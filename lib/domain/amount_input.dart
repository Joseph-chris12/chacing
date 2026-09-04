/// Nominal yang sedang diketik di papan angka.
///
/// Dipisah dari widget-nya supaya bisa diuji tanpa Flutter. Ini menyentuh
/// rupiah, dan setiap hitungan yang menyentuh rupiah wajib punya tes —
/// termasuk yang kelihatannya sesederhana "tambah satu digit".
library;

/// Batas atas nominal: Rp 999.999.999.
///
/// Bukan batas teknis `int`, tapi batas akal sehat. Tanpa batas, satu
/// ketukan nyasar yang tertahan bisa menghasilkan angka yang merusak
/// tampilan dan membuat ringkasan mingguan tidak masuk akal.
const int maxAmount = 999999999;

/// Nilai rupiah yang sedang disusun, selalu bilangan bulat.
///
/// Kelas ini kekal: setiap operasi mengembalikan nilai baru, tidak pernah
/// mengubah yang lama. Dengan begitu tidak ada jalan untuk diam-diam
/// mengubah nominal dari tempat lain.
class AmountInput {
  const AmountInput([this.value = 0]) : assert(value >= 0);

  final int value;

  bool get isEmpty => value == 0;

  /// Menambah satu digit di belakang.
  ///
  /// Ketukan yang akan melewati [maxAmount] diabaikan, bukan dipotong.
  /// Memotong akan menghasilkan angka yang tidak pernah diketik siapa pun.
  AmountInput append(int digit) {
    assert(digit >= 0 && digit <= 9);
    final next = value * 10 + digit;
    if (next > maxAmount) return this;
    return AmountInput(next);
  }

  /// Tombol `000`, karena hampir semua nominal rupiah berakhiran tiga nol.
  ///
  /// Tidak melakukan apa-apa saat nominal masih kosong: `000` di awal
  /// tetap nol, dan membiarkannya hanya membuat pengguna mengira
  /// ketukannya tidak terbaca.
  AmountInput appendTripleZero() {
    if (isEmpty) return this;
    final next = value * 1000;
    if (next > maxAmount) return this;
    return AmountInput(next);
  }

  /// Menghapus satu digit terakhir.
  AmountInput backspace() => AmountInput(value ~/ 10);

  AmountInput clear() => const AmountInput();

  @override
  bool operator ==(Object other) =>
      other is AmountInput && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AmountInput($value)';
}
