/// Akses ke dompet: tunai, e-wallet, rekening bank.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';

class WalletRepository {
  WalletRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Dompet yang masih aktif, urut sesuai urutan pembuatan.
  Stream<List<Wallet>> watchAll() {
    return (_db.select(_db.wallets)
          ..where((w) => w.deletedAt.isNull() & w.isArchived.equals(false))
          ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
        .watch();
  }

  Future<List<Wallet>> all() {
    return (_db.select(_db.wallets)
          ..where((w) => w.deletedAt.isNull() & w.isArchived.equals(false))
          ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
        .get();
  }

  Future<Wallet?> findById(String id) {
    return (_db.select(_db.wallets)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> create({
    required String name,
    required WalletType type,
    int initialBalance = 0,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db.into(_db.wallets).insert(
          WalletsCompanion.insert(
            id: id,
            name: name,
            type: type,
            initialBalance: Value(initialBalance),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return id;
  }

  /// Dompet diarsipkan, bukan dihapus. Transaksi lama tetap menunjuk
  /// ke sini dan harus tetap bisa menampilkan namanya.
  Future<void> archive(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }
}
