/// Tren bulanan dan dugaan langganan.
///
/// Dua pertanyaan yang tidak bisa dijawab layar mingguan: apakah
/// belakangan ini makin boros, dan ke mana uang yang keluar sendiri tiap
/// bulan tanpa pernah terasa sebagai keputusan belanja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/domain/recurring_detector.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';

class TrendScreen extends ConsumerWidget {
  const TrendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthly = ref.watch(monthlySpendingProvider);
    final recurring = ref.watch(recurringProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tren')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Enam bulan terakhir',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          monthly.when(
            loading: () => const SizedBox(height: 180),
            error: (error, _) => Text('Grafik gagal dimuat: $error'),
            data: (months) => _MonthlyChart(months: months),
          ),
          const Divider(height: 36),
          Text('Sepertinya langganan',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Pengeluaran yang muncul berulang dengan nominal dan jarak '
            'yang mirip. Ini dugaan, bukan kepastian.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          recurring.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Gagal memuat: $error'),
            data: (rows) => rows.isEmpty
                ? const _NoRecurring()
                : Column(
                    children: [
                      for (final candidate in rows)
                        _RecurringTile(candidate: candidate),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Batang pengeluaran per bulan.
///
/// Batang biasa, bukan pustaka grafik: yang dibutuhkan cuma perbandingan
/// tinggi antar bulan, dan itu tidak sepadan dengan menambah pustaka.
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.months});

  final List<MonthlySpending> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highest = months.fold<int>(0, (max, m) => m.total > max ? m.total : max);

    if (highest == 0) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Belum ada cukup data untuk melihat tren.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    // Bulan berjalan belum selesai, jadi batangnya wajar lebih pendek.
    // Ditandai supaya tidak terbaca sebagai penurunan pengeluaran.
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final month in months)
            Expanded(
              child: _MonthBar(
                month: month,
                fraction: month.total / highest,
                isCurrent: month.month == currentMonth,
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.fraction,
    required this.isCurrent,
  });

  final MonthlySpending month;
  final double fraction;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            month.total == 0 ? '' : _short(month.total),
            style: theme.textTheme.labelSmall,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Container(
            height: (fraction * 110).clamp(2.0, 110.0),
            decoration: BoxDecoration(
              color: isCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.45)
                  : theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMonthShort(month.month),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// Rp 1.250.000 jadi "1,2jt" supaya muat di atas batang yang sempit.
  String _short(int amount) {
    if (amount >= 1000000) {
      final juta = amount / 1000000;
      return '${juta.toStringAsFixed(juta >= 10 ? 0 : 1)}jt';
    }
    if (amount >= 1000) return '${(amount / 1000).round()}rb';
    return '$amount';
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({required this.candidate});

  final RecurringCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(candidate.merchant),
        subtitle: Text(
          '${candidate.cadence.label} · '
          '${formatRupiah(candidate.typicalAmount)} · '
          '${candidate.occurrences}x tercatat',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Angka setahun ditaruh paling menonjol. Rp 55.000 sebulan
            // terdengar kecil sampai ditulis sebagai Rp 660.000 setahun.
            Text(
              formatRupiah(candidate.yearlyCost),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('per tahun', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _NoRecurring extends StatelessWidget {
  const _NoRecurring();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Belum ada pola yang cukup jelas. Butuh minimal tiga kali '
        'pencatatan dengan nominal dan jarak yang mirip.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
