import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/ui/category_colors.dart';

void main() {
  group('warna tersimpan', () {
    test('warna pilihan pengguna dipakai apa adanya di tema terang', () {
      final color = categoryColor(
        stored: encodeCategoryColor(categoryPalette[3]),
        seed: 'apa-saja',
        brightness: Brightness.light,
      );

      expect(color.toARGB32(), categoryPalette[3].toARGB32());
    });

    test('warna dicerahkan di tema gelap, tapi tetap warna yang sama', () {
      const base = Color(0xFF0284C7);
      final dark = categoryColor(
        stored: encodeCategoryColor(base),
        seed: 'apa-saja',
        brightness: Brightness.dark,
      );

      expect(dark.toARGB32(), isNot(base.toARGB32()));
      // Masih biru: komponen biru tetap yang paling besar.
      expect(dark.b, greaterThan(dark.r));
      expect(dark.b, greaterThan(dark.g));
    });
  });

  group('warna bawaan', () {
    test('kategori tanpa warna tetap dapat warna, bukan abu-abu', () {
      final color = categoryColor(
        stored: null,
        seed: 'kategori-baru',
        brightness: Brightness.light,
      );

      expect(
        categoryPalette.map((c) => c.toARGB32()),
        contains(color.toARGB32()),
      );
    });

    test('warna bawaan tetap sama setiap kali dihitung', () {
      // Kalau berubah tiap render, kategori yang sama akan berpindah
      // warna setiap grafik digambar ulang.
      Color of() => categoryColor(
            stored: null,
            seed: 'id-yang-sama',
            brightness: Brightness.light,
          );

      expect(of().toARGB32(), of().toARGB32());
    });

    test('id berbeda cenderung dapat warna berbeda', () {
      final colors = {
        for (final seed in ['a', 'b', 'c', 'd', 'e', 'f'])
          categoryColor(
            stored: null,
            seed: seed,
            brightness: Brightness.light,
          ).toARGB32(),
      };

      // Bukan jaminan semuanya unik — yang penting tidak semuanya sama.
      expect(colors.length, greaterThan(1));
    });
  });

  test('palet cukup banyak untuk kategori bawaan', () {
    expect(categoryPalette.length, greaterThanOrEqualTo(7));
  });
}
