/// Ringkasan pengeluaran per kategori.
///
/// Batangnya sengaja dibuat dari `Container` biasa, bukan pustaka grafik.
/// Yang dibutuhkan cuma perbandingan panjang antar kategori, dan itu tidak
/// sepadan dengan menambah pustaka grafik ke dalam MVP.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/category_icons.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/widgets/period_navigator.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spending = ref.watch(categorySpendingProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: PeriodNavigator(),
          ),
          const Divider(height: 1),
          Expanded(
            child: spending.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Gagal memuat: $error')),
              data: (rows) => _CategoryBars(
                spending: rows,
                categories: categories,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.spending, required this.categories});

  final List<CategorySpending> spending;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    // Kategori dengan nol pengeluaran ikut terbawa dari `LEFT JOIN`.
    // Menampilkannya hanya memanjangkan daftar tanpa memberi tahu apa pun.
    final rows = spending.where((s) => s.total > 0).toList();

    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Belum ada pengeluaran di minggu ini.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    // Skala batang memakai kategori terbesar, bukan total. Kalau memakai
    // total, semua batang jadi pendek dan perbandingannya justru hilang.
    final largest = rows.first.total;
    final iconByCategoryId = {
      for (final category in categories) category.id: category.icon,
    };

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _TotalHeader(total: total);

        final row = rows[index - 1];
        return _CategoryBar(
          name: row.categoryName,
          amount: row.total,
          icon: categoryIcon(iconByCategoryId[row.categoryId]),
          fraction: largest == 0 ? 0 : row.total / largest,
          share: total == 0 ? 0 : row.total / total,
        );
      },
    );
  }
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total minggu ini', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            formatRupiah(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.amount,
    required this.icon,
    required this.fraction,
    required this.share,
  });

  final String name;
  final int amount;
  final IconData icon;

  /// Panjang batang relatif terhadap kategori terbesar.
  final double fraction;

  /// Porsi terhadap seluruh pengeluaran, untuk tulisan persen.
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                formatRupiah(amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text(
                  '${(share * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
