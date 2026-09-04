/// Perpindahan antar periode, dipakai di beranda dan ringkasan.
///
/// Dulu bernama `WeekNavigator` dan hanya mengerti minggu. Sejak periode
/// budget bisa dipilih harian, mingguan, atau bulanan, judulnya harus ikut
/// menyesuaikan — "Minggu lalu" di atas rentang satu bulan penuh lebih
/// membingungkan daripada tidak ada judul sama sekali.
///
/// Maju dihentikan di periode berjalan: tidak ada pengeluaran di masa depan
/// untuk dilihat, dan membiarkannya hanya menghasilkan layar kosong tanpa
/// alasan yang jelas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';

class PeriodNavigator extends ConsumerWidget {
  const PeriodNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(currentPeriodProvider);
    final offset = ref.watch(periodOffsetProvider);
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Periode sebelumnya',
          onPressed: () =>
              ref.read(periodOffsetProvider.notifier).update((v) => v - 1),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _label(range.kind, offset),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _range(range),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Periode berikutnya',
          onPressed: offset >= 0
              ? null
              : () =>
                  ref.read(periodOffsetProvider.notifier).update((v) => v + 1),
        ),
      ],
    );
  }

  /// "Minggu lalu" hanya benar untuk satu periode ke belakang. Lebih jauh
  /// dari itu harus disebut jaraknya, kalau tidak dua periode berbeda
  /// akan memakai judul yang sama persis.
  String _label(PeriodKind kind, int offset) {
    final unit = switch (kind) {
      PeriodKind.day => 'Hari',
      PeriodKind.week => 'Minggu',
      PeriodKind.month => 'Bulan',
    };

    if (offset == 0) return '$unit ini';
    if (offset == -1) return '$unit lalu';
    return '${-offset} ${unit.toLowerCase()} lalu';
  }

  /// Rentang tanggalnya. Batas atas eksklusif, jadi hari terakhir yang
  /// benar-benar termasuk adalah sehari sebelum `end`.
  String _range(BudgetPeriodRange range) {
    final lastDay = DateTime(
      range.end.year,
      range.end.month,
      range.end.day - 1,
    );

    return switch (range.kind) {
      PeriodKind.day => formatFullDate(range.start),
      PeriodKind.week =>
        '${formatDayMonth(range.start)} – ${formatDayMonth(lastDay)}',
      PeriodKind.month => formatMonthYear(range.start),
    };
  }
}
