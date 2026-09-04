/// Tes penyimpanan sungguhan memakai SQLite in-memory.
///
/// Ini yang membuktikan kriteria selesai Minggu 1: transaksi bisa disimpan
/// lewat kode dan dibaca kembali. Sekaligus menjaga tiga hal yang mudah
/// rusak diam-diam — `createdAt` saat menyunting, cascade saat membuang
/// tombstone, dan porsi sendiri saat ada split.
library;

// `isNull`/`isNotNull` disembunyikan: drift mengekspor keduanya untuk
// membangun SQL, dan namanya bentrok dengan matcher milik flutter_test.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/seed.dart';
import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/domain/split_calculator.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late String walletId;
  late String categoryId;
  late String selfId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(db).run();
    repository = TransactionRepository(db);

    walletId = (await db.select(db.wallets).get()).first.id;
    categoryId = (await db.select(db.categories).get()).first.id;
    selfId = (await (db.select(db.people)..where((p) => p.isSelf.equals(true)))
            .getSingle())
        .id;
  });

  tearDown(() async => db.close());

  TransactionDraft draft({
    String? id,
    int total = 25000,
    String merchant = 'Warung Kopi',
    DateTime? occurredAt,
    bool excludeFromBudget = false,
    List<LineItem> items = const [],
    List<Assignment> assignments = const [],
    Map<String, int> payments = const {},
  }) {
    return TransactionDraft(
      id: id,
      walletId: walletId,
      categoryId: categoryId,
      merchant: merchant,
      occurredAt: occurredAt ?? DateTime(2026, 9, 3, 12, 0),
      total: total,
      excludeFromBudget: excludeFromBudget,
      items: items,
      assignments: assignments,
      payments: payments,
    );
  }

  group('seeding', () {
    test('mengisi kategori, dompet tunai, dan baris diri sendiri', () async {
      expect((await db.select(db.categories).get()).length, 7);
      expect((await db.select(db.wallets).get()).single.name, 'Tunai');
      expect((await db.select(db.people).get()).single.isSelf, isTrue);
    });

    test('kategori bawaan punya warna sendiri-sendiri', () async {
      final rows = await db.select(db.categories).get();
      final colors = rows.map((c) => c.colorValue).toList();

      // Semua terisi, dan tidak ada dua kategori berwarna sama — grafik
      // dengan dua batang sewarna tidak bisa dibaca.
      expect(colors.any((c) => c == null), isFalse);
      expect(colors.toSet().length, rows.length);
    });

    test('warna kosong diisi ulang tanpa menimpa pilihan pengguna', () async {
      final makan = (await db.select(db.categories).get())
          .firstWhere((c) => c.name == 'Makan');

      // Satu kategori dikosongkan warnanya seperti pemasangan lama,
      // satu lagi diberi warna pilihan sendiri.
      await (db.update(db.categories)..where((c) => c.id.equals(makan.id)))
          .write(const CategoriesCompanion(colorValue: Value(null)));
      final transport = (await db.select(db.categories).get())
          .firstWhere((c) => c.name == 'Transport');
      await (db.update(db.categories)..where((c) => c.id.equals(transport.id)))
          .write(const CategoriesCompanion(colorValue: Value(0xFF123456)));

      await DatabaseSeeder(db).run();

      final after = await db.select(db.categories).get();
      expect(after.firstWhere((c) => c.name == 'Makan').colorValue, isNotNull);
      expect(
        after.firstWhere((c) => c.name == 'Transport').colorValue,
        0xFF123456,
      );
    });

    test('dijalankan dua kali tidak menggandakan apa pun', () async {
      await DatabaseSeeder(db).run();

      expect((await db.select(db.categories).get()).length, 7);
      expect((await db.select(db.wallets).get()).length, 1);
      expect((await db.select(db.people).get()).length, 1);
    });
  });

  group('simpan dan baca kembali', () {
    test('transaksi tersimpan bisa dibaca lagi apa adanya', () async {
      final result = await repository.save(draft());

      final saved = await repository.findById(result.transactionId);

      expect(saved, isNotNull);
      expect(saved!.merchant, 'Warung Kopi');
      expect(saved.total, 25000);
      expect(saved.walletId, walletId);
      expect(saved.isDirty, isTrue);
      expect(saved.deletedAt, isNull);
    });

    test('tanpa split, porsi sendiri sama dengan total', () async {
      final result = await repository.save(draft(total: 47500));

      expect(result.ownShare, 47500);
      expect((await repository.findById(result.transactionId))!.ownShare, 47500);
    });

    test('menyunting tidak menimpa createdAt dengan waktu sekarang', () async {
      final first = await repository.save(draft());
      final original = (await repository.findById(first.transactionId))!;

      // Granularitas jam Windows sekitar 15 ms, jadi jeda harus cukup
      // longgar supaya `updatedAt` benar-benar bergerak.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await repository.save(
        draft(id: first.transactionId, total: 30000, merchant: 'Warung Sate'),
      );
      final edited = (await repository.findById(first.transactionId))!;

      expect(edited.merchant, 'Warung Sate');
      expect(edited.total, 30000);
      expect(edited.createdAt, original.createdAt);
      expect(edited.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('item struk ikut tersimpan dan terbaca berurutan', () async {
      final result = await repository.save(
        draft(
          total: 40000,
          items: const [
            LineItem(id: 'i1', name: 'Kopi', quantity: 1, unitPrice: 25000),
            LineItem(id: 'i2', name: 'Roti', quantity: 1, unitPrice: 15000),
          ],
        ),
      );

      final items = await repository.itemsOf(result.transactionId);

      expect(items.map((i) => i.name), ['Kopi', 'Roti']);
      expect(items.first.unitPrice, 25000);
    });

    test('menyunting mengganti item lama, tidak menumpuk', () async {
      final first = await repository.save(
        draft(
          items: const [
            LineItem(id: 'i1', name: 'Kopi', quantity: 1, unitPrice: 25000),
          ],
        ),
      );

      await repository.save(
        draft(
          id: first.transactionId,
          items: const [
            LineItem(id: 'i2', name: 'Teh', quantity: 1, unitPrice: 10000),
          ],
        ),
      );

      final items = await repository.itemsOf(first.transactionId);
      expect(items.map((i) => i.name), ['Teh']);
    });
  });

  group('split bill', () {
    test('hanya porsi sendiri yang masuk sebagai pengeluaran', () async {
      final now = DateTime.now();
      await db.into(db.people).insert(
            PeopleCompanion.insert(
              id: 'budi',
              name: 'Budi',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Makan 90.000 dibagi rata berdua. Saya menalangi semuanya.
      final result = await repository.save(
        draft(
          total: 90000,
          items: const [
            LineItem(id: 'i1', name: 'Makan', quantity: 1, unitPrice: 90000),
          ],
          assignments: [
            Assignment(lineItemId: 'i1', personId: selfId),
            const Assignment(lineItemId: 'i1', personId: 'budi'),
          ],
          payments: {selfId: 90000},
        ),
      );

      // Yang keluar dari dompet 90.000, tapi yang jadi pengeluaran
      // sendiri hanya 45.000.
      expect(result.ownShare, 45000);

      final saved = (await repository.findById(result.transactionId))!;
      expect(saved.total, 90000);
      expect(saved.ownShare, 45000);
    });

    test('budget memakai porsi sendiri, bukan total struk', () async {
      final now = DateTime.now();
      await db.into(db.people).insert(
            PeopleCompanion.insert(
              id: 'budi',
              name: 'Budi',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await repository.save(
        draft(
          total: 90000,
          occurredAt: DateTime(2026, 9, 3, 12),
          items: const [
            LineItem(id: 'i1', name: 'Makan', quantity: 1, unitPrice: 90000),
          ],
          assignments: [
            Assignment(lineItemId: 'i1', personId: selfId),
            const Assignment(lineItemId: 'i1', personId: 'budi'),
          ],
        ),
      );

      const calculator = BudgetPeriodCalculator();
      final week = calculator.weekContaining(DateTime(2026, 9, 3));

      expect(await repository.spentIn(week), 45000);
    });
  });

  group('budget', () {
    const calculator = BudgetPeriodCalculator();
    final week = calculator.weekContaining(DateTime(2026, 9, 3));

    test('menjumlahkan hanya transaksi dalam periode', () async {
      await repository.save(
        draft(total: 25000, occurredAt: DateTime(2026, 9, 3, 12)),
      );
      // Minggu berikutnya, tidak boleh ikut terhitung.
      await repository.save(
        draft(total: 99000, occurredAt: DateTime(2026, 9, 8, 12)),
      );

      expect(await repository.spentIn(week), 25000);
    });

    test('transaksi yang dikecualikan tidak ikut dihitung', () async {
      await repository.save(draft(total: 25000));
      await repository.save(draft(total: 500000, excludeFromBudget: true));

      expect(await repository.spentIn(week), 25000);
    });

    test('transaksi terhapus tidak ikut dihitung', () async {
      final result = await repository.save(draft(total: 25000));
      await repository.save(draft(total: 30000));

      await repository.softDelete(result.transactionId);

      expect(await repository.spentIn(week), 30000);
    });

    test('pengeluaran per kategori dikelompokkan dan diurutkan', () async {
      final categories = await db.select(db.categories).get();
      final makan = categories.firstWhere((c) => c.name == 'Makan');
      final transport = categories.firstWhere((c) => c.name == 'Transport');

      await repository.save(
        TransactionDraft(
          walletId: walletId,
          categoryId: makan.id,
          merchant: 'Warteg',
          occurredAt: DateTime(2026, 9, 3, 12),
          total: 30000,
        ),
      );
      await repository.save(
        TransactionDraft(
          walletId: walletId,
          categoryId: transport.id,
          merchant: 'Ojek',
          occurredAt: DateTime(2026, 9, 3, 13),
          total: 15000,
        ),
      );

      final spending = await repository.spendingByCategory(week);

      expect(spending.first.categoryName, 'Makan');
      expect(spending.first.total, 30000);
      expect(spending.last.categoryName, 'Transport');
    });
  });

  group('hapus dan pulihkan', () {
    /// Memundurkan tanggal hapus supaya tombstone benar-benar lebih tua
    /// dari masa simpan.
    ///
    /// Memakai `retention: Duration.zero` tidak bisa diandalkan: batasnya
    /// jadi "sekarang", dan seluruh rangkaian hapus lalu purge bisa selesai
    /// dalam satu milidetik yang sama sehingga tombstone-nya belum terhitung
    /// lebih tua. Tesnya lalu lulus atau gagal tergantung kecepatan mesin.
    Future<void> backdateDeletion(String id, {required int days}) async {
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value(DateTime.now().subtract(Duration(days: days))),
        ),
      );
    }

    test('soft delete menyembunyikan tapi tidak membuang baris', () async {
      final result = await repository.save(draft());

      await repository.softDelete(result.transactionId);

      final row = await repository.findById(result.transactionId);
      expect(row, isNotNull);
      expect(row!.deletedAt, isNotNull);

      final recent = await repository.watchRecent().first;
      expect(recent, isEmpty);
    });

    test('pulihkan mengembalikan transaksi ke daftar', () async {
      final result = await repository.save(draft());
      await repository.softDelete(result.transactionId);

      await repository.restore(result.transactionId);

      final recent = await repository.watchRecent().first;
      expect(recent.single.id, result.transactionId);
    });

    test('membuang tombstone ikut menghapus item anaknya', () async {
      final result = await repository.save(
        draft(
          items: const [
            LineItem(id: 'i1', name: 'Kopi', quantity: 1, unitPrice: 25000),
          ],
        ),
      );

      expect((await db.select(db.lineItems).get()).length, 1);

      await repository.softDelete(result.transactionId);
      await repository.markSynced([result.transactionId], DateTime.now());
      await backdateDeletion(result.transactionId, days: 100);

      final purged = await repository.purgeTombstones();

      expect(purged, 1);
      expect(await db.select(db.transactions).get(), isEmpty);
      // Tanpa ON DELETE CASCADE, baris ini akan tertinggal sebagai yatim —
      // atau penghapusan induknya gagal sama sekali.
      expect(await db.select(db.lineItems).get(), isEmpty);
    });

    test('tombstone yang belum tersinkron tidak ikut dibuang', () async {
      final result = await repository.save(draft());
      await repository.softDelete(result.transactionId);
      await backdateDeletion(result.transactionId, days: 100);

      // Cukup tua untuk dibuang, tapi `isDirty` masih menyala — server
      // belum pernah tahu baris ini dihapus.
      final purged = await repository.purgeTombstones();

      expect(purged, 0);
      expect(await repository.findById(result.transactionId), isNotNull);
    });
  });

  group('sync', () {
    test('baris baru menunggu diunggah', () async {
      final result = await repository.save(draft());

      final pending = await repository.pendingUploads();
      expect(pending.single.id, result.transactionId);
    });

    test('markSynced memakai waktu server, bukan jam HP', () async {
      final result = await repository.save(draft());
      final serverTime = DateTime(2030, 1, 1, 9, 0);

      await repository.markSynced([result.transactionId], serverTime);

      final row = (await repository.findById(result.transactionId))!;
      expect(row.isDirty, isFalse);
      expect(row.updatedAt, serverTime);
      expect(await repository.pendingUploads(), isEmpty);
    });
  });
}
