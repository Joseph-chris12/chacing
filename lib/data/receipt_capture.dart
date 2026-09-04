/// Mengambil foto struk lalu membacanya.
///
/// Dipisah dari layarnya karena dipakai dua tempat: layar scan yang
/// menyimpan langsung, dan layar bagi tagihan yang memakai itemnya untuk
/// ditugaskan ke orang. Menyalin alurnya ke dua tempat berarti perbaikan
/// pada satu sisi diam-diam tidak ikut di sisi lain.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chacing/data/api_key_store.dart';
import 'package:chacing/data/gemini_client.dart';
import 'package:chacing/data/settings_store.dart';
import 'package:chacing/domain/receipt_draft.dart';

/// Kunci API belum dipasang.
///
/// Dibedakan dari kegagalan lain karena penanganannya berbeda: yang ini
/// bukan error yang perlu ditampilkan, melainkan layar pengaturan yang
/// perlu dibuka.
class MissingApiKeyException implements Exception {
  const MissingApiKeyException();
}

/// Hasil pemindaian beserta foto aslinya.
typedef CapturedReceipt = ({ReceiptDraft draft, String photoPath});

// Linter menyarankan initializing formal (`this._keyStore`), tapi
// parameter bernama tidak boleh diawali garis bawah di Dart, jadi
// saran itu tidak bisa diterapkan untuk field privat.
// ignore_for_file: prefer_initializing_formals
class ReceiptCapture {
  ReceiptCapture({
    required ApiKeyStore keyStore,
    required GeminiReceiptScanner scanner,
    required SettingsStore settings,
    ImagePicker? picker,
  })  : _keyStore = keyStore,
        _scanner = scanner,
        _settings = settings,
        _picker = picker ?? ImagePicker();

  final ApiKeyStore _keyStore;

  final GeminiReceiptScanner _scanner;

  final SettingsStore _settings;

  final ImagePicker _picker;

  /// Mengambil foto dari [source] lalu membacanya.
  ///
  /// Mengembalikan null kalau pengguna membatalkan pemilihan foto.
  /// Melempar [MissingApiKeyException] kalau kuncinya belum dipasang,
  /// dan [ReceiptScanException] atau [ReceiptParseException] kalau
  /// pembacaannya gagal.
  Future<CapturedReceipt?> capture(ImageSource source) async {
    final apiKey = await _keyStore.read();
    if (apiKey == null) throw const MissingApiKeyException();

    final picked = await _picker.pickImage(
      source: source,
      // Struk itu tinggi dan sempit; sisi terpanjang 1600 px sudah cukup
      // untuk membaca angka, dan jauh lebih hemat kuota daripada foto
      // penuh 12 megapiksel.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final draft = await _scanner.scan(
      imageBytes: await _compress(picked.path),
      apiKey: apiKey,
      model: await _settings.readScanModel(),
    );

    return (draft: draft, photoPath: picked.path);
  }

  /// Memampatkan foto sebelum dikirim.
  ///
  /// Menghemat kuota dan waktu unggah. Kalau pemampatan gagal, foto asli
  /// tetap dikirim — lebih baik boros sedikit daripada gagal sama sekali.
  Future<Uint8List> _compress(String path) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: 1000,
      minHeight: 1000,
      quality: 80,
    );
    return compressed ?? await File(path).readAsBytes();
  }
}
