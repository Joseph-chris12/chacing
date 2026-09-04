/// Menyimpan kunci API pembaca struk.
///
/// Kuncinya **tidak** ikut dibundel ke dalam APK. Siapa pun bisa
/// membongkar APK dan mengambil apa yang tertanam di dalamnya, jadi
/// kuncinya dimasukkan sendiri oleh pemilik aplikasi lewat layar
/// pengaturan dan disimpan di penyimpanan aman bawaan sistem —
/// Android Keystore, bukan berkas biasa.
///
/// Juga sengaja tidak disimpan di database aplikasi: isi database ikut
/// terbawa ke berkas cadangan JSON, dan berkas itu dikirim lewat share
/// sheet ke mana saja. Kunci API tidak boleh ikut menumpang di sana.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyStore {
  const ApiKeyStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _geminiKey = 'gemini_api_key';

  Future<String?> read() async {
    final value = await _storage.read(key: _geminiKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<bool> get hasKey async => await read() != null;

  Future<void> write(String key) =>
      _storage.write(key: _geminiKey, value: key.trim());

  Future<void> clear() => _storage.delete(key: _geminiKey);
}
