/// Tes pindah dana dan saldo dompet.
///
/// Memindahkan uang antar dompet sendiri bukan pengeluaran. Kalau sampai
/// terhitung sebagai pengeluaran, budget mingguan langsung jebol hanya
/// karena seseorang memindahkan uang dari bank ke e-wallet.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/repositories/wallet_repository.dart';
import 'package:chacing/data/seed.dart';
import 'package:chacing/domain/budget_period.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late WalletRepository wallets;
  late String cashId;
  late String ewalletId;

  const calculator = BudgetPeriodCalculator();
  final week = calculator.weekContaining(DateTime(2026, 9, 3));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(db).run();
    repository = TransactionRepository(db);
    wallets = WalletRepository(db);

    cashId = (await wallets.all()).first.id;
    ewalletId = await wallets.create(name: 'GoPay', type: WalletType.ewallet);
  });

  tearDown(() async => db.close());

  group('pindah dana', () {
    test('mencatat sepasang transaksi berlawanan', () async {
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: ewalletId,
        amount: 200000,
        occurredAt: DateTime(2026, 9, 3, 10),
      );

      final rows = await db.select(db.transactions).get();
      expect(rows.length, 2);

      final out = rows.firstWhere((t) => t.walletId == cashId);
      final into = rows.firstWhere((t) => t.walletId == ewalletId);

      expect(out.total, 200000);
      expect(into.total, -200000);
    });

    test('tidak ikut dihitung sebagai pengeluaran', () async {
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: ewalletId,
        amount: 200000,
        occurredAt: DateTime(2026, 9, 3, 10),
      );

      // Inilah yang paling penting: memindahkan uang tidak boleh
      // memakan budget sepeser pun.
      expect(await repository.spentIn(week), 0);
    });

    test('namanya menyebut dompet lawannya', () async {
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: ewalletId,
        amount: 50000,
      );

      final rows = await db.select(db.transactions).get();
      final out = rows.firstWhere((t) => t.walletId == cashId);
      final into = rows.firstWhere((t) => t.walletId == ewalletId);

      expect(out.merchant, 'Pindah ke GoPay');
      expect(into.merchant, 'Terima dari Tunai');
    });

    test('nominal nol atau minus diabaikan', () async {
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: ewalletId,
        amount: 0,
      );
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: ewalletId,
        amount: -5000,
      );

      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('pindah ke dompet yang sama diabaikan', () async {
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: cashId,
        amount: 50000,
      );

      expect(await db.select(db.transactions).get(), isEmpty);
    });
  });

  group('saldo dompet', () {
    test('pindah dana menggeser saldo tanpa mengubah jumlah totalnya',
        () async {
      await repository.transfer(
        fromWalletId: cashId,
        toWalletId: ewalletId,
        amount: 200000,
      );

      final balances = await repository.watchWalletBalances().first;

      expect(balances[cashId], -200000);
      expect(balances[ewalletId], 200000);
      // Uangnya cuma berpindah tempat, tidak bertambah atau berkurang.
      expect(balances.values.reduce((a, b) => a + b), 0);
    });

    test('saldo memakai total struk, bukan porsi sendiri', () async {
      // Menalangi makan bertiga: Rp 90.000 benar-benar keluar dari dompet
      // meski porsi sendiri hanya sepertiganya.
      await repository.save(
        TransactionDraft(
          walletId: cashId,
          merchant: 'Makan bareng',
          occurredAt: DateTime(2026, 9, 3, 12),
          total: 90000,
        ),
      );

      final balances = await repository.watchWalletBalances().first;
      expect(balances[cashId], -90000);
    });

    test('saldo awal ikut diperhitungkan', () async {
      final bankId = await wallets.create(
        name: 'BCA',
        type: WalletType.bank,
        initialBalance: 1000000,
      );

      await repository.save(
        TransactionDraft(
          walletId: bankId,
          merchant: 'Listrik',
          occurredAt: DateTime(2026, 9, 3),
          total: 250000,
        ),
      );

      final balances = await repository.watchWalletBalances().first;
      expect(balances[bankId], 750000);
    });

    test('transaksi terhapus tidak ikut mengurangi saldo', () async {
      final saved = await repository.save(
        TransactionDraft(
          walletId: cashId,
          merchant: 'Salah catat',
          occurredAt: DateTime(2026, 9, 3),
          total: 75000,
        ),
      );
      await repository.softDelete(saved.transactionId);

      final balances = await repository.watchWalletBalances().first;
      expect(balances[cashId], 0);
    });
  });
}
