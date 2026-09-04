/// Data awal yang harus ada sebelum aplikasi bisa dipakai.
///
/// Dijalankan sekali saat aplikasi pertama kali dibuka. Aman dipanggil
/// berulang kali: setiap bagian memeriksa dulu apakah datanya sudah ada,
/// jadi tidak akan menggandakan apa pun.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';

/// Kategori bawaan. Ditandai `isSystem` supaya tidak bisa dihapus —
/// pengguna boleh mengganti nama dan ikonnya, tapi kategori yang hilang
/// akan membuat transaksi lama kehilangan pengelompokan.
const _defaultCategories = <({String name, String icon})>[
  (name: 'Makan', icon: 'restaurant'),
  (name: 'Transport', icon: 'directions_bus'),
  (name: 'Belanja', icon: 'shopping_bag'),
  (name: 'Tagihan', icon: 'receipt_long'),
  (name: 'Hiburan', icon: 'movie'),
  (name: 'Kesehatan', icon: 'medical_services'),
  (name: 'Lainnya', icon: 'more_horiz'),
];

class DatabaseSeeder {
  DatabaseSeeder(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Mengisi kategori bawaan, dompet tunai, dan baris orang "saya".
  Future<void> run() async {
    await _db.transaction(() async {
      await _seedCategories();
      await _seedCashWallet();
      await _seedSelf();
    });
  }

  Future<void> _seedCategories() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    for (var i = 0; i < _defaultCategories.length; i++) {
      final category = _defaultCategories[i];
      // Setiap kategori diberi `createdAt` yang maju satu milidetik supaya
      // urutan daftar di layar input mengikuti urutan di atas — yang paling
      // sering dipakai lebih dulu. Kalau semuanya berstempel waktu sama,
      // urutannya jadi acak sesuai kehendak SQLite.
      final stamp = now.add(Duration(milliseconds: i));
      await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              id: _uuid.v4(),
              name: category.name,
              icon: Value(category.icon),
              isSystem: const Value(true),
              createdAt: stamp,
              updatedAt: stamp,
            ),
          );
    }
  }

  Future<void> _seedCashWallet() async {
    final existing = await _db.select(_db.wallets).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    await _db.into(_db.wallets).insert(
          WalletsCompanion.insert(
            id: _uuid.v4(),
            name: 'Tunai',
            type: WalletType.cash,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Baris orang yang mewakili pemilik aplikasi.
  ///
  /// Wajib ada sebelum split bill dipakai: tanpa baris ini, repository
  /// tidak tahu porsi mana yang harus masuk ke budget sendiri.
  Future<void> _seedSelf() async {
    final existing = await (_db.select(_db.people)
          ..where((p) => p.isSelf.equals(true)))
        .get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    await _db.into(_db.people).insert(
          PeopleCompanion.insert(
            id: _uuid.v4(),
            name: 'Saya',
            isSelf: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
