/// Tes untuk penyimpanan pengaturan budget dan agregasi harian grafik.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/budget_repository.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/seed.dart';
import 'package:chacing/domain/budget_period.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository budgets;
  late TransactionRepository transactions;
  late String walletId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(db).run();
    budgets = BudgetRepository(db);
    transactions = TransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
  });

  tearDown(() async => db.close());

  TransactionDraft draft({
    required int total,
    required DateTime occurredAt,
    bool excludeFromBudget = false,
  }) {
    return TransactionDraft(
      walletId: walletId,
      merchant: 'Warung',
      occurredAt: occurredAt,
      total: total,
      excludeFromBudget: excludeFromBudget,
    );
  }

  group('pengaturan budget', () {
    test('belum ada budget sebelum pengguna menetapkannya', () async {
      expect(await budgets.active(), isNull);
    });

    test('menyimpan dan membaca kembali pilihan periode', () async {
      await budgets.save(period: PeriodKind.month, amount: 3000000);

      final saved = await budgets.active();
      expect(saved, isNotNull);
      expect(saved!.period, PeriodKind.month);
      expect(saved.amount, 3000000);
    });

    test('ketiga jenis periode bertahan melewati penyimpanan', () async {
      for (final kind in PeriodKind.values) {
        await budgets.save(period: kind, amount: 50000);
        expect((await budgets.active())!.period, kind);
      }
    });

    test('menyimpan ulang memperbarui baris yang sama, tidak menumpuk',
        () async {
      await budgets.save(period: PeriodKind.week, amount: 700000);
      await budgets.save(period: PeriodKind.day, amount: 100000);

      final all = await db.select(db.budgets).get();
      expect(all.length, 1);
      expect(all.single.period, PeriodKind.day);
      expect(all.single.amount, 100000);
    });

    test('rollover ikut tersimpan', () async {
      await budgets.save(
        period: PeriodKind.week,
        amount: 700000,
        rollover: true,
      );

      expect((await budgets.active())!.rollover, isTrue);
    });

    test('mematikan budget menyembunyikannya tanpa menghapus riwayat',
        () async {
      await budgets.save(period: PeriodKind.week, amount: 700000);

      await budgets.disable();

      expect(await budgets.active(), isNull);
      // Barisnya tetap ada, hanya tidak aktif.
      expect((await db.select(db.budgets).get()).length, 1);
    });
  });

  group('pengeluaran per hari untuk grafik', () {
    const calculator = BudgetPeriodCalculator();
    final week = calculator.weekContaining(DateTime(2026, 9, 3));

    test('hari tanpa pengeluaran tetap muncul sebagai nol', () async {
      await transactions.save(
        draft(total: 25000, occurredAt: DateTime(2026, 9, 3, 12)),
      );

      final days = await transactions.spendingByDay(week);

      // Tujuh batang, bukan satu. Grafik yang melewatkan hari kosong
      // memampatkan sumbu waktu dan membuat polanya salah dibaca.
      expect(days.length, 7);
      expect(days.where((d) => d.total == 0).length, 6);
    });

    test('urutannya mengikuti urutan hari dalam periode', () async {
      final days = await transactions.spendingByDay(week);

      expect(days.first.day, DateTime(2026, 8, 31));
      expect(days.last.day, DateTime(2026, 9, 6));
    });

    test('beberapa transaksi di hari yang sama dijumlahkan', () async {
      await transactions.save(
        draft(total: 25000, occurredAt: DateTime(2026, 9, 3, 8)),
      );
      await transactions.save(
        draft(total: 15000, occurredAt: DateTime(2026, 9, 3, 19)),
      );

      final days = await transactions.spendingByDay(week);
      final thursday =
          days.firstWhere((d) => d.day == DateTime(2026, 9, 3));

      expect(thursday.total, 40000);
    });

    test('belanja larut malam tetap masuk ke harinya sendiri', () async {
      // Ini yang akan salah kalau pengelompokan memakai `date(occurred_at)`
      // di SQL: Drift menyimpan tanggal dalam UTC, jadi pukul 23:30 WIB
      // tersimpan sebagai 16:30 UTC di hari yang sama, tapi pukul 00:30 WIB
      // tersimpan sebagai 17:30 UTC di hari SEBELUMNYA.
      await transactions.save(
        draft(total: 30000, occurredAt: DateTime(2026, 9, 3, 23, 30)),
      );
      await transactions.save(
        draft(total: 20000, occurredAt: DateTime(2026, 9, 4, 0, 30)),
      );

      final days = await transactions.spendingByDay(week);

      expect(
        days.firstWhere((d) => d.day == DateTime(2026, 9, 3)).total,
        30000,
      );
      expect(
        days.firstWhere((d) => d.day == DateTime(2026, 9, 4)).total,
        20000,
      );
    });

    test('transaksi yang dikecualikan tidak masuk grafik', () async {
      await transactions.save(
        draft(total: 25000, occurredAt: DateTime(2026, 9, 3, 12)),
      );
      await transactions.save(
        draft(
          total: 500000,
          occurredAt: DateTime(2026, 9, 3, 13),
          excludeFromBudget: true,
        ),
      );

      final days = await transactions.spendingByDay(week);
      final thursday =
          days.firstWhere((d) => d.day == DateTime(2026, 9, 3));

      expect(thursday.total, 25000);
    });

    test('periode bulanan menghasilkan satu batang per hari', () async {
      final month = calculator.monthContaining(DateTime(2026, 9, 15));

      final days = await transactions.spendingByDay(month);

      expect(days.length, 30);
    });
  });
}
