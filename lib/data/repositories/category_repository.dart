/// Akses ke kategori. UI tidak pernah menyentuh Drift langsung.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';

class CategoryRepository {
  CategoryRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Kategori aktif, urut sesuai urutan pembuatan.
  ///
  /// Urutan ini disengaja: kategori bawaan disemai mulai dari yang paling
  /// sering dipakai (Makan), sehingga jarinya paling dekat. Mengurutkan
  /// menurut abjad akan melempar "Makan" ke tengah daftar.
  Stream<List<Category>> watchAll() {
    return (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .watch();
  }

  Future<List<Category>> all() {
    return (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();
  }

  Future<Category?> findById(String id) {
    return (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> create({
    required String name,
    String? icon,
    int? colorValue,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            icon: Value(icon),
            colorValue: Value(colorValue),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return id;
  }

  /// Mengubah nama dan/atau ikon.
  ///
  /// Kategori bawaan ikut boleh diubah — yang dilarang hanya menghapusnya.
  /// Nama "Makan" mungkin tidak cocok untuk semua orang, dan memaksa
  /// mereka membuat kategori kembar hanya menambah kekacauan.
  Future<void> update(
    String id, {
    String? name,
    String? icon,
    int? colorValue,
  }) async {
    if (name == null && icon == null && colorValue == null) return;

    final now = DateTime.now();
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        icon: icon == null ? const Value.absent() : Value(icon),
        colorValue:
            colorValue == null ? const Value.absent() : Value(colorValue),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> rename(String id, String name) => update(id, name: name);

  /// Kategori bawaan tidak boleh dihapus — transaksi lama akan kehilangan
  /// pengelompokannya.
  Future<bool> softDelete(String id) async {
    final category = await findById(id);
    if (category == null || category.isSystem) return false;

    final now = DateTime.now();
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
    return true;
  }
}
