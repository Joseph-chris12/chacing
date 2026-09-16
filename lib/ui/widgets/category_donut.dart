/// Grafik donat porsi pengeluaran per kategori.
///
/// Donat hanya menjawab satu pertanyaan: "sebagian besar uangku habis ke
/// mana?" — perbandingan bagian terhadap keseluruhan, sekilas. Untuk angka
/// pasti dan perbandingan antar kategori yang nilainya berdekatan, daftar
/// batang di bawahnya tetap ada. Mata manusia buruk membandingkan besar
/// sudut, jadi donat tidak pernah dibiarkan sendirian.
///
/// Aturan yang dipegang:
///
///  * Paling banyak enam potongan. Sisanya digabung jadi "Kategori lain"
///    berwarna abu netral — lebih dari itu potongannya jadi serpihan yang
///    warnanya tidak bisa lagi dibedakan.
///  * Warna mengikuti kategorinya, sama dengan daftar di bawah dan grafik
///    lain. Kategori tidak berganti warna hanya karena peringkatnya berubah.
///  * Ada jeda 2 px di antara potongan dan nama kategori selalu tertulis di
///    daftar, jadi identitas potongan tidak pernah bergantung pada warna
///    saja. Beberapa warna di palet kategori memang berdekatan.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:chacing/ui/format.dart';

/// Satu potongan donat.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;
}

/// Potongan terbanyak sebelum sisanya digabung.
const maxDonutSlices = 6;

/// Memadatkan [slices] (sudah urut dari terbesar) menjadi paling banyak
/// [maxDonutSlices] potongan. Kalau lebih, lima teratas dipertahankan dan
/// sisanya digabung ke satu potongan [otherColor].
List<DonutSlice> foldDonutSlices(
  List<DonutSlice> slices, {
  required Color otherColor,
}) {
  final positive = [
    for (final slice in slices)
      if (slice.amount > 0) slice,
  ];
  if (positive.length <= maxDonutSlices) return positive;

  final kept = positive.take(maxDonutSlices - 1).toList();
  final rest = positive
      .skip(maxDonutSlices - 1)
      .fold<int>(0, (sum, slice) => sum + slice.amount);

  return [
    ...kept,
    DonutSlice(label: 'Kategori lain', amount: rest, color: otherColor),
  ];
}

class CategoryDonut extends StatefulWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.totalLabel,
  });

  /// Sudah dipadatkan lewat [foldDonutSlices].
  final List<DonutSlice> slices;

  /// Keterangan di tengah donat saat tidak ada yang dipilih.
  final String totalLabel;

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  /// Potongan yang sedang diketuk, atau null.
  int? _selected;

  @override
  void didUpdateWidget(CategoryDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Isi donat berganti saat berpindah periode. Pilihan lama bisa menunjuk
    // ke kategori yang berbeda, atau ke potongan yang sudah tidak ada.
    if (_selected != null && _selected! >= widget.slices.length) {
      _selected = null;
    }
  }

  void _onTouch(FlTouchEvent event, PieTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final index = response?.touchedSection?.touchedSectionIndex ?? -1;

    setState(() {
      // Mengetuk potongan yang sama, atau ruang kosong, membatalkan pilihan.
      _selected = (index < 0 || index == _selected) ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slices = widget.slices;
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amount);
    if (total <= 0) return const SizedBox.shrink();

    final selected = _selected == null ? null : slices[_selected!];

    // Pembaca layar tidak bisa melihat potongan, jadi seluruh isinya
    // dibacakan sebagai kalimat.
    final spoken = [
      for (final slice in slices)
        '${slice.label} ${(slice.amount * 100 / total).round()} persen',
    ].join(', ');

    return Semantics(
      label: 'Grafik donat pengeluaran. $spoken.',
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 2,
                centerSpaceRadius: 64,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(touchCallback: _onTouch),
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      value: slices[i].amount.toDouble(),
                      color: _selected == null || _selected == i
                          ? slices[i].color
                          : slices[i].color.withValues(alpha: 0.35),
                      radius: _selected == i ? 42 : 34,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            // Tulisan di tengah memakai warna teks, bukan warna kategori:
            // warna menandai potongan, angka harus tetap terbaca.
            IgnorePointer(
              child: SizedBox(
                width: 112,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected?.label ?? widget.totalLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatRupiah(selected?.amount ?? total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected != null)
                      Text(
                        '${(selected.amount * 100 / total).round()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
