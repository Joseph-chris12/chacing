/// Hasil pembacaan struk yang belum dikonfirmasi pengguna.
///
/// Sengaja terpisah dari `TransactionDraft`: yang keluar dari OCR adalah
/// **tebakan**, dan tebakan tidak boleh diam-diam menjadi catatan
/// keuangan. Semua isinya harus lewat layar konfirmasi dulu.
///
/// Struktur ini murni Dart supaya penguraiannya bisa diuji tanpa jaringan
/// maupun kamera — dan penguraian itulah bagian yang paling mudah salah.
library;

import 'dart:convert';

/// Satu baris hasil pembacaan, beserta seberapa yakin modelnya.
class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.confidence,
  });

  final String name;
  final int quantity;
  final int unitPrice;

  /// Skor 0–100 dari model. Null kalau tidak diberikan.
  final int? confidence;

  int get total => quantity * unitPrice;

  /// Baris yang perlu disorot supaya diperiksa manusia.
  bool get isDoubtful => confidence != null && confidence! < 70;
}

class ReceiptDraft {
  const ReceiptDraft({
    this.merchant,
    this.occurredAt,
    this.items = const [],
    this.subtotal = 0,
    this.tax = 0,
    this.serviceCharge = 0,
    this.discount = 0,
    this.total = 0,
    this.warnings = const [],
  });

  final String? merchant;
  final DateTime? occurredAt;
  final List<ScannedItem> items;
  final int subtotal;
  final int tax;
  final int serviceCharge;
  final int discount;
  final int total;
  final List<String> warnings;

  int get itemsTotal => items.fold<int>(0, (sum, item) => sum + item.total);

  /// Selisih antara total yang terbaca dan hasil menjumlahkan item.
  ///
  /// Nol berarti pembacaannya konsisten. Tidak nol berarti ada baris yang
  /// terlewat atau salah baca — dan pengguna harus tahu sebelum menyimpan.
  int get discrepancy => total - (itemsTotal + tax + serviceCharge - discount);

  bool get isConsistent => discrepancy == 0;

  bool get hasDoubtfulItems => items.any((item) => item.isDoubtful);
}

/// Gagal menguraikan jawaban model.
class ReceiptParseException implements Exception {
  const ReceiptParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mengubah jawaban JSON dari model menjadi [ReceiptDraft].
///
/// Ditulis defensif dengan sengaja. Model bahasa kadang mengembalikan
/// angka sebagai teks, menambahkan pagar ```json di sekelilingnya, atau
/// menyisipkan kalimat penjelasan. Semua itu ditangani di sini supaya
/// tidak ada satu pun kemungkinan yang berakhir sebagai nominal salah
/// yang diam-diam tersimpan.
class ReceiptParser {
  const ReceiptParser();

  ReceiptDraft parse(String source) {
    final json = _decodeObject(source);
    final warnings = <String>[];

    final items = <ScannedItem>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is! Map) continue;
        final name = _asString(entry['name']);
        final unitPrice = _asInt(entry['unit_price'] ?? entry['price']);
        if (name.isEmpty || unitPrice <= 0) continue;

        // Kuantitas nol atau tidak terbaca dianggap satu. Membuang
        // barisnya justru membuat totalnya meleset tanpa jejak.
        final quantity = _asInt(entry['quantity']).clamp(1, 999);

        items.add(
          ScannedItem(
            name: name,
            quantity: quantity,
            unitPrice: unitPrice,
            confidence: entry['confidence'] == null
                ? null
                : _asInt(entry['confidence']).clamp(0, 100),
          ),
        );
      }
    }

    if (items.isEmpty) {
      warnings.add('Tidak ada baris item yang terbaca dari struk ini.');
    }

    final draft = ReceiptDraft(
      merchant: _asString(json['merchant']).isEmpty
          ? null
          : _asString(json['merchant']),
      occurredAt: _asDate(json['date'] ?? json['occurred_at']),
      items: items,
      subtotal: _asInt(json['subtotal']),
      tax: _asInt(json['tax']),
      serviceCharge: _asInt(json['service_charge'] ?? json['service']),
      discount: _asInt(json['discount']),
      total: _asInt(json['total']),
      warnings: warnings,
    );

    if (draft.total <= 0) {
      return ReceiptDraft(
        merchant: draft.merchant,
        occurredAt: draft.occurredAt,
        items: draft.items,
        subtotal: draft.subtotal,
        tax: draft.tax,
        serviceCharge: draft.serviceCharge,
        discount: draft.discount,
        // Total yang tidak terbaca diganti hasil hitung sendiri, dan
        // pengguna diberi tahu bahwa angka itu bukan dari struk.
        total: draft.itemsTotal + draft.tax + draft.serviceCharge -
            draft.discount,
        warnings: [
          ...draft.warnings,
          'Total tidak terbaca; dihitung dari item. Periksa kembali.',
        ],
      );
    }

    if (!draft.isConsistent) {
      return ReceiptDraft(
        merchant: draft.merchant,
        occurredAt: draft.occurredAt,
        items: draft.items,
        subtotal: draft.subtotal,
        tax: draft.tax,
        serviceCharge: draft.serviceCharge,
        discount: draft.discount,
        total: draft.total,
        warnings: [
          ...draft.warnings,
          'Jumlah item tidak cocok dengan total struk, selisih '
              'Rp ${draft.discrepancy.abs()}.',
        ],
      );
    }

    return draft;
  }

  Map<String, dynamic> _decodeObject(String source) {
    var text = source.trim();

    // Model sering membungkus jawabannya dengan pagar kode.
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fenced = fence.firstMatch(text);
    if (fenced != null) text = fenced.group(1)!.trim();

    // Kalau masih ada kalimat pengantar, ambil objek JSON pertama.
    if (!text.startsWith('{')) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) text = text.substring(start, end + 1);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const ReceiptParseException(
        'Jawaban dari layanan pembaca struk tidak bisa dibaca. Coba ulangi '
        'dengan foto yang lebih terang.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ReceiptParseException(
        'Struk tidak terbaca. Coba foto ulang dari jarak lebih dekat.',
      );
    }

    return decoded;
  }

  String _asString(Object? value) => value is String ? value.trim() : '';

  /// Membaca nominal dari apa pun bentuknya.
  ///
  /// Model bisa mengembalikan `25000`, `"25000"`, `"Rp 25.000"`, atau
  /// `25000.0`. Semua harus mendarat sebagai rupiah bulat yang sama.
  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final digits = value.replaceAll(RegExp(r'[^0-9-]'), '');
      return int.tryParse(digits) ?? 0;
    }
    return 0;
  }

  DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value.trim());
  }
}
