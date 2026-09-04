/// Skema SQLite (via Drift) untuk aplikasi pencatat keuangan.
///
/// Prinsip yang dipegang di seluruh skema:
///
///  * SQLite adalah sumber kebenaran. Firestore hanya lapisan transport.
///  * Semua id berupa UUID string, bukan integer auto-increment. Dua device
///    yang membuat data secara offline tidak boleh bertabrakan id.
///  * Uang disimpan sebagai `int` rupiah penuh. Tidak ada desimal.
///  * Tidak ada penghapusan permanen. Baris yang dihapus diberi `deletedAt`
///    supaya device lain tahu ada penghapusan dan tidak menghidupkannya lagi.
///  * `isDirty` menandai baris yang belum terkirim ke Firestore.
///  * `updatedAt` diisi server timestamp saat sync, karena jam HP tidak
///    bisa dipercaya untuk resolusi konflik.
///
/// Nama kelas data diberikan eksplisit lewat [DataClassName] karena dua
/// alasan: bawaan Drift hanya membuang huruf `s` di akhir (`Categories`
/// menjadi `Categorie`), dan `LineItem`/`Assignment` akan bentrok dengan
/// kelas bernama sama di `domain/split_calculator.dart`.
library;

import 'package:drift/drift.dart';

import 'package:chacing/domain/budget_period.dart';

part 'database.g.dart';

/// Kolom yang wajib ada di setiap tabel yang ikut sync.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
}

enum WalletType { cash, ewallet, bank, credit }

enum TransactionSource { manual, ocrReceipt, ocrScreenshot, recurring }

/// Dompet: tunai, GoPay, OVO, rekening bank, kartu kredit.
@DataClassName('Wallet')
class Wallets extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<WalletType>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Category')
class Categories extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text().nullable()();
  IntColumn get colorValue => integer().nullable()();

  /// Kategori bawaan tidak boleh dihapus pengguna.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Orang yang ikut split bill. Tidak harus punya akun.
@DataClassName('Person')
class People extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get phone => text().nullable()();

  /// Menandai baris yang mewakili pemilik aplikasi sendiri.
  BoolColumn get isSelf => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Transaction')
class Transactions extends Table with SyncColumns {
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  TextColumn get merchant => text().withLength(max: 120)();
  DateTimeColumn get occurredAt => dateTime()();

  /// Jumlah nilai seluruh item, sebelum pajak dan diskon global.
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get serviceCharge => integer().withDefault(const Constant(0))();
  IntColumn get discount => integer().withDefault(const Constant(0))();

  /// Total yang tercetak di struk. Ini yang keluar dari dompet.
  IntColumn get total => integer()();

  /// Porsi pemilik aplikasi sendiri setelah split.
  ///
  /// Kolom inilah yang dipakai untuk budget mingguan, BUKAN [total].
  /// Kalau tidak ada split, nilainya sama dengan [total].
  IntColumn get ownShare => integer()();

  TextColumn get source => textEnum<TransactionSource>()();
  TextColumn get note => text().nullable()();
  TextColumn get receiptPhotoPath => text().nullable()();
  TextColumn get receiptPhotoUrl => text().nullable()();

  /// Hasil OCR yang belum dikonfirmasi pengguna tetap ditandai di sini,
  /// supaya bisa disorot di UI dan tidak diam-diam dianggap benar.
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();

  /// Dikecualikan dari budget: transfer antar dompet sendiri, top-up,
  /// atau pengeluaran yang pasti diganti kantor.
  BoolColumn get excludeFromBudget =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Satu baris item pada struk.
///
/// Kelas datanya sengaja dinamai `ReceiptItem`, bukan `LineItem`, supaya
/// tidak bentrok dengan `LineItem` milik mesin split di lapisan domain.
@DataClassName('ReceiptItem')
class LineItems extends Table with SyncColumns {
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(max: 120)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitPrice => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Skor keyakinan OCR 0–100. Dipakai untuk menyorot baris yang meragukan.
  IntColumn get ocrConfidence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Siapa menikmati item apa. Inti dari split bill.
@DataClassName('ItemAssignment')
class Assignments extends Table with SyncColumns {
  TextColumn get lineItemId =>
      text().references(LineItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get personId => text().references(People, #id)();
  IntColumn get weight => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Siapa yang benar-benar mengeluarkan uang di kasir.
///
/// Sengaja dipisah dari [Assignments]. Satu orang bisa membayar penuh
/// tanpa memakan apa pun, dan sebaliknya.
@DataClassName('Payment')
class Payments extends Table with SyncColumns {
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get personId => text().references(People, #id)();
  IntColumn get amount => integer()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get settledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Budget')
class Budgets extends Table with SyncColumns {
  /// Harian, mingguan, atau bulanan — dipilih pengguna.
  ///
  /// Memakai `PeriodKind` milik lapisan domain, bukan enum sendiri.
  /// Dua enum untuk satu hal yang sama hanya melahirkan lapisan
  /// penerjemah yang bisa salah arah tanpa ketahuan.
  TextColumn get period => textEnum<PeriodKind>()();
  IntColumn get amount => integer()();

  /// Hari mulai minggu: 1 = Senin, 7 = Minggu (mengikuti DateTime.weekday).
  IntColumn get weekStartsOn => integer().withDefault(const Constant(1))();

  /// Kalau null, budget berlaku untuk semua kategori.
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Sisa budget dibawa ke periode berikutnya.
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catatan sync per tabel: kapan terakhir berhasil tarik data dari server.
///
/// Kolomnya dinamai `entity`, bukan `tableName`, karena `tableName` sudah
/// dipakai Drift sendiri untuk menimpa nama tabel SQL dan harus berupa
/// literal string.
@DataClassName('SyncState')
class SyncStates extends Table {
  TextColumn get entity => text()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}

@DriftDatabase(
  tables: [
    Wallets,
    Categories,
    People,
    Transactions,
    LineItems,
    Assignments,
    Payments,
    Budgets,
    SyncStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Waktu disimpan sebagai teks ISO-8601, bukan detik unix.
  ///
  /// Bawaan Drift membulatkan setiap `DateTime` ke detik penuh. Itu tidak
  /// cukup untuk `updatedAt`, yang justru dipakai untuk menentukan versi
  /// mana yang menang saat sync: dua penyuntingan dalam detik yang sama
  /// akan terlihat persis sama dan konfliknya tidak bisa diselesaikan.
  ///
  /// Pilihan ini harus dibuat sekarang, selagi `schemaVersion` masih 1 dan
  /// belum ada data siapa pun. Mengubahnya setelah rilis berarti menulis
  /// migrasi yang mengonversi seluruh kolom tanggal.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        // Setiap penambahan kolom di versi berikutnya ditangani di sini.
        // Jangan pernah rilis tanpa menaikkan schemaVersion.
        onUpgrade: (m, from, to) async {},
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    // Query paling panas: pengeluaran dalam rentang tanggal untuk budget.
    await customStatement(
      'CREATE INDEX idx_tx_occurred ON transactions (occurred_at, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX idx_tx_dirty ON transactions (is_dirty)',
    );
    await customStatement(
      'CREATE INDEX idx_tx_category ON transactions (category_id)',
    );
    await customStatement(
      'CREATE INDEX idx_items_tx ON line_items (transaction_id)',
    );
    await customStatement(
      'CREATE INDEX idx_assign_item ON assignments (line_item_id)',
    );
    await customStatement(
      'CREATE INDEX idx_payments_tx ON payments (transaction_id)',
    );
  }
}
