import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/daily_group.dart';

/// Transaksi tiruan secukupnya untuk menguji pengelompokan.
class _Entry {
  const _Entry(this.at, this.ownShare, this.total);

  final DateTime at;
  final int ownShare;
  final int total;
}

List<DailyGroup<_Entry>> _group(List<_Entry> entries) => groupByDay<_Entry>(
      entries,
      dateOf: (e) => e.at,
      amountOf: (e) => e.ownShare,
    );

void main() {
  test('transaksi di hari yang sama masuk satu kelompok', () {
    final groups = _group([
      _Entry(DateTime(2026, 9, 3, 8), 15000, 15000),
      _Entry(DateTime(2026, 9, 3, 21, 45), 25000, 25000),
    ]);

    expect(groups.length, 1);
    expect(groups.single.count, 2);
    expect(groups.single.date, DateTime(2026, 9, 3));
  });

  test('subtotal harian menjumlahkan porsi sendiri', () {
    final groups = _group([
      _Entry(DateTime(2026, 9, 3, 8), 15000, 15000),
      _Entry(DateTime(2026, 9, 3, 12), 25000, 25000),
    ]);

    expect(groups.single.subtotal, 40000);
  });

  test('subtotal memakai porsi sendiri, bukan total struk', () {
    // Menalangi makan bertiga: Rp 90.000 keluar dari dompet,
    // tapi yang jadi pengeluaran sendiri hanya Rp 30.000.
    final groups = _group([
      _Entry(DateTime(2026, 9, 3, 19), 30000, 90000),
    ]);

    expect(groups.single.subtotal, 30000);
  });

  test('hari terbaru muncul lebih dulu', () {
    final groups = _group([
      _Entry(DateTime(2026, 9, 1, 10), 10000, 10000),
      _Entry(DateTime(2026, 9, 5, 10), 20000, 20000),
      _Entry(DateTime(2026, 9, 3, 10), 30000, 30000),
    ]);

    expect(
      groups.map((g) => g.date),
      [DateTime(2026, 9, 5), DateTime(2026, 9, 3), DateTime(2026, 9, 1)],
    );
  });

  test('jam tidak ikut menentukan kelompok', () {
    // Tengah malam dan sedetik sebelum tengah malam berikutnya tetap
    // satu hari yang sama.
    final groups = _group([
      _Entry(DateTime(2026, 9, 3, 0, 0, 0), 1000, 1000),
      _Entry(DateTime(2026, 9, 3, 23, 59, 59), 2000, 2000),
    ]);

    expect(groups.length, 1);
    expect(groups.single.subtotal, 3000);
  });

  test('urutan dalam satu hari mengikuti urutan masukan', () {
    final groups = _group([
      _Entry(DateTime(2026, 9, 3, 20), 20000, 20000),
      _Entry(DateTime(2026, 9, 3, 7), 7000, 7000),
    ]);

    expect(groups.single.entries.map((e) => e.ownShare), [20000, 7000]);
  });

  test('daftar kosong menghasilkan nol kelompok', () {
    expect(_group(const []), isEmpty);
  });
}
