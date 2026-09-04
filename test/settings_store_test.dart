import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chacing/data/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = SettingsStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bawaannya terang, bukan mengikuti sistem', () async {
    // Merek Chacing dibangun di atas putih dan merah muda, dan itulah
    // wajah yang harus dilihat pertama kali.
    expect(SettingsStore.defaultMode, ThemeMode.light);
    expect(await store.read(), ThemeMode.light);
  });

  test('pilihan tersimpan terbaca kembali', () async {
    await store.write(ThemeMode.dark);
    expect(await store.read(), ThemeMode.dark);

    await store.write(ThemeMode.system);
    expect(await store.read(), ThemeMode.system);
  });

  test('nilai yang tidak dikenal jatuh ke bawaan, bukan melempar error', () {
    // Sisa dari versi lama tidak boleh membuat aplikasi gagal dibuka.
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    expect(store.read(), completion(ThemeMode.light));
  });
}
