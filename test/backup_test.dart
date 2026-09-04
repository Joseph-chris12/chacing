/// Tes cadangan: yang keluar harus bisa masuk kembali persis sama.
///
/// Sampai sync dibangun, file JSON ini satu-satunya jalan keluar data.
/// Cadangan yang diam-diam kehilangan satu kolom baru ketahuan saat
/// seseorang benar-benar kehilangan HP-nya — terlambat.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/data/backup.dart';
import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/budget_repository.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/data/seed.dart';
import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/domain/split_calculator.dart';

void main() {
  late AppDatabase source;
  late BackupService service;

  setUp(() async {
    source = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder(source).run();
    service = BackupService(source);
  });

  tearDown(() async => source.close());

  Future<String> seedAndExport() async {
    final repository = TransactionRepository(source);
    final walletId = (await source.select(source.wallets).get()).first.id;
    final categories = await source.select(source.categories).get();

    await repository.save(
      TransactionDraft(
        walletId: walletId,
        categoryId: categories.first.id,
        merchant: 'Warung Kopi',
        occurredAt: DateTime(2026, 9, 3, 12),
        total: 25000,
      ),
    );

    await repository.save(
      TransactionDraft(
        walletId: walletId,
        categoryId: categories[1].id,
        merchant: 'Ojek',
        occurredAt: DateTime(2026, 9, 4, 8),
        total: 40000,
        items: const [
          LineItem(id: 'i1', name: 'Perjalanan', quantity: 1, unitPrice: 40000),
        ],
      ),
    );

    await BudgetRepository(source).save(
      period: PeriodKind.week,
      amount: 700000,
      rollover: true,
    );

    return service.exportJson();
  }

  group('bentuk file', () {
    test('menyertakan penanda format dan versi skema', () async {
      final decoded = jsonDecode(await seedAndExport()) as Map<String, dynamic>;

      expect(decoded['format'], 'chacing-backup');
      expect(decoded['version'], BackupService.formatVersion);
      expect(decoded['schemaVersion'], source.schemaVersion);
      expect(DateTime.tryParse(decoded['exportedAt'] as String), isNotNull);
    });

    test('nama file menyertakan tanggal', () {
      final name = service.suggestedFileName(now: DateTime(2026, 9, 4));
      expect(name, 'chacing-20260904.json');
    });

    test('ringkasan isi dibaca tanpa menyentuh database', () async {
      final contents = service.inspect(await seedAndExport());

      expect(contents.transactions, 2);
      expect(contents.categories, 7);
      expect(contents.wallets, 1);
      expect(contents.budgets, 1);
      expect(contents.lineItems, 1);
    });
  });

  group('pulang pergi', () {
    test('data yang dicadangkan kembali utuh di database kosong', () async {
      final json = await seedAndExport();

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await BackupService(target).restore(json);

      final transactions = await target.select(target.transactions).get();
      expect(transactions.length, 2);

      final kopi = transactions.firstWhere((t) => t.merchant == 'Warung Kopi');
      expect(kopi.total, 25000);
      expect(kopi.ownShare, 25000);
      expect(kopi.occurredAt, DateTime(2026, 9, 3, 12));

      expect((await target.select(target.categories).get()).length, 7);
      expect((await target.select(target.wallets).get()).single.name, 'Tunai');
      expect((await target.select(target.people).get()).single.isSelf, isTrue);
    });

    test('item struk ikut terbawa dan tetap menempel ke induknya', () async {
      final json = await seedAndExport();

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await BackupService(target).restore(json);

      final ojek = (await target.select(target.transactions).get())
          .firstWhere((t) => t.merchant == 'Ojek');
      final items = await TransactionRepository(target).itemsOf(ojek.id);

      expect(items.single.name, 'Perjalanan');
      expect(items.single.unitPrice, 40000);
    });

    test('pengaturan budget ikut terbawa', () async {
      final json = await seedAndExport();

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await BackupService(target).restore(json);

      final budget = await BudgetRepository(target).active();
      expect(budget, isNotNull);
      expect(budget!.amount, 700000);
      expect(budget.period, PeriodKind.week);
      expect(budget.rollover, isTrue);
    });

    test('memulihkan mengganti data lama, bukan menggabungkan', () async {
      final json = await seedAndExport();

      // Database tujuan sudah berisi transaksi lain yang tidak ada di file.
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await DatabaseSeeder(target).run();

      final walletId = (await target.select(target.wallets).get()).first.id;
      await TransactionRepository(target).save(
        TransactionDraft(
          walletId: walletId,
          merchant: 'Harus hilang',
          occurredAt: DateTime(2026, 9, 1),
          total: 99000,
        ),
      );

      await BackupService(target).restore(json);

      final merchants = (await target.select(target.transactions).get())
          .map((t) => t.merchant);
      expect(merchants, isNot(contains('Harus hilang')));
      expect(merchants.length, 2);
    });

    test('transaksi terhapus tetap terbawa sebagai tombstone', () async {
      final repository = TransactionRepository(source);
      final walletId = (await source.select(source.wallets).get()).first.id;
      final saved = await repository.save(
        TransactionDraft(
          walletId: walletId,
          merchant: 'Sudah dihapus',
          occurredAt: DateTime(2026, 9, 3),
          total: 10000,
        ),
      );
      await repository.softDelete(saved.transactionId);

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await BackupService(target).restore(await service.exportJson());

      // Tanpa tombstone, memulihkan cadangan lama akan menghidupkan
      // kembali transaksi yang sudah sengaja dihapus.
      final restored =
          await TransactionRepository(target).findById(saved.transactionId);
      expect(restored, isNotNull);
      expect(restored!.deletedAt, isNotNull);
    });
  });

  group('file yang tidak bisa dipakai ditolak', () {
    test('bukan JSON', () {
      expect(
        () => service.inspect('bukan json sama sekali'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('JSON yang bukan cadangan Chacing', () {
      expect(
        () => service.inspect('{"hello":"world"}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('cadangan dari versi format yang lebih baru', () {
      final future = jsonEncode({
        'format': 'chacing-backup',
        'version': BackupService.formatVersion + 1,
        'schemaVersion': 1,
      });

      expect(
        () => service.inspect(future),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('cadangan dari skema yang lebih baru', () {
      final future = jsonEncode({
        'format': 'chacing-backup',
        'version': BackupService.formatVersion,
        'schemaVersion': 99,
      });

      expect(
        () => service.inspect(future),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('file rusak tidak menyentuh data yang ada', () async {
      await seedAndExport();

      await expectLater(
        service.restore('{"format":"chacing-backup","version":1,'
            '"transactions":"bukan daftar"}'),
        throwsA(isA<BackupFormatException>()),
      );

      // Pemeriksaan terjadi sebelum satu baris pun dihapus.
      expect((await source.select(source.transactions).get()).length, 2);
    });
  });
}
