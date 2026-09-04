/// Warna dan bentuk untuk seluruh aplikasi.
///
/// Putih dan merah muda, mengikuti maskot cacing koral di logo.
///
/// Satu hal yang perlu diketahui sebelum mengubah angka di sini: warna
/// maskot [mascotPink] terlalu terang untuk dipakai sebagai warna tulisan
/// atau tombol. Di atas putih rasio kontrasnya hanya sekitar 2,6:1,
/// jauh di bawah batas 4,5:1 yang bisa dibaca orang. Jadi peranannya
/// dibagi dua:
///
///  * [mascotPink] untuk bidang lebar — batang grafik, isi kartu, aksen.
///  * [_rose] yang lebih pekat untuk tombol, tautan, dan tulisan berwarna.
///
/// Keduanya berasal dari keluarga warna yang sama, jadi tetap terlihat
/// satu kesatuan dengan logo.
library;

import 'package:flutter/material.dart';

/// Koral maskot, sama dengan tubuh cacing di logo.
const mascotPink = Color(0xFFFB7185);

/// Merah muda pekat untuk tombol dan tulisan berwarna.
const _rose = Color(0xFFE11D48);

/// Merah muda paling gelap, dipakai sebagai tulisan di atas bidang muda.
const _roseDeep = Color(0xFF881337);

/// Kuning amber untuk status "terlalu cepat".
///
/// Sengaja bukan merah muda yang lebih tua: kalau laju kencang dan budget
/// jebol memakai keluarga warna yang sama, keduanya tidak bisa dibedakan
/// sekilas — padahal yang satu peringatan dan yang satu sudah terlambat.
const _amber = Color(0xFFB45309);

/// Merah murni untuk budget jebol, dijauhkan dari merah muda merek.
const _danger = Color(0xFFB3261E);

const _ink = Color(0xFF1C1917);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _rose,
    brightness: Brightness.light,
  ).copyWith(
    primary: _rose,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFE4E9),
    onPrimaryContainer: _roseDeep,
    secondary: mascotPink,
    onSecondary: Colors.white,
    tertiary: _amber,
    error: _danger,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: _ink,
    // Tangga permukaan dibuat merah muda yang makin pekat, bukan abu-abu.
    // Inilah yang membuat seluruh aplikasi terasa putih-merah muda tanpa
    // perlu mewarnai tiap widget satu per satu.
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFFFF7F8),
    surfaceContainer: const Color(0xFFFEF1F4),
    surfaceContainerHigh: const Color(0xFFFCE8EC),
    surfaceContainerHighest: const Color(0xFFFADDE4),
    onSurfaceVariant: const Color(0xFF6B5257),
    outline: const Color(0xFFB79AA1),
    outlineVariant: const Color(0xFFEBD3D9),
  );

  return _themeFrom(scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _rose,
    brightness: Brightness.dark,
  ).copyWith(
    // Di latar gelap justru koral maskot yang punya kontras paling baik,
    // jadi perannya bertukar dengan yang di mode terang.
    primary: mascotPink,
    onPrimary: const Color(0xFF4C0519),
    primaryContainer: const Color(0xFF7F1D34),
    onPrimaryContainer: const Color(0xFFFFE4E9),
    secondary: const Color(0xFFFDA4AF),
    tertiary: const Color(0xFFFBBF24),
    error: const Color(0xFFFFB4AB),
    surface: const Color(0xFF171214),
    onSurface: const Color(0xFFF2E7EA),
    surfaceContainerLowest: const Color(0xFF120E0F),
    surfaceContainerLow: const Color(0xFF1E1819),
    surfaceContainer: const Color(0xFF241C1F),
    surfaceContainerHigh: const Color(0xFF2E2429),
    surfaceContainerHighest: const Color(0xFF392C32),
    onSurfaceVariant: const Color(0xFFD7BFC5),
    outline: const Color(0xFF9F8189),
    outlineVariant: const Color(0xFF524347),
  );

  return _themeFrom(scheme);
}

ThemeData _themeFrom(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Tombol utama dibuat agak lebih tumpul dari bawaan Material supaya
    // sebentuk dengan tubuh cacing yang serba membulat.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: isLight
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerHigh,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: null,
      minVerticalPadding: 10,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
