/// Mencari transaksi lama.
///
/// Pertanyaan yang dijawab layar ini biasanya bukan "berapa totalnya"
/// melainkan "kapan terakhir aku beli ini" dan "berapa biasanya".
/// Karena itu pencarian tidak dibatasi periode yang sedang dilihat, dan
/// hasilnya menampilkan jumlah serta total supaya kedua pertanyaan itu
/// terjawab tanpa menghitung sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/screens/quick_entry_screen.dart';
import 'package:chacing/ui/widgets/transaction_list.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(searchQueryProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearAll() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(searchCategoryProvider.notifier).state = null;
    ref.read(searchWalletProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final hasFilter = ref.watch(hasActiveFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari'),
        actions: [
          if (hasFilter)
            TextButton(onPressed: _clearAll, child: const Text('Bersihkan')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Nama tempat atau catatan',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
            ),
          ),
          _FilterRow(categories: categories, wallets: wallets),
          const Divider(height: 16),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Gagal memuat: $error')),
              data: (rows) => rows.isEmpty
                  ? const _NoResults()
                  : TransactionList(
                      transactions: rows,
                      categories: categories,
                      header: _ResultSummary(rows: rows),
                      onEdit: (row) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuickEntryScreen(existing: row),
                        ),
                      ),
                      onDelete: (row) => ref
                          .read(transactionRepositoryProvider)
                          .softDelete(row.id),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deretan penyaring kategori dan dompet.
class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.categories, required this.wallets});

  final List<Category> categories;
  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(searchCategoryProvider);
    final selectedWallet = ref.watch(searchWalletProvider);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final category in categories) ...[
            FilterChip(
              label: Text(category.name),
              selected: selectedCategory == category.id,
              onSelected: (selected) =>
                  ref.read(searchCategoryProvider.notifier).state =
                      selected ? category.id : null,
            ),
            const SizedBox(width: 8),
          ],
          // Dompet hanya ditawarkan kalau memang ada lebih dari satu.
          if (wallets.length > 1)
            for (final wallet in wallets) ...[
              FilterChip(
                label: Text(wallet.name),
                selected: selectedWallet == wallet.id,
                onSelected: (selected) =>
                    ref.read(searchWalletProvider.notifier).state =
                        selected ? wallet.id : null,
              ),
              const SizedBox(width: 8),
            ],
        ],
      ),
    );
  }
}

/// Jumlah dan total hasil pencarian.
///
/// Rata-rata ikut ditampilkan karena pertanyaan "berapa biasanya" jauh
/// lebih sering muncul daripada "berapa totalnya" saat menelusuri
/// belanjaan yang berulang.
class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.rows});

  final List<Transaction> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = rows.fold<int>(0, (sum, row) => sum + row.ownShare);
    final average = total ~/ rows.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${rows.length} transaksi · ${formatRupiah(total)}',
            style: theme.textTheme.labelLarge,
          ),
          Text(
            'rata-rata ${formatRupiah(average)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text('Tidak ada yang cocok', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Coba kata lain, atau lepas penyaringnya.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
