/// Warna kategori.
///
/// Warna disimpan di kolom `colorValue` yang sudah ada di tabel sejak
/// awal — tidak perlu mengubah tabel untuk fitur ini.
///
/// Dua hal yang menentukan bentuk berkas ini:
///
///  * Palet dibatasi dan dipilihkan, bukan pemilih warna bebas. Warna
///    bebas menghasilkan kuning pucat di atas putih yang tidak terbaca,
///    dan dua kategori berwarna nyaris sama yang tidak bisa dibedakan
///    di grafik. Palet yang dikurasi menutup kedua kemungkinan itu.
///  * Kategori yang belum diberi warna tidak dibiarkan abu-abu semua.
///    Warnanya ditentukan dari id-nya, jadi grafik langsung terbaca
///    sejak pemasangan pertama tanpa pengguna mengatur apa pun.
library;

import 'package:flutter/material.dart';

/// Palet pilihan.
///
/// Semuanya setingkat kepekatan yang sama supaya tidak ada satu kategori
/// yang tampak lebih "penting" hanya karena warnanya lebih gelap. Diawali
/// merah muda merek, lalu memutari roda warna.
const categoryPalette = <Color>[
  Color(0xFFE11D48), // rose
  Color(0xFFDB2777), // pink
  Color(0xFF9333EA), // ungu
  Color(0xFF4F46E5), // indigo
  Color(0xFF0284C7), // biru
  Color(0xFF0891B2), // sian
  Color(0xFF0D9488), // teal
  Color(0xFF16A34A), // hijau
  Color(0xFF65A30D), // lime
  Color(0xFFCA8A04), // kuning tua
  Color(0xFFEA580C), // oranye
  Color(0xFF78716C), // cokelat abu
];

/// Warna untuk satu kategori.
///
/// [stored] adalah isi `colorValue`; null berarti pengguna belum memilih.
/// [seed] dipakai untuk menentukan warna bawaan — id kategori, supaya
/// warnanya tetap sama setiap kali dibuka, bukan berubah tiap render.
Color categoryColor({
  required int? stored,
  required String seed,
  required Brightness brightness,
}) {
  final base = stored != null
      ? Color(stored)
      : categoryPalette[seed.hashCode.abs() % categoryPalette.length];

  // Di latar gelap, warna setingkat ini terlalu redup untuk dibaca
  // sebagai batang grafik. Dicerahkan sedikit, bukan diganti, supaya
  // kategori tetap dikenali sebagai warna yang sama.
  if (brightness == Brightness.dark) {
    return Color.lerp(base, Colors.white, 0.28) ?? base;
  }
  return base;
}

/// Bentuk yang disimpan ke database.
int encodeCategoryColor(Color color) => color.toARGB32();

/// Apakah [color] adalah pilihan yang tersimpan, untuk menandai swatch
/// mana yang sedang terpilih.
bool isSameSwatch(Color a, Color b) => a.toARGB32() == b.toARGB32();
