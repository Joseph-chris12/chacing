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
/// pengguna boleh mengganti nama, ikon, dan warnanya, tapi kategori yang
/// hilang akan membuat transaksi lama kehilangan pengelompokan.
///
/// Warnanya ditulis sebagai ARGB mentah, bukan diambil dari palet di
/// `ui/category_colors.dart`. Lapisan data tidak boleh bergantung pada
/// lapisan tampilan; nilainya memang sengaja disamakan dengan palet itu.
/// Urutannya dijarakkan supaya dua kategori bersebelahan tidak berwarna
/// mirip — itu yang paling sering membuat grafik sulit dibaca.
const _defaultCategories = <({String name, String icon, int color})>[
  (name: 'Makan', icon: 'restaurant', color: 0xFFEA580C),
  (name: 'Transport', icon: 'directions_bus', color: 0xFF0284C7),
  (name: 'Belanja', icon: 'shopping_bag', color: 0xFF9333EA),
  (name: 'Tagihan', icon: 'receipt_long', color: 0xFF0D9488),
  (name: 'Hiburan', icon: 'movie', color: 0xFFDB2777),
  (name: 'Kesehatan', icon: 'medical_services', color: 0xFF16A34A),
  (name: 'Lainnya', icon: 'more_horiz', color: 0xFF78716C),
];

class DatabaseSeeder {
  DatabaseSeeder(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Mengisi kategori bawaan, dompet tunai, dan baris orang "saya".
  Future<void> run() async {
    await _db.transaction(() async {
      await _seedCategories();
      await _backfillCategoryColors();
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
              colorValue: Value(category.color),
              isSystem: const Value(true),
              createdAt: stamp,
              updatedAt: stamp,
            ),
          );
    }
  }

  /// Mengisi warna kategori bawaan yang sudah terlanjur dibuat tanpa warna.
  ///
  /// Kolom `colorValue` sudah ada di tabel sejak awal tapi baru dipakai
  /// belakangan, jadi pemasangan yang lebih tua punya kategori bawaan
  /// dengan warna kosong. Tanpa langkah ini, warna yang sudah dipilihkan
  /// hanya terlihat oleh orang yang memasang aplikasi dari nol.
  ///
  /// Hanya menyentuh baris yang warnanya masih kosong, jadi pilihan
  /// pengguna tidak pernah tertimpa.
  Future<void> _backfillCategoryColors() async {
    final rows = await (_db.select(_db.categories)
          ..where((c) => c.colorValue.isNull()))
        .get();
    if (rows.isEmpty) return;

    final byName = {
      for (final category in _defaultCategories) category.name: category.color,
    };

    for (final row in rows) {
      final color = byName[row.name];
      if (color == null) continue;

      await (_db.update(_db.categories)..where((c) => c.id.equals(row.id)))
          .write(CategoriesCompanion(colorValue: Value(color)));
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
