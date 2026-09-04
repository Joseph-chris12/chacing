/// Grafik batang pengeluaran per hari.
///
/// Tujuannya bukan presisi — untuk angka pastinya ada daftar transaksi.
/// Tujuannya menunjukkan *irama*: hari apa yang boros, apakah akhir pekan
/// selalu melonjak, apakah ada hari yang benar-benar kosong.
///
/// Batang yang melewati laju harian ideal diberi warna berbeda. Itu
/// menyampaikan "hari ini kelewatan" tanpa satu kalimat pun, dan tanpa
/// menghakimi seperti tulisan "Kamu boros!".
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/ui/format.dart';

class SpendingBarChart extends StatelessWidget {
  const SpendingBarChart({
    super.key,
    required this.days,
    required this.idealDailyPace,
  });

  final List<DailySpending> days;

  /// Laju harian ideal. Nol berarti pengguna belum menetapkan budget,
  /// dan tidak ada batang yang perlu ditandai.
  final int idealDailyPace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (days.isEmpty) return const SizedBox.shrink();

    final highest = days.fold<int>(0, (max, d) => d.total > max ? d.total : max);

    // Sumbu Y tetap punya tinggi walau semua nol, supaya grafik kosong
    // tetap tergambar sebagai garis dasar dan bukan kotak melompong.
    final maxY = highest == 0 ? 1.0 : highest * 1.25;

    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = days[group.x];
                return BarTooltipItem(
                  '${formatDayMonth(day.day)}\n',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: formatRupiah(day.total),
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }

                  // Sebulan penuh terlalu rapat untuk 30 label. Ambil
                  // setiap hari kelima supaya tetap terbaca.
                  final crowded = days.length > 10;
                  if (crowded && index % 5 != 0) {
                    return const SizedBox.shrink();
                  }

                  final day = days[index].day;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      crowded ? '${day.day}' : formatShortWeekday(day),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            isToday(day) ? FontWeight.w700 : FontWeight.w400,
                        color: isToday(day)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].total.toDouble(),
                    width: days.length > 10 ? 6 : 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    color: _barColor(
                      theme: theme,
                      amount: days[i].total,
                      isToday: isToday(days[i].day),
                    ),
                    // Batang latar setinggi sumbu, supaya hari tanpa
                    // pengeluaran tetap terlihat sebagai tempat kosong
                    // dan bukan hilang sama sekali.
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _barColor({
    required ThemeData theme,
    required int amount,
    required bool isToday,
  }) {
    final overPace = idealDailyPace > 0 && amount > idealDailyPace;

    if (overPace) return theme.colorScheme.error.withValues(alpha: 0.75);
    if (isToday) return theme.colorScheme.primary;
    return theme.colorScheme.primary.withValues(alpha: 0.55);
  }
}
