/// Tes pemadatan potongan donat.
///
/// Menyentuh rupiah: potongan "Kategori lain" harus menjumlahkan sisa
/// kategori dengan tepat, dan total donat tidak boleh berubah sepeser pun
/// karena penggabungan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/ui/widgets/category_donut.dart';

void main() {
  const other = Color(0xFF888888);

  List<DonutSlice> slices(List<int> amounts) => [
    for (var i = 0; i < amounts.length; i++)
      DonutSlice(
        label: 'K$i',
        amount: amounts[i],
        color: Color(0xFF000000 + i),
      ),
  ];

  int sum(List<DonutSlice> list) =>
      list.fold<int>(0, (total, slice) => total + slice.amount);

  test('enam kategori atau kurang tidak digabung', () {
    final result = foldDonutSlices(
      slices([60000, 50000, 40000, 30000, 20000, 10000]),
      otherColor: other,
    );

    expect(result.length, 6);
    expect(result.map((s) => s.label), isNot(contains('Kategori lain')));
  });

  test('lebih dari enam: lima teratas dan satu potongan gabungan', () {
    final result = foldDonutSlices(
      slices([70000, 60000, 50000, 40000, 30000, 20000, 15000, 5000]),
      otherColor: other,
    );

    expect(result.length, 6);
    expect(result.take(5).map((s) => s.label), ['K0', 'K1', 'K2', 'K3', 'K4']);
    expect(result.last.label, 'Kategori lain');
    expect(result.last.amount, 40000); // 20.000 + 15.000 + 5.000
    expect(result.last.color, other);
  });

  test('total tidak berubah karena penggabungan', () {
    final input = slices([123457, 98765, 45678, 34567, 23456, 12345, 999, 1]);
    final result = foldDonutSlices(input, otherColor: other);

    expect(sum(result), sum(input));
  });

  test('kategori bernilai nol tidak jadi potongan', () {
    final result = foldDonutSlices(
      slices([50000, 0, 25000, 0]),
      otherColor: other,
    );

    expect(result.map((s) => s.amount), [50000, 25000]);
  });

  test('nol yang dibuang tidak membuat penggabungan terpicu', () {
    // Tujuh baris tapi hanya enam yang berisi: tidak perlu digabung.
    final result = foldDonutSlices(
      slices([60000, 50000, 40000, 30000, 20000, 10000, 0]),
      otherColor: other,
    );

    expect(result.length, 6);
    expect(result.last.label, 'K5');
  });

  test('warna mengikuti kategorinya, bukan peringkatnya', () {
    final input = slices([10000, 90000]);
    // Urutan masuk sengaja tidak terurut: warna harus tetap menempel ke
    // label aslinya, bukan dibagikan ulang menurut posisi.
    final result = foldDonutSlices(input, otherColor: other);

    expect(result[0].label, 'K0');
    expect(result[0].color, const Color(0xFF000000));
    expect(result[1].color, const Color(0xFF000001));
  });
}
