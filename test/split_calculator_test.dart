import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/split_calculator.dart';

void main() {
  const calc = SplitCalculator();

  test('total semua porsi persis sama dengan total struk', () {
    // Nasi 35.000 untuk Andi, ayam 40.000 untuk Budi,
    // es teh 25.000 dibagi bertiga. Pajak 11%.
    final items = [
      const LineItem(id: 'i1', name: 'Nasi', quantity: 1, unitPrice: 35000),
      const LineItem(id: 'i2', name: 'Ayam', quantity: 1, unitPrice: 40000),
      const LineItem(id: 'i3', name: 'Es teh', quantity: 1, unitPrice: 25000),
    ];

    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi'),
      const Assignment(lineItemId: 'i2', personId: 'budi'),
      const Assignment(lineItemId: 'i3', personId: 'andi'),
      const Assignment(lineItemId: 'i3', personId: 'budi'),
      const Assignment(lineItemId: 'i3', personId: 'citra'),
    ];

    final result = calc.calculate(
      items: items,
      assignments: assignments,
      tax: 11000,
      receiptTotal: 111000,
    );

    final sum = result.shares.fold<int>(0, (a, s) => a + s.total);
    expect(sum, 111000);
    expect(result.warnings, isEmpty);
    expect(result.unallocated, 0);
  });

  test('pajak dialokasikan proporsional, bukan dibagi rata', () {
    final items = [
      const LineItem(id: 'i1', name: 'Mahal', quantity: 1, unitPrice: 90000),
      const LineItem(id: 'i2', name: 'Murah', quantity: 1, unitPrice: 10000),
    ];
    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi'),
      const Assignment(lineItemId: 'i2', personId: 'budi'),
    ];

    final result = calc.calculate(
      items: items,
      assignments: assignments,
      tax: 10000,
    );

    // Andi menanggung 90% dari pajak, bukan setengahnya.
    expect(result.shareOf('andi')!.adjustment, 9000);
    expect(result.shareOf('budi')!.adjustment, 1000);
  });

  test('bobot dipakai untuk item yang dibagi tidak rata', () {
    final items = [
      const LineItem(id: 'i1', name: 'Sate', quantity: 10, unitPrice: 5000),
    ];
    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi', weight: 6),
      const Assignment(lineItemId: 'i1', personId: 'budi', weight: 4),
    ];

    final result = calc.calculate(items: items, assignments: assignments);

    expect(result.shareOf('andi')!.total, 30000);
    expect(result.shareOf('budi')!.total, 20000);
  });

  test('utang dihitung dari selisih bayar dan porsi', () {
    final items = [
      const LineItem(id: 'i1', name: 'Makan', quantity: 1, unitPrice: 90000),
    ];
    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi'),
      const Assignment(lineItemId: 'i1', personId: 'budi'),
      const Assignment(lineItemId: 'i1', personId: 'citra'),
    ];

    // Andi menalangi semuanya.
    final result = calc.calculate(
      items: items,
      assignments: assignments,
      payments: {'andi': 90000},
    );

    expect(result.settlements.length, 2);
    for (final s in result.settlements) {
      expect(s.toPersonId, 'andi');
      expect(s.amount, 30000);
    }
  });

  test('item tanpa penugasan menghasilkan peringatan, bukan diam-diam hilang',
      () {
    final items = [
      const LineItem(id: 'i1', name: 'Kopi', quantity: 1, unitPrice: 25000),
      const LineItem(id: 'i2', name: 'Roti', quantity: 1, unitPrice: 15000),
    ];
    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi'),
    ];

    final result = calc.calculate(items: items, assignments: assignments);

    expect(result.warnings, isNotEmpty);
    expect(result.warnings.first, contains('Roti'));
  });

  test('item tanpa penugasan tidak dibebankan ke orang lain', () {
    // Kopi 25.000 milik Andi, roti 15.000 tidak ditugaskan.
    // Andi harus tetap membayar 25.000 — bukan 40.000.
    final items = [
      const LineItem(id: 'i1', name: 'Kopi', quantity: 1, unitPrice: 25000),
      const LineItem(id: 'i2', name: 'Roti', quantity: 1, unitPrice: 15000),
    ];
    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi'),
    ];

    final result = calc.calculate(items: items, assignments: assignments);

    expect(result.shareOf('andi')!.total, 25000);
    expect(result.unallocated, 15000);
  });

  test('pajak ikut disisihkan untuk bagian yang belum ditugaskan', () {
    // Dua item 50.000 masing-masing, pajak 20.000, total 120.000.
    // Hanya satu item yang punya pemilik, jadi Andi menanggung
    // setengah struk: 50.000 + 10.000 pajak.
    final items = [
      const LineItem(id: 'i1', name: 'Punya Andi', quantity: 1, unitPrice: 50000),
      const LineItem(id: 'i2', name: 'Yatim', quantity: 1, unitPrice: 50000),
    ];
    final assignments = [
      const Assignment(lineItemId: 'i1', personId: 'andi'),
    ];

    final result = calc.calculate(
      items: items,
      assignments: assignments,
      tax: 20000,
    );

    expect(result.shareOf('andi')!.total, 60000);
    expect(result.shareOf('andi')!.itemSubtotal, 50000);
    expect(result.shareOf('andi')!.adjustment, 10000);
    expect(result.unallocated, 60000);
  });

  test('semua item tanpa penugasan menghasilkan hasil kosong', () {
    final items = [
      const LineItem(id: 'i1', name: 'Kopi', quantity: 1, unitPrice: 25000),
    ];

    final result = calc.calculate(items: items, assignments: const []);

    expect(result.shares, isEmpty);
    expect(result.unallocated, 25000);
    expect(result.warnings, isNotEmpty);
  });
}
