/// Tes uang masuk, tagihan tetap, cadangan, dan migrasi skema v1 ke v2.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/backup.dart';
import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/fixed_bill_repository.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/repositories/wallet_repository.dart';
import 'package:chacing/data/seed.dart';
import 'package:chacing/domain/bill_schedule.dart';
import 'package:chacing/domain/budget_period.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late FixedBillRepository bills;
  late String cashId;
  late String categoryId;

  final now = DateTime.now();
  final thisPeriod = const BudgetPeriodCalculator().monthContaining(now);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(db).run();
    transactions = TransactionRepository(db);
    bills = FixedBillRepository(db, transactions);
    cashId = (await WalletRepository(db).all()).first.id;
    categoryId = (await db.select(db.categories).get()).first.id;
  });

  tearDown(() async => db.close());

  Future<int> balanceOf(String walletId) async =>
      (await transactions.watchWalletBalances().first)[walletId]!;

  group('uang masuk', () {
    test('menaikkan saldo dompet', () async {
      await transactions.recordIncome(
        walletId: cashId,
        amount: 2500000,
        name: 'Gaji',
      );

      expect(await balanceOf(cashId), 2500000);
    });

    test('tidak mengurangi atau menambah budget', () async {
      await transactions.save(
        TransactionDraft(
          walletId: cashId,
          merchant: 'Warteg',
          occurredAt: now,
          total: 20000,
        ),
      );
      await transactions.recordIncome(
        walletId: cashId,
        amount: 2500000,
        name: 'Gaji',
      );

      // Hanya belanja yang terhitung — pemasukan tidak membuat angka
      // pengeluaran jadi negatif.
      expect(await transactions.spentIn(thisPeriod), 20000);
    });

    test('tidak muncul di grafik harian maupun per kategori', () async {
      await transactions.recordIncome(
        walletId: cashId,
        amount: 500000,
        name: 'Uang saku',
      );

      final days = await transactions.spendingByDay(thisPeriod);
      expect(days.every((d) => d.total == 0), isTrue);
      expect(await transactions.spendingByCategory(thisPeriod), isEmpty);
    });

    test('tidak terbaca sebagai langganan', () async {
      for (var month = 1; month <= 4; month++) {
        await transactions.recordIncome(
          walletId: cashId,
          amount: 2500000,
          name: 'Gaji',
          occurredAt: DateTime(now.year, now.month - month, 25),
        );
      }

      expect(await transactions.recurringInputs(), isEmpty);
    });

    test(
      'ditandai sebagai pemasukan dengan nominal tersimpan negatif',
      () async {
        final id = await transactions.recordIncome(
          walletId: cashId,
          amount: 750000,
          name: '  Kiriman ibu  ',
        );

        final row = (await transactions.findById(id))!;
        expect(row.source, TransactionSource.income);
        expect(row.total, -750000);
        expect(row.ownShare, -750000);
        expect(row.excludeFromBudget, isTrue);
        expect(row.merchant, 'Kiriman ibu');
      },
    );

    test('menyunting mengganti nominal tanpa menambah baris', () async {
      final id = await transactions.recordIncome(
        walletId: cashId,
        amount: 100000,
        name: 'Bonus',
      );
      final created = (await transactions.findById(id))!.createdAt;

      await transactions.recordIncome(
        id: id,
        walletId: cashId,
        amount: 150000,
        name: 'Bonus',
      );

      expect((await db.select(db.transactions).get()).length, 1);
      expect(await balanceOf(cashId), 150000);
      expect((await transactions.findById(id))!.createdAt, created);
    });

    test('nominal nol atau negatif ditolak', () async {
      expect(
        () => transactions.recordIncome(
          walletId: cashId,
          amount: 0,
          name: 'Gaji',
        ),
        throwsArgumentError,
      );
    });

    test('dihapus lalu saldo kembali', () async {
      final id = await transactions.recordIncome(
        walletId: cashId,
        amount: 300000,
        name: 'Gaji',
      );
      await transactions.softDelete(id);

      expect(await balanceOf(cashId), 0);
    });
  });

  group('tagihan tetap', () {
    Future<String> createBill({
      int amount = 350000,
      int dueDay = 10,
      bool countInBudget = false,
    }) {
      return bills.save(
        name: 'Internet',
        amount: amount,
        dueDay: dueDay,
        walletId: cashId,
        categoryId: categoryId,
        countInBudget: countInBudget,
      );
    }

    test('baru dibuat belum dibayar', () async {
      await createBill();

      final view = (await bills.active()).single;
      expect(view.paidForMonth, isNull);
      expect(view.schedule().isPaidThisMonth, isFalse);
    });

    test('membayar mencatat transaksi dan menandai lunas bulan ini', () async {
      final billId = await createBill();

      final txId = await bills.recordPayment(
        billId: billId,
        amount: 350000,
        walletId: cashId,
      );

      final tx = (await transactions.findById(txId))!;
      expect(tx.merchant, 'Internet');
      expect(tx.total, 350000);
      expect(tx.source, TransactionSource.recurring);
      expect(tx.categoryId, categoryId);

      final view = (await bills.active()).single;
      expect(view.schedule().status, BillStatus.paid);
      expect(await balanceOf(cashId), -350000);
    });

    test('nominal saat membayar boleh berbeda dari nominal tagihan', () async {
      final billId = await createBill(amount: 200000);

      final txId = await bills.recordPayment(
        billId: billId,
        amount: 237500,
        walletId: cashId,
      );

      expect((await transactions.findById(txId))!.total, 237500);
      // Nominal tagihannya sendiri tidak ikut berubah.
      expect((await bills.findById(billId))!.amount, 200000);
    });

    test('tidak dihitung ke budget kalau sakelarnya mati', () async {
      final billId = await createBill(countInBudget: false);
      await bills.recordPayment(
        billId: billId,
        amount: 350000,
        walletId: cashId,
      );

      expect(await transactions.spentIn(thisPeriod), 0);
    });

    test('dihitung ke budget kalau sakelarnya menyala', () async {
      final billId = await createBill(countInBudget: true);
      await bills.recordPayment(
        billId: billId,
        amount: 350000,
        walletId: cashId,
      );

      expect(await transactions.spentIn(thisPeriod), 350000);
    });

    test(
      'menghapus transaksi pembayaran membuat tagihan belum dibayar lagi',
      () async {
        final billId = await createBill();
        final txId = await bills.recordPayment(
          billId: billId,
          amount: 350000,
          walletId: cashId,
        );

        await transactions.softDelete(txId);

        final view = (await bills.active()).single;
        expect(view.paidForMonth, isNull);
        expect(view.schedule().isPaidThisMonth, isFalse);
      },
    );

    test('memulihkan transaksi yang dihapus menandai lunas lagi', () async {
      final billId = await createBill();
      final txId = await bills.recordPayment(
        billId: billId,
        amount: 350000,
        walletId: cashId,
      );
      await transactions.softDelete(txId);
      await transactions.restore(txId);

      expect((await bills.active()).single.schedule().isPaidThisMonth, isTrue);
    });

    test(
      'tagihan yang dihapus hilang dari daftar, pembayarannya tetap',
      () async {
        final billId = await createBill();
        final txId = await bills.recordPayment(
          billId: billId,
          amount: 350000,
          walletId: cashId,
        );

        await bills.softDelete(billId);

        expect(await bills.active(), isEmpty);
        expect(await transactions.findById(txId), isNotNull);
      },
    );

    test('tanggal di luar 1–31 dan nominal nol ditolak', () async {
      expect(() => createBill(dueDay: 0), throwsArgumentError);
      expect(() => createBill(dueDay: 32), throwsArgumentError);
      expect(() => createBill(amount: 0), throwsArgumentError);
    });

    test('daftar urut tanggal jatuh tempo', () async {
      await bills.save(name: 'Kos', amount: 1500000, dueDay: 25);
      await bills.save(name: 'Pulsa', amount: 50000, dueDay: 3);

      final names = (await bills.active()).map((v) => v.bill.name);
      expect(names, ['Pulsa', 'Kos']);
    });
  });

  group('cadangan', () {
    test('tagihan tetap ikut dicadangkan dan dipulihkan', () async {
      await bills.save(name: 'Kos', amount: 1500000, dueDay: 1);
      await transactions.recordIncome(
        walletId: cashId,
        amount: 2000000,
        name: 'Gaji',
      );

      final service = BackupService(db);
      final json = await service.exportJson();
      expect(service.inspect(json).fixedBills, 1);

      await bills.save(name: 'Tambahan setelah cadangan', amount: 1, dueDay: 2);
      await service.restore(json);

      final names = (await bills.active()).map((v) => v.bill.name);
      expect(names, ['Kos']);
      expect(await balanceOf(cashId), 2000000);
    });

    test(
      'cadangan lama tanpa bagian tagihan tetap masih bisa dipulihkan',
      () async {
        final service = BackupService(db);
        final json = await service.exportJson();

        // Meniru file dari sebelum schemaVersion 2.
        final legacy = json
            .replaceFirst(RegExp(r'"schemaVersion": 2'), '"schemaVersion": 1')
            .replaceFirst(RegExp(r',\s*"fixedBills": \[\s*\]'), '');
        expect(legacy.contains('fixedBills'), isFalse);

        await bills.save(name: 'Kos', amount: 1500000, dueDay: 1);
        await service.restore(legacy);

        expect(await bills.active(), isEmpty);
      },
    );
  });

  group('migrasi skema', () {
    test('HP dengan database v1 naik ke v2 tanpa kehilangan data', () async {
      final dir = await Directory.systemTemp.createTemp('chacing_migration');
      final file = File('${dir.path}/chacing.sqlite');

      try {
        // Susun database yang persis seperti di HP sebelum pembaruan:
        // tanpa tabel tagihan dan bertanda versi 1.
        var old = AppDatabase(NativeDatabase(file));
        await DatabaseSeeder(old).run();
        final wallet = (await WalletRepository(old).all()).first.id;
        await TransactionRepository(old).save(
          TransactionDraft(
            walletId: wallet,
            merchant: 'Mekdi',
            occurredAt: DateTime(2026, 9, 4, 12),
            total: 10000,
          ),
        );
        await old.customStatement('DROP TABLE fixed_bills');
        await old.customStatement('PRAGMA user_version = 1');
        await old.close();

        final upgraded = AppDatabase(NativeDatabase(file));
        try {
          final version = await upgraded
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), 2);

          final rows = await upgraded.select(upgraded.transactions).get();
          expect(rows.single.merchant, 'Mekdi');
          expect(rows.single.total, 10000);

          final upgradedBills = FixedBillRepository(
            upgraded,
            TransactionRepository(upgraded),
          );
          await upgradedBills.save(name: 'Kos', amount: 1500000, dueDay: 1);
          expect((await upgradedBills.active()).single.bill.name, 'Kos');
        } finally {
          await upgraded.close();
        }
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  test('kolom sumber menyimpan nama, jadi nilai lama tetap terbaca', () async {
    // Menambah `income` di akhir enum tidak boleh menggeser arti baris
    // lama. Kolomnya teks, bukan indeks — tes ini menjaga itu.
    await db.customStatement(
      "INSERT INTO transactions (id, wallet_id, merchant, occurred_at, total, "
      "own_share, source, created_at, updated_at) VALUES "
      "('lama', '$cashId', 'Lama', '2026-09-01T00:00:00.000', 1, 1, "
      "'recurring', '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')",
    );

    expect(
      (await transactions.findById('lama'))!.source,
      TransactionSource.recurring,
    );
  });
}
