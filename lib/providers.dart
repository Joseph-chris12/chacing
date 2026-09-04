/// Titik sambung antara Riverpod dan lapisan data.
///
/// Semua provider yang menyentuh database tinggal di sini supaya mudah
/// ditimpa di tes: cukup override [databaseProvider] dengan database
/// in-memory dan seluruh pohon provider ikut memakainya.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/backup.dart';
import 'package:chacing/data/connection.dart';
import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/budget_repository.dart';
import 'package:chacing/data/repositories/category_repository.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/repositories/wallet_repository.dart';
import 'package:chacing/domain/budget_period.dart';

const _calculator = BudgetPeriodCalculator();

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(databaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(databaseProvider)),
);

/// Kategori aktif, urut sesuai urutan penyemaian.
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// Dompet aktif, yang belum diarsipkan.
final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(walletRepositoryProvider).watchAll(),
);

// ------------------------------------------------------------------ budget

/// Budget yang sedang berlaku. Null berarti belum pernah ditetapkan.
final activeBudgetProvider = StreamProvider<Budget?>(
  (ref) => ref.watch(budgetRepositoryProvider).watchActive(),
);

/// Panjang periode pilihan pengguna.
///
/// Mingguan dipakai sebagai bawaan sebelum pengguna memilih apa pun:
/// cukup longgar untuk akhir pekan, tapi masih cukup pendek untuk terasa.
final periodKindProvider = Provider<PeriodKind>((ref) {
  return ref.watch(activeBudgetProvider).value?.period ?? PeriodKind.week;
});

/// Geseran periode yang sedang dilihat: 0 = sekarang, -1 = sebelumnya.
///
/// Dipisah dari [currentPeriodProvider] supaya layar bisa menengok
/// periode lampau tanpa menyentuh pengaturan budget.
final periodOffsetProvider = StateProvider<int>((ref) => 0);

/// Periode yang sedang ditampilkan.
final currentPeriodProvider = Provider<BudgetPeriodRange>((ref) {
  final kind = ref.watch(periodKindProvider);
  final weekStartsOn =
      ref.watch(activeBudgetProvider).value?.weekStartsOn ?? DateTime.monday;

  var range = _calculator.periodContaining(
    DateTime.now(),
    kind,
    weekStartsOn: weekStartsOn,
  );

  // Melangkah satu per satu, bukan mengalikan panjang periode, karena
  // bulan tidak sama panjang.
  final offset = ref.watch(periodOffsetProvider);
  for (var i = 0; i < offset.abs(); i++) {
    range = offset < 0 ? range.previous : range.next;
  }

  return range;
});

/// Total pengeluaran sendiri dalam periode yang sedang dilihat.
final spentInPeriodProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchSpentIn(ref.watch(currentPeriodProvider));
});

/// Sisa dari periode sebelumnya, kalau rollover dinyalakan.
///
/// Dibatasi satu periode ke belakang, tidak berantai — lihat
/// [BudgetPeriodCalculator.rolloverFrom].
final rolloverProvider = FutureProvider<int>((ref) async {
  final budget = ref.watch(activeBudgetProvider).value;
  if (budget == null || !budget.rollover) return 0;

  final previous = ref.watch(currentPeriodProvider).previous;
  final spent = await ref.watch(transactionRepositoryProvider).spentIn(previous);

  return _calculator.rolloverFrom(
    previousBaseAmount: budget.amount,
    spentInPrevious: spent,
  );
});

/// Ringkasan budget siap pakai untuk layar.
final budgetStatusProvider = Provider<BudgetStatus>((ref) {
  return BudgetStatus(
    range: ref.watch(currentPeriodProvider),
    baseAmount: ref.watch(activeBudgetProvider).value?.amount ?? 0,
    rolloverAmount: ref.watch(rolloverProvider).value ?? 0,
    spent: ref.watch(spentInPeriodProvider).value ?? 0,
    now: DateTime.now(),
  );
});

// ------------------------------------------------------------------ grafik

/// Rentang yang digambar di grafik batang.
///
/// Untuk budget harian ini bukan periodenya sendiri. Satu batang tidak
/// menggambarkan irama apa pun, jadi grafiknya memundurkan tujuh hari
/// terakhir sebagai konteks — angka budgetnya tetap harian.
final chartRangeProvider = Provider<BudgetPeriodRange>((ref) {
  final range = ref.watch(currentPeriodProvider);
  if (range.kind != PeriodKind.day) return range;

  return BudgetPeriodRange(
    start: DateTime(range.end.year, range.end.month, range.end.day - 7),
    end: range.end,
    kind: PeriodKind.week,
  );
});

/// Pengeluaran per hari sepanjang rentang grafik.
final dailySpendingProvider = StreamProvider<List<DailySpending>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchSpendingByDay(ref.watch(chartRangeProvider));
});

/// Pengeluaran per kategori dalam periode, terbesar dulu.
///
/// Ikut dihitung ulang setiap ada transaksi baru dengan menumpang pada
/// stream transaksi — `spendingByCategory` sendiri hanya sekali baca.
final categorySpendingProvider =
    StreamProvider<List<CategorySpending>>((ref) async* {
  final repository = ref.watch(transactionRepositoryProvider);
  final range = ref.watch(currentPeriodProvider);

  await for (final _ in repository.watchInRange(range)) {
    yield await repository.spendingByCategory(range);
  }
});

// ------------------------------------------------------------------- daftar

/// Transaksi dalam periode yang sedang dilihat, terbaru dulu.
final periodTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchInRange(ref.watch(currentPeriodProvider));
});

/// Transaksi terbaru lintas periode.
final recentTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchRecent(),
);

// ----------------------------------------------------------------- cadangan

/// Layanan ekspor dan impor JSON.
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
