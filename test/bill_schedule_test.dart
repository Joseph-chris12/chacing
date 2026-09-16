/// Tes aturan tanggal tagihan tetap.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/bill_schedule.dart';

void main() {
  group('tanggal jatuh tempo', () {
    test('tanggal biasa dipakai apa adanya', () {
      expect(dueDateIn(2026, 9, 10), DateTime(2026, 9, 10));
    });

    test('tanggal 31 di bulan 30 hari jatuh di hari terakhir', () {
      expect(dueDateIn(2026, 9, 31), DateTime(2026, 9, 30));
    });

    test('tanggal 31 di Februari tidak melompat ke Maret', () {
      // `DateTime(2026, 2, 31)` bernilai 3 Maret. Tagihan Februari
      // akan hilang kalau dibiarkan begitu.
      expect(dueDateIn(2026, 2, 31), DateTime(2026, 2, 28));
      expect(dueDateIn(2028, 2, 30), DateTime(2028, 2, 29));
    });
  });

  group('status', () {
    BillSchedule on(int day, {int dueDay = 10, DateTime? paid, int hour = 9}) {
      return BillSchedule(
        dueDay: dueDay,
        paidForMonth: paid,
        now: DateTime(2026, 9, day, hour),
      );
    }

    test('masih jauh', () {
      expect(on(1).status, BillStatus.upcoming);
      expect(on(1).status.needsAttention, isFalse);
    });

    test('tiga hari sebelum jatuh tempo mulai diingatkan', () {
      expect(on(6).status, BillStatus.upcoming);
      expect(on(7).status, BillStatus.dueSoon);
      expect(on(7).daysUntilDue, 3);
    });

    test('hari jatuh tempo tetap "hari ini" sampai tengah malam', () {
      expect(on(10, hour: 0).status, BillStatus.dueToday);
      expect(on(10, hour: 23).status, BillStatus.dueToday);
    });

    test('lewat jatuh tempo', () {
      final schedule = on(12);
      expect(schedule.status, BillStatus.overdue);
      expect(schedule.label, 'Lewat 2 hari dari jatuh tempo');
    });

    test('dibayar bulan ini mengalahkan semua status lain', () {
      final paid = on(12, paid: DateTime(2026, 9, 1));
      expect(paid.status, BillStatus.paid);
      expect(paid.status.needsAttention, isFalse);
    });

    test('pembayaran bulan lalu tidak menutup tagihan bulan ini', () {
      final schedule = on(12, paid: DateTime(2026, 8, 1));
      expect(schedule.isPaidThisMonth, isFalse);
      expect(schedule.status, BillStatus.overdue);
    });

    test('bulan yang sama di tahun berbeda bukan bulan ini', () {
      final schedule = on(12, paid: DateTime(2025, 9, 1));
      expect(schedule.isPaidThisMonth, isFalse);
    });

    test('label jatuh tempo besok', () {
      expect(on(9).label, 'Jatuh tempo besok');
    });
  });
}
