/// Tes pengurai jawaban OCR.
///
/// Ini lapisan paling rawan di seluruh fitur scan: yang datang adalah
/// jawaban model bahasa, dan bentuknya tidak dijamin. Setiap kemungkinan
/// yang tidak ditangani di sini berakhir sebagai nominal salah yang
/// diam-diam masuk ke catatan keuangan.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/receipt_draft.dart';

const parser = ReceiptParser();

void main() {
  group('membaca jawaban yang rapi', () {
    test('struk lengkap terbaca utuh', () {
      final draft = parser.parse('''
      {
        "merchant": "Warung Kopi",
        "date": "2026-09-03",
        "items": [
          {"name": "Kopi susu", "quantity": 2, "unit_price": 18000},
          {"name": "Roti bakar", "quantity": 1, "unit_price": 15000}
        ],
        "tax": 5100,
        "total": 56100
      }
      ''');

      expect(draft.merchant, 'Warung Kopi');
      expect(draft.occurredAt, DateTime(2026, 9, 3));
      expect(draft.items.length, 2);
      expect(draft.items.first.total, 36000);
      expect(draft.total, 56100);
      expect(draft.isConsistent, isTrue);
      expect(draft.warnings, isEmpty);
    });
  });

  group('bertahan dari jawaban yang berantakan', () {
    test('pagar kode ```json dibuang', () {
      final draft = parser.parse('''
      ```json
      {"merchant": "Warteg", "items": [], "total": 25000}
      ```
      ''');

      expect(draft.merchant, 'Warteg');
      expect(draft.total, 25000);
    });

    test('kalimat pengantar sebelum JSON diabaikan', () {
      final draft = parser.parse(
        'Berikut hasil pembacaannya: {"merchant":"Ayam Geprek","total":28000}',
      );

      expect(draft.merchant, 'Ayam Geprek');
      expect(draft.total, 28000);
    });

    test('nominal berbentuk teks berformat rupiah tetap terbaca', () {
      final draft = parser.parse('''
      {
        "items": [{"name": "Nasi", "quantity": "1", "unit_price": "Rp 25.000"}],
        "total": "Rp 25.000"
      }
      ''');

      expect(draft.items.single.unitPrice, 25000);
      expect(draft.total, 25000);
    });

    test('nominal pecahan dibulatkan ke rupiah bulat', () {
      final draft = parser.parse(
        '{"items":[{"name":"Teh","quantity":1,"unit_price":8500.4}],'
        '"total":8500}',
      );

      expect(draft.items.single.unitPrice, 8500);
    });

    test('kuantitas nol dianggap satu, bukan dibuang', () {
      // Membuang barisnya justru membuat totalnya meleset tanpa jejak.
      final draft = parser.parse(
        '{"items":[{"name":"Es teh","quantity":0,"unit_price":6000}],'
        '"total":6000}',
      );

      expect(draft.items.single.quantity, 1);
    });

    test('baris tanpa nama atau tanpa harga dilewati', () {
      final draft = parser.parse('''
      {
        "items": [
          {"name": "", "unit_price": 10000},
          {"name": "Sah", "quantity": 1, "unit_price": 10000},
          {"name": "Tanpa harga", "quantity": 1, "unit_price": 0}
        ],
        "total": 10000
      }
      ''');

      expect(draft.items.map((i) => i.name), ['Sah']);
    });

    test('bukan JSON sama sekali menghasilkan pesan untuk pengguna', () {
      expect(
        () => parser.parse('maaf saya tidak bisa membaca struk ini'),
        throwsA(isA<ReceiptParseException>()),
      );
    });
  });

  group('menjaga pengguna dari angka yang salah', () {
    test('selisih jumlah item dan total diberi peringatan', () {
      final draft = parser.parse('''
      {
        "items": [{"name": "Kopi", "quantity": 1, "unit_price": 20000}],
        "total": 35000
      }
      ''');

      expect(draft.isConsistent, isFalse);
      expect(draft.discrepancy, 15000);
      expect(draft.warnings.first, contains('tidak cocok'));
    });

    test('total yang tidak terbaca dihitung dari item, dengan peringatan', () {
      final draft = parser.parse('''
      {
        "items": [
          {"name": "Kopi", "quantity": 2, "unit_price": 18000}
        ],
        "tax": 3600
      }
      ''');

      expect(draft.total, 39600);
      expect(draft.warnings.any((w) => w.contains('Total tidak terbaca')),
          isTrue);
    });

    test('struk tanpa satu pun item diberi peringatan', () {
      final draft = parser.parse('{"merchant":"Warung","total":25000}');
      expect(draft.warnings.first, contains('Tidak ada baris item'));
    });

    test('baris dengan keyakinan rendah ditandai untuk diperiksa', () {
      final draft = parser.parse('''
      {
        "items": [
          {"name": "Jelas", "quantity": 1, "unit_price": 10000,
           "confidence": 95},
          {"name": "Buram", "quantity": 1, "unit_price": 15000,
           "confidence": 40}
        ],
        "total": 25000
      }
      ''');

      expect(draft.hasDoubtfulItems, isTrue);
      expect(draft.items.first.isDoubtful, isFalse);
      expect(draft.items.last.isDoubtful, isTrue);
    });
  });
}
