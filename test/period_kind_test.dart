/// Tes untuk periode budget yang bisa dipilih pengguna.
///
/// Harian dan bulanan baru ditambahkan; mingguan sudah diuji di
/// `budget_period_test.dart`. Yang dijaga di sini adalah hal-hal yang
/// paling mudah salah saat panjang periode tidak lagi selalu tujuh hari.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/budget_period.dart';

void main() {
  const calc = BudgetPeriodCalculator();

  group('periode harian', () {
    test('mulai tengah malam dan berakhir tengah malam berikutnya', () {
      final range = calc.dayContaining(DateTime(2026, 9, 4, 14, 30));

      expect(range.start, DateTime(2026, 9, 4));
      expect(range.end, DateTime(2026, 9, 5));
      expect(range.totalDays, 1);
      expect(range.kind, PeriodKind.day);
    });

    test('setengah terbuka: tengah malam berikutnya sudah hari lain', () {
      final range = calc.dayContaining(DateTime(2026, 9, 4));

      expect(range.contains(DateTime(2026, 9, 4)), isTrue);
      expect(range.contains(DateTime(2026, 9, 4, 23, 59, 59)), isTrue);
      expect(range.contains(DateTime(2026, 9, 5)), isFalse);
    });

    test('mundur dan maju satu hari', () {
      final range = calc.dayContaining(DateTime(2026, 9, 1));

      // Menyeberang batas bulan tanpa mendarat di tanggal nol.
      expect(range.previous.start, DateTime(2026, 8, 31));
      expect(range.previous.end, DateTime(2026, 9, 1));
      expect(range.next.start, DateTime(2026, 9, 2));
    });

    test('sisa hari ini tidak membagi dengan nol', () {
      final now = DateTime(2026, 9, 4, 20, 0);
      final status = BudgetStatus(
        range: calc.dayContaining(now),
        baseAmount: 50000,
        rolloverAmount: 0,
        spent: 20000,
        now: now,
      );

      expect(status.daysRemaining, 1);
      // Untuk periode harian, yang aman dipakai adalah seluruh sisanya:
      // tidak ada hari lain untuk membaginya.
      expect(status.safeToSpendToday, 30000);
    });
  });

  group('periode bulanan', () {
    test('panjangnya mengikuti jumlah hari bulan itu', () {
      expect(calc.monthContaining(DateTime(2026, 9, 10)).totalDays, 30);
      expect(calc.monthContaining(DateTime(2026, 10, 10)).totalDays, 31);
      expect(calc.monthContaining(DateTime(2026, 2, 10)).totalDays, 28);
    });

    test('tahun kabisat dihitung benar', () {
      expect(calc.monthContaining(DateTime(2028, 2, 10)).totalDays, 29);
    });
  });

  group('periodContaining memilih sesuai jenis', () {
    final moment = DateTime(2026, 9, 4, 9, 0);

    test('harian', () {
      final range = calc.periodContaining(moment, PeriodKind.day);
      expect(range.totalDays, 1);
      expect(range.start, DateTime(2026, 9, 4));
    });

    test('mingguan', () {
      final range = calc.periodContaining(moment, PeriodKind.week);
      expect(range.totalDays, 7);
      // 4 September 2026 jatuh hari Jumat, jadi minggunya mulai Senin 31.
      expect(range.start, DateTime(2026, 8, 31));
    });

    test('bulanan', () {
      final range = calc.periodContaining(moment, PeriodKind.month);
      expect(range.start, DateTime(2026, 9, 1));
      expect(range.end, DateTime(2026, 10, 1));
    });
  });

  group('daftar hari untuk sumbu grafik', () {
    test('mingguan menghasilkan tujuh hari berurutan', () {
      final days = calc.weekContaining(DateTime(2026, 9, 4)).days;

      expect(days.length, 7);
      expect(days.first, DateTime(2026, 8, 31));
      expect(days.last, DateTime(2026, 9, 6));
    });

    test('bulanan menghasilkan seluruh hari bulan itu', () {
      final days = calc.monthContaining(DateTime(2026, 9, 15)).days;

      expect(days.length, 30);
      expect(days.first, DateTime(2026, 9, 1));
      expect(days.last, DateTime(2026, 9, 30));
    });

    test('harian menghasilkan satu hari', () {
      final days = calc.dayContaining(DateTime(2026, 9, 4)).days;

      expect(days.length, 1);
      expect(days.single, DateTime(2026, 9, 4));
    });

    test('tidak ada hari yang terlewat di pergantian bulan', () {
      // Minggu 31 Agustus sampai 6 September menyeberang batas bulan.
      final days = calc.weekContaining(DateTime(2026, 9, 2)).days;

      expect(days[0], DateTime(2026, 8, 31));
      expect(days[1], DateTime(2026, 9, 1));
      expect(days[6], DateTime(2026, 9, 6));
    });
  });

  group('label periode', () {
    test('setiap jenis punya nama dan potongan kalimatnya', () {
      expect(PeriodKind.day.label, 'Harian');
      expect(PeriodKind.week.label, 'Mingguan');
      expect(PeriodKind.month.label, 'Bulanan');

      expect(PeriodKind.day.thisPeriod, 'hari ini');
      expect(PeriodKind.week.thisPeriod, 'minggu ini');
      expect(PeriodKind.month.thisPeriod, 'bulan ini');
    });

    test('satuan waktu terpisah dari nama periode', () {
      // "per " + huruf kecil dari label menghasilkan "per mingguan",
      // yang salah. Satuannya harus disimpan sendiri.
      expect(PeriodKind.day.unit, 'hari');
      expect(PeriodKind.week.unit, 'minggu');
      expect(PeriodKind.month.unit, 'bulan');

      for (final kind in PeriodKind.values) {
        expect(kind.unit, isNot(equals(kind.label.toLowerCase())));
      }
    });
  });
}
