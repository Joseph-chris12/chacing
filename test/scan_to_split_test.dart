/// Tes jalur dari struk hasil pindai ke pembagian tagihan.
///
/// Bagian yang mudah salah di sini adalah kuantitas. Struk menulis
/// "2 Kopi @ 18.000" dan yang harus masuk ke pembagian adalah 36.000,
/// bukan 18.000. Salah di sini membuat tagihan teman terlalu murah dan
/// selisihnya baru ketahuan saat menghitung uang di kasir.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/receipt_draft.dart';
import 'package:chacing/domain/split_calculator.dart';

const parser = ReceiptParser();
const calculator = SplitCalculator();

/// Mengubah hasil pindai jadi masukan mesin split, persis seperti yang
/// dilakukan layar bagi tagihan.
List<LineItem> asLineItems(ReceiptDraft draft) => [
      for (var i = 0; i < draft.items.length; i++)
        LineItem(
          id: 'i$i',
          name: draft.items[i].name,
          quantity: 1,
          // `total`, bukan `unitPrice`: kuantitas sudah dilipat ke sini.
          unitPrice: draft.items[i].total,
        ),
    ];

void main() {
  test('kuantitas lebih dari satu ikut terbawa ke pembagian', () {
    final draft = parser.parse('''
    {
      "items": [
        {"name": "Kopi", "quantity": 2, "unit_price": 18000},
        {"name": "Roti", "quantity": 1, "unit_price": 15000}
      ],
      "total": 51000
    }
    ''');

    final items = asLineItems(draft);

    expect(items.first.total, 36000);
    expect(items.map((i) => i.total).reduce((a, b) => a + b), 51000);
  });

  test('porsi tiap orang menjumlah persis total struk hasil pindai', () {
    final draft = parser.parse('''
    {
      "merchant": "Warung Bareng",
      "items": [
        {"name": "Nasi goreng", "quantity": 1, "unit_price": 35000},
        {"name": "Ayam bakar", "quantity": 1, "unit_price": 40000},
        {"name": "Es teh", "quantity": 3, "unit_price": 8000}
      ],
      "tax": 10900,
      "total": 109900
    }
    ''');

    final items = asLineItems(draft);
    final result = calculator.calculate(
      items: items,
      assignments: const [
        Assignment(lineItemId: 'i0', personId: 'aku'),
        Assignment(lineItemId: 'i1', personId: 'budi'),
        Assignment(lineItemId: 'i2', personId: 'aku'),
        Assignment(lineItemId: 'i2', personId: 'budi'),
        Assignment(lineItemId: 'i2', personId: 'citra'),
      ],
      tax: draft.tax,
      receiptTotal: draft.total,
    );

    final sum = result.shares.fold<int>(0, (a, s) => a + s.total);
    expect(sum, 109900);
    expect(result.unallocated, 0);
  });

  test('struk yang totalnya tidak cocok tetap membawa peringatannya', () {
    // Pembacaan yang meleset tidak boleh diam-diam jadi tagihan.
    final draft = parser.parse('''
    {
      "items": [{"name": "Kopi", "quantity": 1, "unit_price": 20000}],
      "total": 35000
    }
    ''');

    expect(draft.isConsistent, isFalse);
    expect(draft.warnings, isNotEmpty);
  });

  test('item yang belum ditandai tidak dibebankan ke yang sudah', () {
    final draft = parser.parse('''
    {
      "items": [
        {"name": "Punya aku", "quantity": 1, "unit_price": 25000},
        {"name": "Belum ditandai", "quantity": 1, "unit_price": 25000}
      ],
      "total": 50000
    }
    ''');

    final result = calculator.calculate(
      items: asLineItems(draft),
      assignments: const [Assignment(lineItemId: 'i0', personId: 'aku')],
      receiptTotal: draft.total,
    );

    expect(result.shareOf('aku')!.total, 25000);
    expect(result.unallocated, 25000);
  });
}
