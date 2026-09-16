/// Tes menyetel saldo dompet sesuai isi sebenarnya.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/repositories/wallet_repository.dart';
import 'package:chacing/data/seed.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late WalletRepository wallets;
  late String cashId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(db).run();
    transactions = TransactionRepository(db);
    wallets = WalletRepository(db);
    cashId = (await wallets.all()).first.id;
  });

  tearDown(() async => db.close());

  Future<int> balance() async =>
      (await transactions.watchWalletBalances().first)[cashId]!;

  Future<void> spend(int amount) => transactions.save(
    TransactionDraft(
      walletId: cashId,
      merchant: 'Warung',
      occurredAt: DateTime(2026, 9, 10, 12),
      total: amount,
    ),
  );

  test('dompet tanpa transaksi langsung bernilai yang disetel', () async {
    await wallets.setBalance(cashId, 850000);
    expect(await balance(), 850000);
  });

  test('transaksi yang sudah tercatat tidak mengacaukan angka baru', () async {
    // Sudah belanja 120rb sebelum saldo pernah disetel, jadi saldonya
    // terbaca minus. Setelah disetel, angkanya harus persis isi dompet.
    await spend(70000);
    await spend(50000);
    expect(await balance(), -120000);

    await wallets.setBalance(cashId, 500000);

    expect(await balance(), 500000);
  });

  test('pengeluaran sesudahnya mengurangi saldo yang baru disetel', () async {
    await spend(30000);
    await wallets.setBalance(cashId, 400000);

    await spend(25000);

    expect(await balance(), 375000);
  });

  test('uang masuk yang sudah tercatat ikut diperhitungkan', () async {
    await transactions.recordIncome(
      walletId: cashId,
      amount: 1000000,
      name: 'Gaji',
    );

    await wallets.setBalance(cashId, 600000);

    expect(await balance(), 600000);
  });

  test('transaksi yang dihapus tidak ikut dihitung', () async {
    await spend(90000);
    final deleted = (await transactions.watchRecent().first).single.id;
    await transactions.softDelete(deleted);

    await wallets.setBalance(cashId, 200000);
    // Memulihkan transaksi setelah saldo disetel memang mengurangi saldo:
    // uangnya dianggap keluar lagi.
    expect(await balance(), 200000);

    await transactions.restore(deleted);
    expect(await balance(), 110000);
  });

  test('riwayat transaksi tidak disentuh', () async {
    await spend(45000);

    await wallets.setBalance(cashId, 300000);

    final rows = await db.select(db.transactions).get();
    expect(rows.single.total, 45000);
  });

  test('dompet lain tidak ikut berubah', () async {
    final gopay = await wallets.create(name: 'GoPay', type: WalletType.ewallet);
    await wallets.setBalance(gopay, 75000);

    await wallets.setBalance(cashId, 500000);

    final balances = await transactions.watchWalletBalances().first;
    expect(balances[gopay], 75000);
    expect(balances[cashId], 500000);
  });

  test('menandai dompet perlu disinkronkan', () async {
    await wallets.setBalance(cashId, 10000);

    final row = (await wallets.findById(cashId))!;
    expect(row.isDirty, isTrue);
  });
}
