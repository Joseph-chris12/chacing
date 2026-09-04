/// Cadangkan seluruh data ke JSON dan pulihkan kembali.
///
/// Ini satu-satunya jalan keluar data sebelum sync dibangun. Kalau HP
/// hilang atau aplikasi dipasang ulang, file inilah yang menyelamatkan
/// semuanya — jadi formatnya dibuat sederhana dan bisa dibaca manusia.
///
/// Dua penanda versi ikut disimpan dan keduanya punya tugas berbeda:
///
///  * [formatVersion] menandai susunan file cadangan itu sendiri.
///  * `schemaVersion` menandai bentuk tabel saat cadangan dibuat. File dari
///    aplikasi yang lebih baru ditolak, karena kolom yang belum dikenal
///    akan hilang diam-diam kalau tetap dipulihkan.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:chacing/data/database.dart';

/// Ringkasan isi file cadangan, untuk ditampilkan sebelum menimpa data.
class BackupContents {
  const BackupContents({
    required this.exportedAt,
    required this.wallets,
    required this.categories,
    required this.people,
    required this.transactions,
    required this.lineItems,
    required this.assignments,
    required this.payments,
    required this.budgets,
  });

  final DateTime? exportedAt;
  final int wallets;
  final int categories;
  final int people;
  final int transactions;
  final int lineItems;
  final int assignments;
  final int payments;
  final int budgets;
}

/// File cadangan yang tidak bisa dipakai. Pesannya ditulis untuk pengguna,
/// bukan untuk log — kalimat ini muncul apa adanya di layar.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const String formatName = 'chacing-backup';
  static const int formatVersion = 1;

  // ------------------------------------------------------------- cadangkan

  /// Seluruh isi database sebagai JSON.
  ///
  /// Baris yang sudah ditandai terhapus ikut dibawa. Tanpa itu, memulihkan
  /// cadangan lama akan menghidupkan kembali transaksi yang sudah sengaja
  /// dihapus pengguna.
  Future<String> exportJson() async {
    final payload = <String, dynamic>{
      'format': formatName,
      'version': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'wallets': await _rows(_db.wallets),
      'categories': await _rows(_db.categories),
      'people': await _rows(_db.people),
      'transactions': await _rows(_db.transactions),
      'lineItems': await _rows(_db.lineItems),
      'assignments': await _rows(_db.assignments),
      'payments': await _rows(_db.payments),
      'budgets': await _rows(_db.budgets),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<List<Map<String, dynamic>>> _rows<T extends Table, D>(
    ResultSetImplementation<T, D> table,
  ) async {
    final rows = await _db.select(table).get();
    return rows.map((row) => (row as DataClass).toJson()).toList();
  }

  /// Nama file yang menyertakan tanggal, supaya beberapa cadangan bisa
  /// hidup berdampingan di folder unduhan tanpa saling menimpa.
  String suggestedFileName({DateTime? now}) {
    final moment = now ?? DateTime.now();
    final stamp = '${moment.year}'
        '${moment.month.toString().padLeft(2, '0')}'
        '${moment.day.toString().padLeft(2, '0')}';
    return 'chacing-$stamp.json';
  }

  // --------------------------------------------------------------- pulihkan

  /// Memeriksa file tanpa mengubah apa pun.
  ///
  /// Dipisah dari [restore] supaya pengguna bisa melihat isinya dulu.
  /// Memulihkan akan menimpa seluruh data, dan itu tidak boleh terjadi
  /// hanya karena salah pilih file.
  BackupContents inspect(String source) {
    final map = _decode(source);

    return BackupContents(
      exportedAt: DateTime.tryParse(map['exportedAt'] as String? ?? ''),
      wallets: _listOf(map, 'wallets').length,
      categories: _listOf(map, 'categories').length,
      people: _listOf(map, 'people').length,
      transactions: _listOf(map, 'transactions').length,
      lineItems: _listOf(map, 'lineItems').length,
      assignments: _listOf(map, 'assignments').length,
      payments: _listOf(map, 'payments').length,
      budgets: _listOf(map, 'budgets').length,
    );
  }

  /// Mengganti seluruh isi database dengan isi file cadangan.
  ///
  /// Menimpa, bukan menggabungkan. Menggabungkan terdengar lebih aman tapi
  /// justru berbahaya: id yang sama dengan isi berbeda tidak punya cara
  /// diselesaikan tanpa aturan sync, dan aturan itu belum ada.
  ///
  /// Seluruhnya berjalan dalam satu transaksi database. Kalau ada satu
  /// baris yang gagal, tidak ada satu pun perubahan yang tertinggal.
  Future<void> restore(String source) async {
    final map = _decode(source);

    await _db.transaction(() async {
      // Urutan hapus mengikuti arah foreign key. Transaksi lebih dulu
      // karena anak-anaknya ikut terhapus lewat cascade.
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.wallets).go();
      await _db.delete(_db.people).go();

      // Urutan isi ulang persis kebalikannya: induk dulu, baru anaknya.
      await _insertAll(map, 'wallets', _db.wallets, Wallet.fromJson);
      await _insertAll(map, 'categories', _db.categories, Category.fromJson);
      await _insertAll(map, 'people', _db.people, Person.fromJson);
      await _insertAll(
        map,
        'transactions',
        _db.transactions,
        Transaction.fromJson,
      );
      await _insertAll(map, 'lineItems', _db.lineItems, ReceiptItem.fromJson);
      await _insertAll(
        map,
        'assignments',
        _db.assignments,
        ItemAssignment.fromJson,
      );
      await _insertAll(map, 'payments', _db.payments, Payment.fromJson);
      await _insertAll(map, 'budgets', _db.budgets, Budget.fromJson);
    });
  }

  Future<void> _insertAll<T extends Table, D>(
    Map<String, dynamic> map,
    String key,
    TableInfo<T, D> table,
    D Function(Map<String, dynamic>) parse,
  ) async {
    for (final entry in _listOf(map, key)) {
      await _db.into(table).insert(
            parse(entry) as Insertable<D>,
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Map<String, dynamic> _decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException(
        'File ini bukan JSON yang sah. Pastikan filenya belum berubah '
        'sejak dibuat.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('Isi file cadangan tidak dikenali.');
    }

    if (decoded['format'] != formatName) {
      throw const BackupFormatException(
        'File ini bukan cadangan Chacing.',
      );
    }

    final version = decoded['version'];
    if (version is! int || version > formatVersion) {
      throw const BackupFormatException(
        'Cadangan ini dibuat oleh Chacing versi yang lebih baru. '
        'Perbarui aplikasi dulu sebelum memulihkannya.',
      );
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is int && schemaVersion > _db.schemaVersion) {
      throw const BackupFormatException(
        'Cadangan ini memakai struktur data yang lebih baru. '
        'Perbarui aplikasi dulu sebelum memulihkannya.',
      );
    }

    return decoded;
  }

  List<Map<String, dynamic>> _listOf(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return const [];
    if (value is! List) {
      throw BackupFormatException('Bagian "$key" pada cadangan rusak.');
    }
    return value.cast<Map<String, dynamic>>();
  }
}
