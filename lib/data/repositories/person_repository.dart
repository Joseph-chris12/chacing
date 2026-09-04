/// Akses ke daftar orang yang ikut bagi tagihan.
///
/// Orang di sini tidak perlu punya akun — cukup nama. Sebagian besar
/// patungan terjadi dengan teman yang tidak akan pernah memasang
/// aplikasinya, dan memaksa mereka mendaftar akan membunuh fiturnya.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';

class PersonRepository {
  PersonRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Semua orang, diri sendiri lebih dulu lalu urut waktu dibuat.
  ///
  /// Diri sendiri ditaruh paling depan karena hampir setiap tagihan
  /// melibatkan dirinya — menaruhnya di tengah daftar berarti satu
  /// guliran tambahan setiap kali.
  Stream<List<Person>> watchAll() {
    return (_db.select(_db.people)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([
            (p) => OrderingTerm.desc(p.isSelf),
            (p) => OrderingTerm.asc(p.createdAt),
          ]))
        .watch();
  }

  Future<List<Person>> all() {
    return (_db.select(_db.people)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([
            (p) => OrderingTerm.desc(p.isSelf),
            (p) => OrderingTerm.asc(p.createdAt),
          ]))
        .get();
  }

  Future<Person?> self() {
    return (_db.select(_db.people)
          ..where((p) => p.isSelf.equals(true) & p.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Person?> findById(String id) {
    return (_db.select(_db.people)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> create(String name) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db.into(_db.people).insert(
          PeopleCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return id;
  }

  Future<void> rename(String id, String name) async {
    final now = DateTime.now();
    await (_db.update(_db.people)..where((p) => p.id.equals(id))).write(
      PeopleCompanion(
        name: Value(name),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Menghapus orang. Diri sendiri tidak boleh dihapus.
  ///
  /// Tanpa baris diri sendiri, repository transaksi tidak tahu porsi mana
  /// yang masuk ke budget dan seluruh total akan dianggap pengeluaran
  /// sendiri — persis kesalahan yang paling merusak di aplikasi ini.
  Future<bool> softDelete(String id) async {
    final person = await findById(id);
    if (person == null || person.isSelf) return false;

    final now = DateTime.now();
    await (_db.update(_db.people)..where((p) => p.id.equals(id))).write(
      PeopleCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
    return true;
  }
}
