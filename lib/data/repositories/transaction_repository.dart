/// Repository untuk transaksi beserta seluruh anaknya.
///
/// Seluruh aplikasi mengakses data lewat kelas ini, tidak pernah menyentuh
/// Drift atau SQL langsung. Kalau suatu saat lapisan penyimpanan diganti,
/// yang berubah hanya file ini.
///
/// Tiga aturan yang dijaga di setiap operasi tulis:
///
///  1. Tidak ada DELETE. Penghapusan mengisi `deletedAt` agar device lain
///     tahu ada penghapusan dan tidak menghidupkannya kembali saat sync.
///  2. Setiap perubahan menyalakan `isDirty` dan memperbarui `updatedAt`.
///  3. Transaksi, item, assignment, dan payment ditulis dalam satu
///     transaksi database. Tidak boleh ada struk yang tersimpan setengah.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/domain/recurring_detector.dart';
import 'package:chacing/domain/split_calculator.dart';

/// Data yang dikirim UI untuk disimpan. Belum punya id kalau baru.
class TransactionDraft {
  TransactionDraft({
    this.id,
    required this.walletId,
    this.categoryId,
    required this.merchant,
    required this.occurredAt,
    required this.total,
    this.tax = 0,
    this.serviceCharge = 0,
    this.discount = 0,
    this.source = TransactionSource.manual,
    this.note,
    this.receiptPhotoPath,
    this.needsReview = false,
    this.excludeFromBudget = false,
    this.items = const [],
    this.assignments = const [],
    this.payments = const {},
  });

  final String? id;
  final String walletId;
  final String? categoryId;
  final String merchant;
  final DateTime occurredAt;
  final int total;
  final int tax;
  final int serviceCharge;
  final int discount;
  final TransactionSource source;
  final String? note;
  final String? receiptPhotoPath;
  final bool needsReview;
  final bool excludeFromBudget;

  final List<LineItem> items;
  final List<Assignment> assignments;

  /// personId -> jumlah yang dia bayarkan di kasir.
  final Map<String, int> payments;

  bool get hasSplit => assignments.isNotEmpty;
}

/// Hasil penyimpanan, termasuk peringatan dari mesin split.
class SaveResult {
  const SaveResult({
    required this.transactionId,
    required this.ownShare,
    required this.warnings,
  });

  final String transactionId;
  final int ownShare;
  final List<String> warnings;
}

class TransactionRepository {
  TransactionRepository(this._db, {Uuid? uuid, SplitCalculator? calculator})
      : _uuid = uuid ?? const Uuid(),
        _calculator = calculator ?? const SplitCalculator();

  final AppDatabase _db;
  final Uuid _uuid;
  final SplitCalculator _calculator;

  // ---------------------------------------------------------------- tulis

  /// Menyimpan transaksi baru atau memperbarui yang lama.
  ///
  /// Item, assignment, dan payment lama dibuang lalu ditulis ulang. Untuk
  /// jumlah baris sekecil ini, mengganti seluruhnya jauh lebih sederhana
  /// dan lebih aman daripada mencocokkan satu per satu.
  Future<SaveResult> save(TransactionDraft draft) async {
    final now = DateTime.now();
    final txId = draft.id ?? _uuid.v4();
    final isNew = draft.id == null;
    final warnings = <String>[];

    final selfId = await _selfPersonId();
    final split = draft.hasSplit
        ? _calculator.calculate(
            items: draft.items,
            assignments: draft.assignments,
            tax: draft.tax,
            serviceCharge: draft.serviceCharge,
            globalDiscount: draft.discount,
            receiptTotal: draft.total,
            payments: draft.payments,
          )
        : null;

    if (split != null) {
      warnings.addAll(split.warnings);
      if (selfId == null) {
        warnings.add(
          'Belum ada orang yang ditandai sebagai diri sendiri, '
          'jadi seluruh total dihitung sebagai pengeluaranmu.',
        );
      }
    }

    // Tanpa split, seluruh nominal adalah pengeluaran sendiri.
    final ownShare = split == null
        ? draft.total
        : (selfId == null ? draft.total : split.shareOf(selfId)?.total ?? 0);

    final subtotal = draft.items.isEmpty
        ? draft.total - draft.tax - draft.serviceCharge + draft.discount
        : draft.items.fold<int>(0, (sum, i) => sum + i.total);

    await _db.transaction(() async {
      // `insertOnConflictUpdate` tetap menyusun baris INSERT lengkap, dan
      // SQLite memeriksa NOT NULL sebelum sempat mendeteksi konflik primary
      // key. Jadi `createdAt` tidak boleh absent saat menyunting — nilainya
      // diambil dari baris lama supaya tidak tertimpa waktu sekarang.
      var createdAt = now;
      if (!isNew) {
        final existing = await findById(txId);
        if (existing != null) createdAt = existing.createdAt;
      }

      final companion = TransactionsCompanion(
        id: Value(txId),
        walletId: Value(draft.walletId),
        categoryId: Value(draft.categoryId),
        merchant: Value(draft.merchant),
        occurredAt: Value(draft.occurredAt),
        subtotal: Value(subtotal),
        tax: Value(draft.tax),
        serviceCharge: Value(draft.serviceCharge),
        discount: Value(draft.discount),
        total: Value(draft.total),
        ownShare: Value(ownShare),
        source: Value(draft.source),
        note: Value(draft.note),
        receiptPhotoPath: Value(draft.receiptPhotoPath),
        needsReview: Value(draft.needsReview),
        excludeFromBudget: Value(draft.excludeFromBudget),
        createdAt: Value(createdAt),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        isDirty: const Value(true),
      );

      await _db.into(_db.transactions).insertOnConflictUpdate(companion);

      await _replaceChildren(txId, draft, now);
    });

    return SaveResult(
      transactionId: txId,
      ownShare: ownShare,
      warnings: warnings,
    );
  }

  Future<void> _replaceChildren(
    String txId,
    TransactionDraft draft,
    DateTime now,
  ) async {
    // Anak-anak dari transaksi ini dibuang total lalu ditulis ulang.
    // Ini penghapusan keras yang disengaja: baris anak tidak pernah
    // disinkronkan sendirian, selalu ikut dokumen induknya di Firestore,
    // jadi tidak perlu tombstone.
    final oldItemIds = await (_db.select(_db.lineItems)
          ..where((t) => t.transactionId.equals(txId)))
        .map((row) => row.id)
        .get();

    if (oldItemIds.isNotEmpty) {
      await (_db.delete(_db.assignments)
            ..where((t) => t.lineItemId.isIn(oldItemIds)))
          .go();
    }
    await (_db.delete(_db.lineItems)
          ..where((t) => t.transactionId.equals(txId)))
        .go();
    await (_db.delete(_db.payments)
          ..where((t) => t.transactionId.equals(txId)))
        .go();

    for (var i = 0; i < draft.items.length; i++) {
      final item = draft.items[i];
      await _db.into(_db.lineItems).insert(
            LineItemsCompanion.insert(
              id: item.id,
              transactionId: txId,
              name: item.name,
              unitPrice: item.unitPrice,
              quantity: Value(item.quantity),
              discount: Value(item.discount),
              position: Value(i),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    for (final a in draft.assignments) {
      await _db.into(_db.assignments).insert(
            AssignmentsCompanion.insert(
              id: _uuid.v4(),
              lineItemId: a.lineItemId,
              personId: a.personId,
              weight: Value(a.weight),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    for (final entry in draft.payments.entries) {
      await _db.into(_db.payments).insert(
            PaymentsCompanion.insert(
              id: _uuid.v4(),
              transactionId: txId,
              personId: entry.key,
              amount: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  /// Menandai transaksi sebagai terhapus. Datanya tetap ada sampai
  /// dibersihkan oleh [purgeTombstones].
  Future<void> softDelete(String transactionId) async {
    final now = DateTime.now();
    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .write(
      TransactionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> restore(String transactionId) async {
    final now = DateTime.now();
    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Membuang tombstone yang sudah lewat [retention] dan sudah tersinkron.
  /// Dipanggil berkala, misalnya sekali saat aplikasi dibuka.
  ///
  /// Baris anak ikut terhapus lewat `ON DELETE CASCADE` di skema.
  Future<int> purgeTombstones({
    Duration retention = const Duration(days: 90),
  }) async {
    final cutoff = DateTime.now().subtract(retention);
    return (_db.delete(_db.transactions)
          ..where((t) =>
              t.deletedAt.isSmallerThanValue(cutoff) &
              t.isDirty.equals(false)))
        .go();
  }

  // ----------------------------------------------------------------- baca

  /// Transaksi dalam satu rentang, terbaru dulu.
  Stream<List<Transaction>> watchInRange(BudgetPeriodRange range) {
    final query = _db.select(_db.transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.occurredAt.isBiggerOrEqualValue(range.start) &
          t.occurredAt.isSmallerThanValue(range.end))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);

    return query.watch();
  }

  Stream<List<Transaction>> watchRecent({int limit = 50}) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);

    return query.watch();
  }

  /// Transaksi hasil OCR yang belum dikonfirmasi pengguna.
  Stream<List<Transaction>> watchNeedingReview() {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull() & t.needsReview.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch();
  }

  Future<Transaction?> findById(String id) {
    return (_db.select(_db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<LineItem>> itemsOf(String transactionId) async {
    final rows = await (_db.select(_db.lineItems)
          ..where((t) => t.transactionId.equals(transactionId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();

    return rows
        .map((r) => LineItem(
              id: r.id,
              name: r.name,
              quantity: r.quantity,
              unitPrice: r.unitPrice,
              discount: r.discount,
            ))
        .toList();
  }

  /// Penugasan item ke orang, untuk seluruh item milik satu transaksi.
  Future<List<Assignment>> assignmentsOf(String transactionId) async {
    final query = _db.select(_db.assignments).join([
      innerJoin(
        _db.lineItems,
        _db.lineItems.id.equalsExp(_db.assignments.lineItemId),
      ),
    ])
      ..where(_db.lineItems.transactionId.equals(transactionId));

    final rows = await query.get();

    return rows.map((row) {
      final assignment = row.readTable(_db.assignments);
      return Assignment(
        lineItemId: assignment.lineItemId,
        personId: assignment.personId,
        weight: assignment.weight,
      );
    }).toList();
  }

  /// Siapa membayar berapa di kasir, sebagai peta personId ke nominal.
  Future<Map<String, int>> paymentsOf(String transactionId) async {
    final rows = await (_db.select(_db.payments)
          ..where((p) => p.transactionId.equals(transactionId)))
        .get();

    return {for (final row in rows) row.personId: row.amount};
  }

  /// Membaca kembali satu transaksi sebagai draft yang siap disunting.
  ///
  /// Memuat item, penugasan, dan pembayaran sekaligus. Menyunting lewat
  /// draft yang tidak lengkap akan menghapus anak-anaknya diam-diam,
  /// karena [save] selalu menulis ulang seluruh anak dari draft.
  Future<TransactionDraft?> draftOf(String transactionId) async {
    final row = await findById(transactionId);
    if (row == null) return null;

    return TransactionDraft(
      id: row.id,
      walletId: row.walletId,
      categoryId: row.categoryId,
      merchant: row.merchant,
      occurredAt: row.occurredAt,
      total: row.total,
      tax: row.tax,
      serviceCharge: row.serviceCharge,
      discount: row.discount,
      source: row.source,
      note: row.note,
      receiptPhotoPath: row.receiptPhotoPath,
      needsReview: row.needsReview,
      excludeFromBudget: row.excludeFromBudget,
      items: await itemsOf(transactionId),
      assignments: await assignmentsOf(transactionId),
      payments: await paymentsOf(transactionId),
    );
  }

  // --------------------------------------------------------------- budget

  /// Total pengeluaran sendiri dalam satu periode.
  Future<int> spentIn(BudgetPeriodRange range, {String? categoryId}) async {
    final row = await _db.customSelect(
      '''
      SELECT COALESCE(SUM(own_share), 0) AS total
      FROM transactions
      WHERE occurred_at >= ? AND occurred_at < ?
        AND deleted_at IS NULL
        AND exclude_from_budget = 0
        AND (? IS NULL OR category_id = ?)
      ''',
      variables: [
        Variable.withDateTime(range.start),
        Variable.withDateTime(range.end),
        Variable<String>(categoryId),
        Variable<String>(categoryId),
      ],
      readsFrom: {_db.transactions},
    ).getSingle();

    return row.read<int>('total');
  }

  /// Versi reaktif dari [spentIn]. UI budget memakai ini supaya angkanya
  /// ikut berubah begitu ada transaksi baru.
  Stream<int> watchSpentIn(BudgetPeriodRange range, {String? categoryId}) {
    return _db.customSelect(
      '''
      SELECT COALESCE(SUM(own_share), 0) AS total
      FROM transactions
      WHERE occurred_at >= ? AND occurred_at < ?
        AND deleted_at IS NULL
        AND exclude_from_budget = 0
        AND (? IS NULL OR category_id = ?)
      ''',
      variables: [
        Variable.withDateTime(range.start),
        Variable.withDateTime(range.end),
        Variable<String>(categoryId),
        Variable<String>(categoryId),
      ],
      readsFrom: {_db.transactions},
    ).watchSingle().map((row) => row.read<int>('total'));
  }

  /// Pengeluaran per hari sepanjang [range], untuk grafik batang.
  ///
  /// Pengelompokan dilakukan di Dart, bukan dengan `date(occurred_at)` di
  /// SQL. Drift menyimpan tanggal sebagai teks ISO-8601 dalam UTC, jadi
  /// belanja jam 1 dini hari WIB tersimpan sebagai tanggal kemarin dalam
  /// UTC dan akan jatuh ke batang yang salah. Objek `DateTime` yang
  /// dikembalikan Drift sudah dikonversi balik ke waktu lokal, sehingga
  /// aman dikelompokkan di sini.
  ///
  /// Jumlah barisnya kecil — satu bulan pemakaian pribadi paling banyak
  /// beberapa ratus transaksi — jadi tidak ada alasan memaksakan SQL.
  Stream<List<DailySpending>> watchSpendingByDay(BudgetPeriodRange range) {
    return watchInRange(range).map((rows) => _groupByDay(rows, range));
  }

  Future<List<DailySpending>> spendingByDay(BudgetPeriodRange range) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.occurredAt.isBiggerOrEqualValue(range.start) &
              t.occurredAt.isSmallerThanValue(range.end)))
        .get();

    return _groupByDay(rows, range);
  }

  List<DailySpending> _groupByDay(
    List<Transaction> rows,
    BudgetPeriodRange range,
  ) {
    final totals = <DateTime, int>{};
    for (final row in rows) {
      if (row.excludeFromBudget) continue;
      final day = DateTime(
        row.occurredAt.year,
        row.occurredAt.month,
        row.occurredAt.day,
      );
      totals[day] = (totals[day] ?? 0) + row.ownShare;
    }

    // Hari tanpa pengeluaran tetap muncul sebagai batang nol. Grafik yang
    // melewatkan hari kosong memampatkan sumbu waktu dan membuat pola
    // belanja terbaca keliru.
    return [
      for (final day in range.days)
        DailySpending(day: day, total: totals[day] ?? 0),
    ];
  }

  /// Pengeluaran per kategori dalam satu periode, terbesar dulu.
  Future<List<CategorySpending>> spendingByCategory(
    BudgetPeriodRange range,
  ) async {
    final rows = await _db.customSelect(
      '''
      SELECT c.id AS category_id,
             c.name AS category_name,
             COALESCE(SUM(t.own_share), 0) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.occurred_at >= ? AND t.occurred_at < ?
        AND t.deleted_at IS NULL
        AND t.exclude_from_budget = 0
      GROUP BY c.id, c.name
      ORDER BY total DESC
      ''',
      variables: [
        Variable.withDateTime(range.start),
        Variable.withDateTime(range.end),
      ],
      readsFrom: {_db.transactions, _db.categories},
    ).get();

    return rows
        .map((r) => CategorySpending(
              categoryId: r.read<String?>('category_id'),
              categoryName: r.read<String?>('category_name') ?? 'Tanpa kategori',
              total: r.read<int>('total'),
            ))
        .toList();
  }

  /// Saldo tiap dompet: saldo awal dikurangi seluruh pengeluaran.
  ///
  /// Memakai `total`, bukan `own_share`. Yang keluar dari dompet di kasir
  /// adalah seluruh nominal struk — kalau menalangi teman, uangnya benar
  /// benar berkurang sebanyak itu meski porsi sendiri lebih kecil.
  /// Ini satu-satunya tempat di aplikasi yang sengaja memakai `total`.
  Stream<Map<String, int>> watchWalletBalances() {
    return _db.customSelect(
      '''
      SELECT w.id AS wallet_id,
             w.initial_balance - COALESCE(SUM(t.total), 0) AS balance
      FROM wallets w
      LEFT JOIN transactions t
        ON t.wallet_id = w.id AND t.deleted_at IS NULL
      WHERE w.deleted_at IS NULL
      GROUP BY w.id, w.initial_balance
      ''',
      readsFrom: {_db.wallets, _db.transactions},
    ).watch().map((rows) => {
          for (final row in rows)
            row.read<String>('wallet_id'): row.read<int>('balance'),
        });
  }

  /// Mencari transaksi menurut nama tempat atau catatan.
  ///
  /// Pencarian dan penyaringan digabung dalam satu query supaya hasilnya
  /// tetap satu stream — menggabungkan beberapa stream di lapisan UI
  /// membuat daftar berkedip tiap kali salah satunya berubah.
  Stream<List<Transaction>> watchFiltered({
    String query = '',
    String? categoryId,
    String? walletId,
    BudgetPeriodRange? range,
    int limit = 300,
  }) {
    final select = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);

    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final pattern = '%$trimmed%';
      select.where(
        (t) => t.merchant.like(pattern) | t.note.like(pattern),
      );
    }
    if (categoryId != null) {
      select.where((t) => t.categoryId.equals(categoryId));
    }
    if (walletId != null) {
      select.where((t) => t.walletId.equals(walletId));
    }
    if (range != null) {
      select
        ..where((t) => t.occurredAt.isBiggerOrEqualValue(range.start))
        ..where((t) => t.occurredAt.isSmallerThanValue(range.end));
    }

    return select.watch();
  }

  // ------------------------------------------------------------- pindah dana

  /// Memindahkan uang antar dompet sendiri.
  ///
  /// Dicatat sebagai dua transaksi berpasangan — keluar dari dompet asal,
  /// masuk ke dompet tujuan sebagai nominal negatif — dan keduanya
  /// dikecualikan dari budget. Memindahkan uang bukan pengeluaran, dan
  /// menghitungnya sebagai pengeluaran akan menggandakan angka begitu
  /// uang itu benar-benar dibelanjakan nanti.
  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    DateTime? occurredAt,
    String? note,
  }) async {
    if (amount <= 0) return;
    if (fromWalletId == toWalletId) return;

    final now = DateTime.now();
    final at = occurredAt ?? now;

    final fromName = await _walletName(fromWalletId);
    final toName = await _walletName(toWalletId);

    await _db.transaction(() async {
      await _insertTransfer(
        walletId: fromWalletId,
        merchant: 'Pindah ke $toName',
        amount: amount,
        at: at,
        note: note,
        now: now,
      );
      await _insertTransfer(
        walletId: toWalletId,
        merchant: 'Terima dari $fromName',
        amount: -amount,
        at: at,
        note: note,
        now: now,
      );
    });
  }

  Future<void> _insertTransfer({
    required String walletId,
    required String merchant,
    required int amount,
    required DateTime at,
    required String? note,
    required DateTime now,
  }) {
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: _uuid.v4(),
            walletId: walletId,
            merchant: merchant,
            occurredAt: at,
            total: amount,
            ownShare: amount,
            source: TransactionSource.manual,
            subtotal: Value(amount),
            note: Value(note),
            excludeFromBudget: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<String> _walletName(String id) async {
    final row = await (_db.select(_db.wallets)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
    return row?.name ?? 'dompet lain';
  }

  // ------------------------------------------------------------------- tren

  /// Pengeluaran per bulan kalender, bulan terlama lebih dulu.
  ///
  /// Bulan tanpa pengeluaran tetap dikembalikan bernilai nol. Grafik tren
  /// yang melewatkan bulan kosong menyambung dua bulan yang berjauhan
  /// menjadi satu garis landai, dan itu membaca pola yang tidak pernah ada.
  Future<List<MonthlySpending>> spendingByMonth({int months = 6}) async {
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - (months - 1), 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final rows = await _db.customSelect(
      '''
      SELECT occurred_at, own_share
      FROM transactions
      WHERE occurred_at >= ? AND occurred_at < ?
        AND deleted_at IS NULL
        AND exclude_from_budget = 0
      ''',
      variables: [
        Variable.withDateTime(firstMonth),
        Variable.withDateTime(end),
      ],
      readsFrom: {_db.transactions},
    ).get();

    final totals = <DateTime, int>{};
    for (final row in rows) {
      final at = row.read<DateTime>('occurred_at');
      final month = DateTime(at.year, at.month, 1);
      totals[month] = (totals[month] ?? 0) + row.read<int>('own_share');
    }

    return [
      for (var i = 0; i < months; i++)
        () {
          final month = DateTime(firstMonth.year, firstMonth.month + i, 1);
          return MonthlySpending(month: month, total: totals[month] ?? 0);
        }(),
    ];
  }

  Stream<List<MonthlySpending>> watchSpendingByMonth({int months = 6}) {
    return _db
        .select(_db.transactions)
        .watch()
        .asyncMap((_) => spendingByMonth(months: months));
  }

  /// Bahan mentah untuk pendeteksi langganan.
  ///
  /// Pindah dana dikecualikan lewat `exclude_from_budget`: nominalnya
  /// memang berulang dan seragam, dan tanpa disaring akan selalu terbaca
  /// sebagai langganan.
  Future<List<RecurringInput>> recurringInputs({int months = 12}) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - months, 1);

    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.excludeFromBudget.equals(false) &
              t.occurredAt.isBiggerOrEqualValue(since)))
        .get();

    return rows
        .map((row) => RecurringInput(
              merchant: row.merchant,
              amount: row.total,
              occurredAt: row.occurredAt,
            ))
        .toList();
  }

  // ------------------------------------------------------------------ sync

  /// Baris yang belum terkirim ke server.
  Future<List<Transaction>> pendingUploads({int limit = 200}) {
    return (_db.select(_db.transactions)
          ..where((t) => t.isDirty.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
          ..limit(limit))
        .get();
  }

  /// Dipanggil setelah upload berhasil. [serverTime] berasal dari
  /// Firestore, bukan dari jam HP.
  Future<void> markSynced(List<String> ids, DateTime serverTime) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(
        isDirty: const Value(false),
        updatedAt: Value(serverTime),
      ),
    );
  }

  // ----------------------------------------------------------------- utils

  Future<String?> _selfPersonId() async {
    final row = await (_db.select(_db.people)
          ..where((p) => p.isSelf.equals(true) & p.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }
}

class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.total,
  });

  final String? categoryId;
  final String categoryName;
  final int total;
}

/// Total pengeluaran sendiri pada satu hari.
class DailySpending {
  const DailySpending({required this.day, required this.total});

  /// Tengah malam waktu lokal pada hari yang bersangkutan.
  final DateTime day;

  final int total;
}

class MonthlySpending {
  const MonthlySpending({required this.month, required this.total});

  /// Tanggal 1 bulan yang bersangkutan.
  final DateTime month;

  final int total;
}
