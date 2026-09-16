/// Akses ke tagihan tetap bulanan beserta pembayarannya.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/domain/bill_schedule.dart';

/// Tagihan beserta status pembayaran yang sudah diperiksa ke transaksinya.
class FixedBillView {
  const FixedBillView({required this.bill, required this.paidForMonth});

  final FixedBill bill;

  /// Bulan terakhir yang benar-benar dibayar.
  ///
  /// Bisa berbeda dari `bill.paidForMonth`: kalau transaksi pembayarannya
  /// sudah dihapus, nilai ini null dan tagihannya kembali muncul sebagai
  /// belum dibayar.
  final DateTime? paidForMonth;

  /// Jadwal dihitung saat dipanggil, bukan saat data dibaca. Status
  /// "jatuh tempo hari ini" harus ikut berganti begitu tanggalnya berganti,
  /// walaupun tidak ada data yang berubah.
  BillSchedule schedule({DateTime? now}) => BillSchedule(
    dueDay: bill.dueDay,
    paidForMonth: paidForMonth,
    now: now ?? DateTime.now(),
  );
}

class FixedBillRepository {
  FixedBillRepository(this._db, this._transactions, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final TransactionRepository _transactions;
  final Uuid _uuid;

  /// Semua tagihan aktif, urut tanggal jatuh tempo.
  ///
  /// Pembayaran terakhir diperiksa dalam query yang sama: tagihan hanya
  /// dianggap lunas kalau transaksinya masih ada dan belum dihapus.
  Stream<List<FixedBillView>> watchActive() {
    return _db
        .customSelect(
          '''
      SELECT b.*, t.id AS paid_transaction_id
      FROM fixed_bills b
      LEFT JOIN transactions t
        ON t.id = b.last_transaction_id AND t.deleted_at IS NULL
      WHERE b.deleted_at IS NULL AND b.is_active = 1
      ORDER BY b.due_day ASC, b.name ASC
      ''',
          readsFrom: {_db.fixedBills, _db.transactions},
        )
        .watch()
        .map((rows) => [for (final row in rows) _toView(row)]);
  }

  Future<List<FixedBillView>> active() => watchActive().first;

  FixedBillView _toView(QueryRow row) {
    final bill = _db.fixedBills.map(row.data);
    final paymentStillExists = row.read<String?>('paid_transaction_id') != null;

    return FixedBillView(
      bill: bill,
      paidForMonth: paymentStillExists ? bill.paidForMonth : null,
    );
  }

  Future<FixedBill?> findById(String id) {
    return (_db.select(
      _db.fixedBills,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Membuat tagihan baru, atau memperbarui kalau [id] diberikan.
  Future<String> save({
    String? id,
    required String name,
    required int amount,
    required int dueDay,
    String? walletId,
    String? categoryId,
    bool countInBudget = false,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari nol');
    }
    if (dueDay < 1 || dueDay > 31) {
      throw ArgumentError.value(dueDay, 'dueDay', 'harus 1 sampai 31');
    }

    final now = DateTime.now();

    if (id != null) {
      await (_db.update(_db.fixedBills)..where((b) => b.id.equals(id))).write(
        FixedBillsCompanion(
          name: Value(name.trim()),
          amount: Value(amount),
          dueDay: Value(dueDay),
          walletId: Value(walletId),
          categoryId: Value(categoryId),
          countInBudget: Value(countInBudget),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
      return id;
    }

    final newId = _uuid.v4();
    await _db
        .into(_db.fixedBills)
        .insert(
          FixedBillsCompanion.insert(
            id: newId,
            name: name.trim(),
            amount: amount,
            dueDay: dueDay,
            walletId: Value(walletId),
            categoryId: Value(categoryId),
            countInBudget: Value(countInBudget),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return newId;
  }

  /// Menghapus tagihan dari daftar. Pembayaran yang sudah tercatat tetap
  /// ada di riwayat transaksi — uangnya memang sudah keluar.
  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.fixedBills)..where((b) => b.id.equals(id))).write(
      FixedBillsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Mencatat pembayaran tagihan untuk bulan berjalan.
  ///
  /// Transaksinya ditulis lewat [TransactionRepository.save] seperti
  /// pengeluaran lain, supaya `ownShare` tetap dihitung di satu tempat.
  /// Pencatatan transaksi dan penandaan lunas berada dalam satu transaksi
  /// database: tidak boleh ada pembayaran yang tercatat tapi tagihannya
  /// masih muncul sebagai belum dibayar, atau sebaliknya.
  ///
  /// [amount] dan [walletId] boleh berbeda dari isian tagihan, karena
  /// tagihan listrik bulan ini jarang sama dengan bulan lalu.
  Future<String> recordPayment({
    required String billId,
    required int amount,
    required String walletId,
    DateTime? paidAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari nol');
    }

    final at = paidAt ?? DateTime.now();

    return _db.transaction(() async {
      final bill = await findById(billId);
      if (bill == null) {
        throw StateError('Tagihan $billId tidak ditemukan');
      }

      final result = await _transactions.save(
        TransactionDraft(
          walletId: walletId,
          categoryId: bill.categoryId,
          merchant: bill.name,
          occurredAt: at,
          total: amount,
          source: TransactionSource.recurring,
          excludeFromBudget: !bill.countInBudget,
        ),
      );

      await (_db.update(
        _db.fixedBills,
      )..where((b) => b.id.equals(billId))).write(
        FixedBillsCompanion(
          paidForMonth: Value(DateTime(at.year, at.month, 1)),
          lastTransactionId: Value(result.transactionId),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );

      return result.transactionId;
    });
  }
}
