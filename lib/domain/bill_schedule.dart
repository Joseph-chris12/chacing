/// Kapan sebuah tagihan tetap jatuh tempo, dan apakah sudah dibayar.
///
/// Murni Dart tanpa database, supaya aturan tanggalnya bisa diuji sendiri.
/// Aturan tanggal inilah yang paling mudah salah: tagihan tanggal 31 di
/// bulan Februari, tagihan yang dibayar bulan lalu, tagihan yang lewat
/// tengah malam.
library;

/// Keadaan tagihan pada bulan berjalan.
enum BillStatus {
  /// Sudah dibayar untuk bulan ini.
  paid,

  /// Belum dibayar dan jatuh temponya masih lebih dari [BillSchedule.soonDays]
  /// hari lagi.
  upcoming,

  /// Belum dibayar dan jatuh tempo dalam beberapa hari ke depan.
  dueSoon,

  /// Belum dibayar dan jatuh tempo hari ini.
  dueToday,

  /// Belum dibayar dan tanggal jatuh temponya sudah lewat.
  overdue;

  /// Tagihan yang perlu muncul di beranda.
  bool get needsAttention =>
      this == dueSoon || this == dueToday || this == overdue;
}

/// Tanggal jatuh tempo di bulan tertentu.
///
/// Tagihan tanggal 31 jatuh di hari terakhir bulan yang lebih pendek —
/// 30 September, 28 atau 29 Februari. Melompat ke awal bulan berikutnya
/// (yang terjadi kalau `DateTime(2026, 2, 31)` dibiarkan apa adanya)
/// akan membuat tagihan Februari seolah tidak pernah ada.
DateTime dueDateIn(int year, int month, int dueDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = dueDay < 1 ? 1 : (dueDay > lastDay ? lastDay : dueDay);
  return DateTime(year, month, day);
}

class BillSchedule {
  const BillSchedule({
    required this.dueDay,
    required this.paidForMonth,
    required this.now,
    this.soonDays = 3,
  });

  /// Tanggal jatuh tempo 1–31.
  final int dueDay;

  /// Awal bulan terakhir yang sudah dibayar, atau null kalau belum pernah
  /// (atau pembayaran terakhirnya sudah dihapus).
  final DateTime? paidForMonth;

  final DateTime now;

  /// Seberapa dekat jatuh tempo sebelum tagihan mulai ditampilkan.
  final int soonDays;

  DateTime get _today => DateTime(now.year, now.month, now.day);

  /// Awal bulan berjalan — bulan yang sedang ditagih.
  DateTime get currentMonth => DateTime(now.year, now.month, 1);

  DateTime get dueDate => dueDateIn(now.year, now.month, dueDay);

  bool get isPaidThisMonth {
    final paid = paidForMonth;
    return paid != null &&
        paid.year == currentMonth.year &&
        paid.month == currentMonth.month;
  }

  /// Negatif kalau sudah lewat. Dihitung dari tanggal saja, bukan jam,
  /// supaya tagihan hari ini tidak berubah jadi "lewat" di sore hari.
  int get daysUntilDue => dueDate.difference(_today).inDays;

  BillStatus get status {
    if (isPaidThisMonth) return BillStatus.paid;

    final days = daysUntilDue;
    if (days < 0) return BillStatus.overdue;
    if (days == 0) return BillStatus.dueToday;
    if (days <= soonDays) return BillStatus.dueSoon;
    return BillStatus.upcoming;
  }

  /// Kalimat singkat untuk daftar. Nadanya memberi tahu, tidak menegur.
  String get label {
    switch (status) {
      case BillStatus.paid:
        return 'Sudah dibayar bulan ini';
      case BillStatus.overdue:
        final late = -daysUntilDue;
        return 'Lewat $late hari dari jatuh tempo';
      case BillStatus.dueToday:
        return 'Jatuh tempo hari ini';
      case BillStatus.dueSoon:
        final days = daysUntilDue;
        return days == 1 ? 'Jatuh tempo besok' : 'Jatuh tempo $days hari lagi';
      case BillStatus.upcoming:
        return 'Jatuh tempo tanggal ${dueDate.day}';
    }
  }
}
