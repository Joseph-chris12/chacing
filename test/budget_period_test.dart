import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/budget_period.dart';

void main() {
  const calc = BudgetPeriodCalculator();

  group('batas minggu', () {
    test('minggu mulai Senin', () {
      // 3 September 2026 jatuh hari Kamis.
      final range = calc.weekContaining(DateTime(2026, 9, 3, 14, 30));

      expect(range.start, DateTime(2026, 8, 31)); // Senin
      expect(range.end, DateTime(2026, 9, 7)); // Senin berikutnya
      expect(range.totalDays, 7);
    });

    test('minggu mulai hari Minggu', () {
      final range =
          calc.weekContaining(DateTime(2026, 9, 3), weekStartsOn: 7);

      expect(range.start, DateTime(2026, 8, 30)); // Minggu
      expect(range.end, DateTime(2026, 9, 6));
    });

    test('tepat di hari pertama periode tidak mundur seminggu', () {
      final range = calc.weekContaining(DateTime(2026, 8, 31, 0, 0));
      expect(range.start, DateTime(2026, 8, 31));
    });

    test('rentang bersifat setengah terbuka', () {
      final range = calc.weekContaining(DateTime(2026, 9, 3));

      expect(range.contains(DateTime(2026, 8, 31)), isTrue);
      expect(range.contains(DateTime(2026, 9, 6, 23, 59)), isTrue);
      // Tengah malam batas atas sudah milik periode berikutnya.
      expect(range.contains(DateTime(2026, 9, 7)), isFalse);
    });

    test('periode sebelumnya menyambung tanpa celah', () {
      final range = calc.weekContaining(DateTime(2026, 9, 3));
      expect(range.previous.end, range.start);
      expect(range.next.start, range.end);
    });

    test('periode bulanan menangani pergantian tahun', () {
      final range = calc.monthContaining(DateTime(2026, 12, 20));
      expect(range.start, DateTime(2026, 12, 1));
      expect(range.end, DateTime(2027, 1, 1));
    });
  });

  group('langkah periode bulanan', () {
    test('mundur satu bulan kalender, bukan sejumlah hari tetap', () {
      // September punya 30 hari. Mundur 30 hari dari 1 September
      // mendarat di 2 Agustus — bukan awal bulan.
      final range = calc.monthContaining(DateTime(2026, 9, 15));

      expect(range.previous.start, DateTime(2026, 8, 1));
      expect(range.previous.end, DateTime(2026, 9, 1));
    });

    test('maju satu bulan kalender', () {
      final range = calc.monthContaining(DateTime(2026, 9, 15));

      expect(range.next.start, DateTime(2026, 10, 1));
      expect(range.next.end, DateTime(2026, 11, 1));
    });

    test('mundur dari Januari menyeberang ke tahun sebelumnya', () {
      final range = calc.monthContaining(DateTime(2027, 1, 10));

      expect(range.previous.start, DateTime(2026, 12, 1));
      expect(range.previous.end, DateTime(2027, 1, 1));
    });
  });

  group('status budget', () {
    BudgetStatus statusOn(int day, {required int spent, int base = 700000}) {
      final now = DateTime(2026, 9, day, 10, 0);
      return BudgetStatus(
        range: calc.weekContaining(now),
        baseAmount: base,
        rolloverAmount: 0,
        spent: spent,
        now: now,
      );
    }

    test('aman dipakai hari ini membagi sisa dengan hari tersisa', () {
      // Kamis 3 Sept, periode Senin 31 Agt sampai Minggu 6 Sept.
      // Tersisa Kamis, Jumat, Sabtu, Minggu = 4 hari.
      final status = statusOn(3, spent: 300000);

      expect(status.daysRemaining, 4);
      expect(status.remaining, 400000);
      expect(status.safeToSpendToday, 100000);
    });

    test('hari terakhir tidak membagi dengan nol', () {
      final status = statusOn(6, spent: 600000);

      expect(status.daysRemaining, 1);
      expect(status.safeToSpendToday, 100000);
    });

    test('budget jebol memberi nol, bukan angka negatif', () {
      final status = statusOn(3, spent: 900000);

      expect(status.isOverBudget, isTrue);
      expect(status.remaining, -200000);
      expect(status.safeToSpendToday, 0);
    });

    test('rollover menambah budget yang tersedia', () {
      final now = DateTime(2026, 9, 3);
      final status = BudgetStatus(
        range: calc.weekContaining(now),
        baseAmount: 700000,
        rolloverAmount: 150000,
        spent: 200000,
        now: now,
      );

      expect(status.available, 850000);
      expect(status.remaining, 650000);
    });

    test('laju terlalu cepat terdeteksi sebelum budget habis', () {
      // Kamis, sudah lewat 3 hari, habis 500rb dari 700rb.
      // Proyeksi akhir minggu jauh di atas budget.
      final status = statusOn(3, spent: 500000);

      expect(status.daysElapsed, 3);
      expect(status.projectedTotal, greaterThan(status.available));
      expect(status.pace, BudgetPace.tooFast);
    });

    test('pengeluaran santai ditandai nyaman', () {
      final status = statusOn(3, spent: 100000);
      expect(status.pace, BudgetPace.comfortable);
    });
  });

  group('budget belum ditetapkan', () {
    test('tanpa budget tidak dianggap jebol', () {
      final now = DateTime(2026, 9, 3);
      final status = BudgetStatus(
        range: calc.weekContaining(now),
        baseAmount: 0,
        rolloverAmount: 0,
        spent: 25000,
        now: now,
      );

      expect(status.hasBudget, isFalse);
      expect(status.isOverBudget, isFalse);
      expect(status.pace, BudgetPace.notSet);
      expect(status.safeToSpendToday, 0);
    });
  });

  group('periode yang sudah lewat', () {
    test('proyeksi sama dengan yang benar-benar dibelanjakan', () {
      // Melihat minggu 31 Agt - 6 Sept dari titik waktu 20 September.
      final range = calc.weekContaining(DateTime(2026, 9, 3));
      final status = BudgetStatus(
        range: range,
        baseAmount: 700000,
        rolloverAmount: 0,
        spent: 420000,
        now: DateTime(2026, 9, 20),
      );

      expect(status.daysRemaining, 0);
      expect(status.daysElapsed, 7);
      // Tanpa perbaikan, angka ini akan membengkak jadi sekitar 490rb
      // karena periode dianggap masih menyisakan satu hari.
      expect(status.projectedTotal, 420000);
      expect(status.safeToSpendToday, 0);
    });
  });

  group('rollover', () {
    test('sisa positif dibawa ke periode berikutnya', () {
      final amount = calc.rolloverFrom(
        previousBaseAmount: 700000,
        spentInPrevious: 550000,
      );
      expect(amount, 150000);
    });

    test('periode jebol bisa dibawa sebagai minus', () {
      final amount = calc.rolloverFrom(
        previousBaseAmount: 700000,
        spentInPrevious: 800000,
      );
      expect(amount, -100000);
    });

    test('minus bisa dimatikan lewat setting', () {
      final amount = calc.rolloverFrom(
        previousBaseAmount: 700000,
        spentInPrevious: 800000,
        allowNegative: false,
      );
      expect(amount, 0);
    });
  });
}
