/// Pengaturan tampilan yang dipilih pengguna.
///
/// Disimpan di preferensi bawaan sistem, bukan di database aplikasi.
/// Dua alasannya: isi database ikut terbawa ke berkas cadangan JSON dan
/// pilihan tampilan tidak ada gunanya dipindahkan antar HP, dan mengubah
/// tabel berarti menaikkan `schemaVersion` untuk sesuatu yang bahkan
/// bukan data keuangan.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  const SettingsStore();

  static const _themeKey = 'theme_mode';

  /// Bawaan aplikasi adalah terang.
  ///
  /// Sengaja bukan `ThemeMode.system`: merek Chacing dibangun di atas
  /// putih dan merah muda, dan itulah wajah yang harus dilihat pertama
  /// kali. Mode gelap tetap tersedia, tapi sebagai pilihan sadar.
  static const defaultMode = ThemeMode.light;

  Future<ThemeMode> read() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_themeKey));
  }

  Future<void> write(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// Nilai yang tidak dikenal — misalnya sisa versi lama — jatuh kembali
  /// ke bawaan alih-alih melempar error saat aplikasi dibuka.
  ThemeMode _parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => defaultMode,
    };
  }
}
