/// Tes alur bagi tagihan dari layar sampai database dan kembali lagi.
///
/// `SplitCalculator` sudah punya tesnya sendiri. Yang diuji di sini adalah
/// sambungannya: apa yang disusun layar benar-benar tersimpan, porsi
/// sendiri yang masuk budget benar, dan menyunting ulang tidak
/// menghilangkan penugasan siapa makan apa.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/person_repository.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/seed.dart';
import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/domain/split_calculator.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late PersonRepository people;
  late String walletId;
  late String selfId;
  late String budiId;
  late String citraId;

  const calculator = BudgetPeriodCalculator();
  final week = calculator.weekContaining(DateTime(2026, 9, 3));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(db).run();
    repository = TransactionRepository(db);
    people = PersonRepository(db);

    walletId = (await db.select(db.wallets).get()).first.id;
    selfId = (await people.self())!.id;
    budiId = await people.create('Budi');
    citraId = await people.create('Citra');
  });

  tearDown(() async => db.close());

  /// Tagihan seperti yang disusun layar bagi tagihan.
  ///
  /// Nasi 35.000 untuk aku, ayam 40.000 untuk Budi, es teh 25.000
  /// dibagi bertiga. Pajak 11.000, total 111.000, aku yang menalangi.
  Future<SaveResult> saveSharedBill() {
    return repository.save(
      TransactionDraft(
        walletId: walletId,
        merchant: 'Warung Bareng',
        occurredAt: DateTime(2026, 9, 3, 19),
        total: 111000,
        tax: 11000,
        items: const [
          LineItem(id: 'i1', name: 'Nasi', quantity: 1, unitPrice: 35000),
          LineItem(id: 'i2', name: 'Ayam', quantity: 1, unitPrice: 40000),
          LineItem(id: 'i3', name: 'Es teh', quantity: 1, unitPrice: 25000),
        ],
        assignments: [
          Assignment(lineItemId: 'i1', personId: selfId),
          Assignment(lineItemId: 'i2', personId: budiId),
          Assignment(lineItemId: 'i3', personId: selfId),
          Assignment(lineItemId: 'i3', personId: budiId),
          Assignment(lineItemId: 'i3', personId: citraId),
        ],
        payments: {selfId: 111000},
      ),
    );
  }

  group('menyimpan tagihan bersama', () {
    test('porsi sendiri jauh lebih kecil dari total struk', () async {
      final saved = await saveSharedBill();

      // Nasi 35.000 + sepertiga es teh 8.333 = 43.333, lalu ditambah
      // bagian pajaknya secara proporsional.
      expect(saved.ownShare, lessThan(111000));
      expect(saved.ownShare, greaterThan(40000));

      final row = (await repository.findById(saved.transactionId))!;
      expect(row.total, 111000);
      expect(row.ownShare, saved.ownShare);
    });

    test('budget memakai porsi sendiri, bukan uang yang ditalangi', () async {
      final saved = await saveSharedBill();

      // Inilah kesalahan paling merusak yang dijaga aturan proyek:
      // menalangi 111.000 tidak boleh memakan 111.000 dari budget.
      expect(await repository.spentIn(week), saved.ownShare);
      expect(await repository.spentIn(week), isNot(111000));
    });

    test('item dan penugasan ikut tersimpan', () async {
      final saved = await saveSharedBill();

      final items = await repository.itemsOf(saved.transactionId);
      expect(items.map((i) => i.name), ['Nasi', 'Ayam', 'Es teh']);

      final assignments =
          await repository.assignmentsOf(saved.transactionId);
      expect(assignments.length, 5);

      final teaEaters = assignments
          .where((a) => a.lineItemId == 'i3')
          .map((a) => a.personId)
          .toSet();
      expect(teaEaters, {selfId, budiId, citraId});
    });

    test('siapa yang menalangi ikut tersimpan', () async {
      final saved = await saveSharedBill();

      final payments = await repository.paymentsOf(saved.transactionId);
      expect(payments, {selfId: 111000});
    });

    test('saldo dompet berkurang penuh, bukan hanya sebesar porsi', () async {
      await saveSharedBill();

      // Uang yang keluar dari dompet di kasir memang 111.000 —
      // ini satu-satunya tempat yang benar memakai total.
      final balances = await repository.watchWalletBalances().first;
      expect(balances[walletId], -111000);
    });
  });

  group('menyunting tagihan bersama', () {
    test('draft yang dibaca kembali lengkap dengan anak-anaknya', () async {
      final saved = await saveSharedBill();

      final draft = await repository.draftOf(saved.transactionId);

      expect(draft, isNotNull);
      expect(draft!.items.length, 3);
      expect(draft.assignments.length, 5);
      expect(draft.payments, {selfId: 111000});
      expect(draft.tax, 11000);
      expect(draft.hasSplit, isTrue);
    });

    test('menyimpan ulang draft utuh tidak mengubah porsi sendiri', () async {
      final saved = await saveSharedBill();
      final before = saved.ownShare;

      final draft = await repository.draftOf(saved.transactionId);
      final again = await repository.save(draft!);

      expect(again.ownShare, before);
      expect((await repository.itemsOf(saved.transactionId)).length, 3);
      expect((await repository.assignmentsOf(saved.transactionId)).length, 5);
    });
  });

  group('daftar orang', () {
    test('diri sendiri selalu di urutan pertama', () async {
      final rows = await people.all();
      expect(rows.first.isSelf, isTrue);
      expect(rows.map((p) => p.name), ['Saya', 'Budi', 'Citra']);
    });

    test('diri sendiri tidak bisa dihapus', () async {
      expect(await people.softDelete(selfId), isFalse);
      expect(await people.self(), isNotNull);
    });

    test('orang lain bisa dihapus dan hilang dari daftar', () async {
      expect(await people.softDelete(budiId), isTrue);
      expect((await people.all()).map((p) => p.name), ['Saya', 'Citra']);
    });
  });
}
