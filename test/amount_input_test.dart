import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/amount_input.dart';

void main() {
  group('mengetik nominal', () {
    test('digit disusun dari kiri ke kanan', () {
      var input = const AmountInput();
      for (final digit in [2, 5, 0, 0, 0]) {
        input = input.append(digit);
      }

      expect(input.value, 25000);
    });

    test('nol di depan tidak menumpuk', () {
      final input = const AmountInput().append(0).append(0).append(7);
      expect(input.value, 7);
    });

    test('nilai awal kosong', () {
      expect(const AmountInput().value, 0);
      expect(const AmountInput().isEmpty, isTrue);
    });
  });

  group('tombol 000', () {
    test('menambah tiga nol sekaligus', () {
      final input = const AmountInput().append(2).append(5).appendTripleZero();
      expect(input.value, 25000);
    });

    test('tidak melakukan apa-apa saat masih kosong', () {
      // `000` di awal tetap nol. Membiarkannya berubah hanya membuat
      // pengguna mengira ketukannya tidak terbaca.
      expect(const AmountInput().appendTripleZero().value, 0);
    });
  });

  group('batas nominal', () {
    test('ketukan yang melewati batas diabaikan, bukan dipotong', () {
      // Rp 999.999.999 adalah batasnya. Menambah satu digit lagi akan
      // menghasilkan sepuluh digit.
      const atLimit = AmountInput(maxAmount);

      expect(atLimit.append(9).value, maxAmount);
      expect(atLimit.append(0).value, maxAmount);
    });

    test('000 yang melewati batas diabaikan', () {
      const large = AmountInput(5000000);
      expect(large.appendTripleZero().value, 5000000);
    });

    test('nominal tepat di batas masih diterima', () {
      const almost = AmountInput(99999999);
      expect(almost.append(9).value, maxAmount);
    });
  });

  group('menghapus', () {
    test('backspace membuang satu digit terakhir', () {
      expect(const AmountInput(25000).backspace().value, 2500);
    });

    test('backspace di nominal satu digit menghasilkan nol', () {
      expect(const AmountInput(7).backspace().value, 0);
    });

    test('backspace di nominal kosong tetap nol', () {
      expect(const AmountInput().backspace().value, 0);
    });

    test('clear mengosongkan seluruhnya', () {
      expect(const AmountInput(123456).clear().value, 0);
    });
  });

  test('nilai lama tidak ikut berubah', () {
    const original = AmountInput(25000);
    original.append(0);
    original.backspace();

    expect(original.value, 25000);
  });
}
