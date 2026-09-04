/// Beranda: sisa budget, irama belanja, dan daftar transaksi.
///
/// Urutan dari atas ke bawah mengikuti urutan pertanyaan yang muncul di
/// kepala saat membuka aplikasi keuangan:
///
///  1. Masih boleh pakai berapa?         → ringkasan budget
///  2. Belakangan ini boros atau tidak?  → grafik batang per hari
///  3. Yang mana saja?                   → daftar transaksi per hari
///
/// Pertanyaan keempat, "habis buat apa", dijawab di [SummaryScreen] yang
/// tinggal satu ketukan dari sini. Menaruhnya sekalian di beranda membuat
/// layar ini harus digulir jauh sebelum sampai ke daftar transaksi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/screens/backup_screen.dart';
import 'package:chacing/ui/screens/budget_settings_screen.dart';
import 'package:chacing/ui/screens/categories_screen.dart';
import 'package:chacing/ui/screens/people_screen.dart';
import 'package:chacing/ui/screens/quick_entry_screen.dart';
import 'package:chacing/ui/screens/scan_receipt_screen.dart';
import 'package:chacing/ui/screens/search_screen.dart';
import 'package:chacing/ui/screens/split_bill_screen.dart';
import 'package:chacing/ui/screens/summary_screen.dart';
import 'package:chacing/ui/screens/trend_screen.dart';
import 'package:chacing/ui/screens/wallets_screen.dart';
import 'package:chacing/ui/widgets/budget_summary.dart';
import 'package:chacing/ui/widgets/period_navigator.dart';
import 'package:chacing/ui/widgets/spending_bar_chart.dart';
import 'package:chacing/ui/widgets/transaction_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openEntry(BuildContext context, {Transaction? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickEntryScreen(existing: existing),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Tersimpan' : 'Perubahan tersimpan'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Menghapus dengan jaring pengaman.
  ///
  /// Penghapusan hanya mengisi `deletedAt`, jadi membatalkannya cukup
  /// memulihkan baris yang sama — tidak ada data yang perlu disusun ulang.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Transaction row,
  ) async {
    final repository = ref.read(transactionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    await repository.softDelete(row.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text('${row.merchant} dihapus'),
        action: SnackBarAction(
          label: 'Batalkan',
          onPressed: () => repository.restore(row.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(budgetStatusProvider);
    final daily = ref.watch(dailySpendingProvider);
    final transactions = ref.watch(periodTransactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PeriodNavigator(),
        BudgetSummary(
          status: status,
          onTap: () => Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
          ),
        ),
        const Divider(height: 20),
        _SectionTitle(
          title: status.range.kind == PeriodKind.day
              ? 'Tujuh hari terakhir'
              : 'Per hari',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
          child: daily.when(
            loading: () => const SizedBox(height: 160),
            error: (error, _) => SizedBox(
              height: 160,
              child: Center(child: Text('Grafik gagal dimuat: $error')),
            ),
            data: (days) => SpendingBarChart(
              days: days,
              idealDailyPace: status.idealDailyPace,
            ),
          ),
        ),
        const Divider(height: 20),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chacing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari transaksi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Ringkasan per kategori',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SummaryScreen()),
            ),
          ),
          PopupMenuButton<_HomeMenu>(
            tooltip: 'Pengaturan',
            onSelected: (item) => _openMenuItem(context, item),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HomeMenu.scan,
                child: ListTile(
                  leading: Icon(Icons.document_scanner_outlined),
                  title: Text('Scan struk'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _HomeMenu.split,
                child: ListTile(
                  leading: Icon(Icons.groups_outlined),
                  title: Text('Bagi tagihan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _HomeMenu.trend,
                child: ListTile(
                  leading: Icon(Icons.show_chart),
                  title: Text('Tren bulanan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _HomeMenu.budget,
                child: ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Atur budget'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _HomeMenu.wallets,
                child: ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined),
                  title: Text('Dompet'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _HomeMenu.categories,
                child: ListTile(
                  leading: Icon(Icons.label_outline),
                  title: Text('Kategori'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _HomeMenu.people,
                child: ListTile(
                  leading: Icon(Icons.people_outline),
                  title: Text('Orang'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _HomeMenu.backup,
                child: ListTile(
                  leading: Icon(Icons.backup_outlined),
                  title: Text('Cadangkan & pulihkan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
        data: (rows) => TransactionList(
          transactions: rows,
          categories: categories,
          header: header,
          onEdit: (row) => _openEntry(context, existing: row),
          onDelete: (row) => _delete(context, ref, row),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntry(context),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
    );
  }
}

/// Isi menu pengaturan di pojok kanan atas.
enum _HomeMenu {
  scan,
  split,
  trend,
  budget,
  wallets,
  categories,
  people,
  backup,
}

extension on HomeScreen {
  void _openMenuItem(BuildContext context, _HomeMenu item) {
    final builder = switch (item) {
      _HomeMenu.scan => (BuildContext _) => const ScanReceiptScreen(),
      _HomeMenu.split => (BuildContext _) => const SplitBillScreen(),
      _HomeMenu.trend => (BuildContext _) => const TrendScreen(),
      _HomeMenu.budget => (BuildContext _) => const BudgetSettingsScreen(),
      _HomeMenu.wallets => (BuildContext _) => const WalletsScreen(),
      _HomeMenu.categories => (BuildContext _) => const CategoriesScreen(),
      _HomeMenu.people => (BuildContext _) => const PeopleScreen(),
      _HomeMenu.backup => (BuildContext _) => const BackupScreen(),
    };

    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
