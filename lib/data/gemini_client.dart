/// Mengirim foto struk ke Gemini dan meminta hasilnya sebagai JSON.
///
/// Semua penguraian jawabannya ada di [ReceiptParser] yang murni Dart dan
/// bertes. Kelas ini hanya mengurus jaringan, supaya bagian yang paling
/// mudah salah tidak ikut butuh koneksi untuk diuji.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:chacing/domain/receipt_draft.dart';

/// Gagal menghubungi atau memakai layanan pembaca struk.
///
/// Pesannya ditulis untuk dibaca pengguna, bukan untuk log.
class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiReceiptScanner {
  GeminiReceiptScanner({http.Client? client, ReceiptParser? parser})
      : _client = client ?? http.Client(),
        _parser = parser ?? const ReceiptParser();

  final http.Client _client;
  final ReceiptParser _parser;

  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Perintah untuk modelnya.
  ///
  /// Ditulis dalam bahasa Inggris karena model lebih patuh pada struktur
  /// dengan bahasa itu, tapi isinya khusus struk Indonesia: pemisah ribuan
  /// memakai titik, dan "PPN" serta "pajak" berarti hal yang sama.
  static const _prompt = '''
You are reading an Indonesian receipt. Return ONLY a JSON object, no prose.

{
  "merchant": string,
  "date": "YYYY-MM-DD" or null,
  "items": [
    {"name": string, "quantity": integer, "unit_price": integer,
     "confidence": integer 0-100}
  ],
  "subtotal": integer,
  "tax": integer,
  "service_charge": integer,
  "discount": integer,
  "total": integer
}

Rules:
- All money values are whole Indonesian rupiah as integers, no decimals,
  no separators, no currency symbol. "Rp 25.000" becomes 25000.
- "PPN", "PB1" and "Pajak" all mean tax. "Service" and "Servis" mean
  service_charge.
- unit_price is the price of ONE unit, not the line total.
- confidence reflects how clearly you could read that line.
- Use 0 for any field that is not printed on the receipt.
''';

  /// Membaca struk dari [imageBytes].
  Future<ReceiptDraft> scan({
    required Uint8List imageBytes,
    required String apiKey,
    String mimeType = 'image/jpeg',
  }) async {
    final uri = Uri.parse('$_endpoint/$_model:generateContent');

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              // Kunci dikirim lewat header, bukan sebagai parameter URL.
              // Parameter URL gampang bocor ke log server dan riwayat.
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Encode(imageBytes),
                      }
                    },
                  ],
                }
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                // Suhu nol: membaca struk bukan pekerjaan kreatif.
                'temperature': 0,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (error) {
      throw const ReceiptScanException(
        'Tidak bisa menghubungi layanan pembaca struk. Periksa koneksi '
        'internetmu lalu coba lagi.',
      );
    }

    if (response.statusCode >= 400) {
      // Alasan asli dari Google ikut ditampilkan. Pesan seragam
      // "kunci ditolak" menyembunyikan bedanya kunci salah ketik, API
      // yang belum diaktifkan, dan kunci yang dibatasi ke domain —
      // padahal ketiganya butuh perbaikan yang berbeda.
      final detail = _errorDetail(response.body);
      final suffix = detail.isEmpty ? '' : '\n\n$detail';

      if (response.statusCode == 429) {
        throw ReceiptScanException(
          'Kuota pembacaan struk sudah habis. Coba lagi nanti, atau '
          'catat manual dulu.$suffix',
        );
      }
      if (response.statusCode == 400 || response.statusCode == 403) {
        throw ReceiptScanException(
          'Kunci API ditolak (${response.statusCode}).$suffix\n\n'
          'Periksa kuncinya di Pengaturan, dan pastikan Gemini API sudah '
          'aktif untuk akun itu serta kuncinya tidak dibatasi ke aplikasi '
          'atau domain tertentu.',
        );
      }
      throw ReceiptScanException(
        'Layanan pembaca struk sedang bermasalah '
        '(${response.statusCode}).$suffix',
      );
    }

    return _parser.parse(_extractText(response.body));
  }

  /// Mengambil kalimat error milik Google dari balasan gagal.
  ///
  /// Bentuknya `{"error": {"message": ...}}`. Kalau tidak berbentuk
  /// itu, lebih baik mengembalikan kosong daripada menampilkan potongan
  /// JSON mentah ke pengguna.
  String _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return '';

      final error = decoded['error'];
      if (error is! Map) return '';

      final message = error['message'];
      return message is String ? message.trim() : '';
    } on FormatException {
      return '';
    }
  }

  /// Mengambil teks jawaban dari bungkus balasan Gemini.
  String _extractText(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const ReceiptScanException(
        'Jawaban dari layanan pembaca struk tidak dikenali.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ReceiptScanException(
        'Jawaban dari layanan pembaca struk tidak dikenali.',
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const ReceiptScanException(
        'Struk tidak terbaca. Coba foto ulang dengan cahaya lebih terang.',
      );
    }

    final parts = (candidates.first as Map?)?['content']?['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const ReceiptScanException(
        'Struk tidak terbaca. Coba foto ulang dengan cahaya lebih terang.',
      );
    }

    final text = (parts.first as Map?)?['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const ReceiptScanException(
        'Struk tidak terbaca. Coba foto ulang dengan cahaya lebih terang.',
      );
    }

    return text;
  }

  void dispose() => _client.close();
}
