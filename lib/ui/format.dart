/// Format angka dan tanggal untuk seluruh aplikasi.
///
/// Semua tampilan rupiah lewat sini. Menulis `NumberFormat` sendiri di
/// tiap layar cepat sekali menghasilkan dua gaya berbeda di satu aplikasi.
library;

import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _plain = NumberFormat.decimalPattern('id_ID');

/// `25000` → `Rp 25.000`. Rupiah tidak memakai desimal.
String formatRupiah(int amount) => _rupiah.format(amount);

/// `25000` → `25.000`, tanpa awalan mata uang.
String formatNumber(int amount) => _plain.format(amount);

final _dayMonth = DateFormat('d MMM', 'id_ID');
final _dayMonthYear = DateFormat('d MMMM y', 'id_ID');
final _monthYear = DateFormat('MMMM y', 'id_ID');

String formatDayMonth(DateTime date) => _dayMonth.format(date);

String formatFullDate(DateTime date) => _dayMonthYear.format(date);

/// Judul periode bulanan: "September 2026".
String formatMonthYear(DateTime date) => _monthYear.format(date);

/// Label tanggal yang enak dibaca: "Hari ini" dan "Kemarin" dipakai
/// sebisanya karena itu yang paling sering muncul saat mencatat.
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final target = _dateOnly(date);
  final difference = today.difference(target).inDays;

  if (difference == 0) return 'Hari ini';
  if (difference == 1) return 'Kemarin';
  if (difference == -1) return 'Besok';
  if (target.year == today.year) return _dayMonth.format(target);
  return _dayMonthYear.format(target);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Nama hari dua huruf: Sn, Sl, Rb, Km, Jm, Sb, Mg.
///
/// Satu huruf tidak cukup dalam bahasa Indonesia — Senin, Selasa, dan
/// Sabtu semuanya jadi "S" dan sumbu grafiknya tidak terbaca.
const _shortWeekdays = <String>[
  'Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg',
];

String formatShortWeekday(DateTime date) =>
    _shortWeekdays[date.weekday - 1];
