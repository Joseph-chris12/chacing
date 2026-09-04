/// Akses ke pengaturan budget.
///
/// Untuk MVP hanya ada satu budget aktif yang berlaku untuk semua
/// kategori. Kolom `categoryId` di tabel sudah menyiapkan budget per
/// kategori, tapi jangan dipakai dulu — satu angka yang dipahami jauh
/// lebih berguna daripada tujuh angka yang tidak pernah ditengok.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/domain/budget_period.dart';

class BudgetRepository {
  BudgetRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  SimpleSelectStatement<$BudgetsTable, Budget> _activeQuery() {
    return _db.select(_db.budgets)
      ..where((b) =>
          b.deletedAt.isNull() &
          b.isActive.equals(true) &
          b.categoryId.isNull())
      ..orderBy([(b) => OrderingTerm.desc(b.updatedAt)])
      ..limit(1);
  }

  /// Budget yang sedang berlaku, atau null kalau pengguna belum
  /// menetapkan apa pun.
  Stream<Budget?> watchActive() =>
      _activeQuery().watch().map((rows) => rows.isEmpty ? null : rows.first);

  Future<Budget?> active() async {
    final rows = await _activeQuery().get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Menyimpan pilihan pengguna.
  ///
  /// Baris yang sama diperbarui, bukan ditambah baris baru tiap kali
  /// pengaturan diubah. Menumpuk baris akan membuat riwayat budget yang
  /// tidak pernah dibaca, dan `watchActive` harus menebak mana yang benar.
  Future<String> save({
    required PeriodKind period,
    required int amount,
    int weekStartsOn = DateTime.monday,
    bool rollover = false,
  }) async {
    final now = DateTime.now();
    final existing = await active();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(
        BudgetsCompanion(
          period: Value(period),
          amount: Value(amount),
          weekStartsOn: Value(weekStartsOn),
          rollover: Value(rollover),
          isActive: const Value(true),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
      return existing.id;
    }

    final id = _uuid.v4();
    await _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            id: id,
            period: period,
            amount: amount,
            weekStartsOn: Value(weekStartsOn),
            rollover: Value(rollover),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Mematikan budget tanpa menghapus riwayatnya.
  Future<void> disable() async {
    final existing = await active();
    if (existing == null) return;

    final now = DateTime.now();
    await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
        .write(
      BudgetsCompanion(
        isActive: const Value(false),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }
}
