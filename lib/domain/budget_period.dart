/// Perhitungan periode dan status budget.
///
/// Semua tanggal diperlakukan sebagai waktu lokal. Indonesia tidak punya
/// daylight saving, tapi konstruktor `DateTime(y, m, d + 7)` tetap dipakai
/// alih-alih `add(Duration(days: 7))` supaya tidak ada kejutan kalau suatu
/// saat aplikasi dipakai di zona waktu yang punya DST.
library;

import 'dart:math' as math;

/// Panjang satu periode budget, dipilih sendiri oleh pengguna.
///
/// Ketiganya punya alasan pakai yang berbeda:
///
///  * [day] untuk yang ingin dikekang harian, misalnya jatah makan siang.
///  * [week] bawaan. Cukup longgar untuk akhir pekan tapi masih terasa.
///  * [month] untuk yang penghasilannya bulanan dan berpikir per gajian.
///
/// Dipakai juga oleh [BudgetPeriodRange.previous] dan [BudgetPeriodRange.next]:
/// hari dan minggu panjangnya tetap, tapi bulan berubah-ubah sehingga tidak
/// boleh dilangkahi dengan menambah sejumlah hari.
enum PeriodKind {
  day('Harian', 'hari ini', 'hari'),
  week('Mingguan', 'minggu ini', 'minggu'),
  month('Bulanan', 'bulan ini', 'bulan');

  const PeriodKind(this.label, this.thisPeriod, this.unit);

  /// Nama periode untuk tombol dan judul: "Mingguan".
  final String label;

  /// Potongan kalimat untuk teks berjalan: "terpakai minggu ini".
  final String thisPeriod;

  /// Satuan waktunya sendiri: "minggu".
  ///
  /// Dipisah dari [label] karena keduanya tidak bisa saling diturunkan.
  /// "per " + huruf kecil dari "Mingguan" menghasilkan "per mingguan",
  /// yang bukan bahasa Indonesia yang benar.
  final String unit;
}

/// Rentang waktu setengah terbuka: [start, end).
///
/// Batas atas sengaja eksklusif supaya query `occurred_at >= start AND
/// occurred_at < end` tidak pernah menghitung ganda transaksi yang jatuh
/// tepat di tengah malam.
class BudgetPeriodRange {
  const BudgetPeriodRange({
    required this.start,
    required this.end,
    this.kind = PeriodKind.week,
  });

  final DateTime start;
  final DateTime end;
  final PeriodKind kind;

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);

  /// Jumlah hari dalam periode ini.
  int get totalDays => end.difference(start).inDays;

  /// Periode sebelumnya, menyambung tanpa celah.
  ///
  /// Untuk periode bulanan, mundur satu bulan kalender — bukan mundur
  /// sejumlah hari. September punya 30 hari, jadi mundur 30 hari dari
  /// 1 September akan mendarat di 2 Agustus, bukan 1 Agustus.
  BudgetPeriodRange get previous {
    switch (kind) {
      case PeriodKind.month:
        return BudgetPeriodRange(
          start: DateTime(start.year, start.month - 1, 1),
          end: start,
          kind: kind,
        );
      case PeriodKind.day:
      case PeriodKind.week:
        final days = totalDays;
        return BudgetPeriodRange(
          start: DateTime(start.year, start.month, start.day - days),
          end: start,
          kind: kind,
        );
    }
  }

  BudgetPeriodRange get next {
    switch (kind) {
      case PeriodKind.month:
        return BudgetPeriodRange(
          start: end,
          end: DateTime(end.year, end.month + 1, 1),
          kind: kind,
        );
      case PeriodKind.day:
      case PeriodKind.week:
        return BudgetPeriodRange(
          start: end,
          end: DateTime(end.year, end.month, end.day + totalDays),
          kind: kind,
        );
    }
  }

  /// Setiap hari dalam periode, dipakai sebagai sumbu grafik.
  ///
  /// Selalu lengkap termasuk hari yang tidak ada pengeluarannya. Grafik
  /// yang melewatkan hari kosong membuat pola belanja salah dibaca —
  /// tujuh batang rapat terlihat seperti belanja tiap hari.
  List<DateTime> get days => [
        for (var i = 0; i < totalDays; i++)
          DateTime(start.year, start.month, start.day + i),
      ];

  @override
  bool operator ==(Object other) =>
      other is BudgetPeriodRange &&
      other.start == start &&
      other.end == end &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'BudgetPeriodRange($start .. $end, ${kind.name})';
}

/// Ringkasan status budget untuk satu periode.
class BudgetStatus {
  const BudgetStatus({
    required this.range,
    required this.baseAmount,
    required this.rolloverAmount,
    required this.spent,
    required this.now,
  });

  final BudgetPeriodRange range;

  /// Budget yang ditetapkan pengguna untuk satu periode.
  /// Nol berarti pengguna belum menetapkan budget sama sekali.
  final int baseAmount;

  /// Sisa yang dibawa dari periode sebelumnya. Nol kalau rollover mati.
  /// Bisa negatif kalau periode lalu jebol dan rollover aktif.
  final int rolloverAmount;

  /// Total pengeluaran dalam periode ini, memakai porsi sendiri.
  final int spent;

  final DateTime now;

  /// Apakah pengguna sudah menetapkan budget.
  ///
  /// Dipisah dari [isOverBudget] karena keduanya sangat berbeda bagi
  /// pengguna: belum menetapkan budget bukan berarti budgetnya jebol.
  bool get hasBudget => baseAmount > 0;

  /// Budget efektif setelah rollover.
  int get available => baseAmount + rolloverAmount;

  int get remaining => available - spent;

  bool get isOverBudget => hasBudget && remaining < 0;

  /// Berapa persen budget yang sudah terpakai. Bisa lebih dari 1.
  double get usedRatio => available <= 0 ? 1.0 : spent / available;

  /// Hari yang tersisa termasuk hari ini.
  ///
  /// Nol kalau periode sudah lewat — dipakai saat pengguna menengok
  /// periode-periode sebelumnya.
  int get daysRemaining {
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(range.start)) return range.totalDays;
    if (!today.isBefore(range.end)) return 0;
    return range.end.difference(today).inDays;
  }

  int get daysElapsed => math.max(0, range.totalDays - daysRemaining);

  /// Angka yang paling berguna sehari-hari: berapa yang aman dipakai
  /// hari ini supaya budget cukup sampai akhir periode.
  ///
  /// Nol kalau sudah jebol — tidak dibuat negatif karena "boleh pakai
  /// minus sekian" tidak berarti apa-apa bagi pengguna.
  int get safeToSpendToday {
    if (!hasBudget) return 0;
    if (remaining <= 0) return 0;
    if (daysRemaining <= 0) return 0;
    return remaining ~/ daysRemaining;
  }

  /// Laju pengeluaran ideal per hari kalau budget dihabiskan rata.
  int get idealDailyPace =>
      range.totalDays == 0 ? 0 : available ~/ range.totalDays;

  /// Proyeksi total pengeluaran akhir periode kalau laju saat ini bertahan.
  ///
  /// Untuk periode yang sudah lewat, [daysElapsed] sama dengan panjang
  /// periode sehingga hasilnya persis [spent] — tidak ada proyeksi ke
  /// masa depan yang tidak akan pernah terjadi.
  int get projectedTotal {
    if (daysElapsed == 0) return spent;
    final perDay = spent / daysElapsed;
    return (perDay * range.totalDays).round();
  }

  /// Dipakai untuk memilih warna dan nada pesan di UI.
  BudgetPace get pace {
    if (!hasBudget) return BudgetPace.notSet;
    if (isOverBudget) return BudgetPace.exceeded;
    if (available <= 0) return BudgetPace.onTrack;
    if (projectedTotal > available) return BudgetPace.tooFast;
    if (projectedTotal < available * 0.7) return BudgetPace.comfortable;
    return BudgetPace.onTrack;
  }
}

enum BudgetPace { notSet, comfortable, onTrack, tooFast, exceeded }

class BudgetPeriodCalculator {
  const BudgetPeriodCalculator();

  /// Periode sesuai jenis yang dipilih pengguna.
  ///
  /// Satu pintu masuk supaya layar tidak perlu tahu cara menghitung
  /// masing-masing jenis periode.
  BudgetPeriodRange periodContaining(
    DateTime moment,
    PeriodKind kind, {
    int weekStartsOn = DateTime.monday,
  }) {
    switch (kind) {
      case PeriodKind.day:
        return dayContaining(moment);
      case PeriodKind.week:
        return weekContaining(moment, weekStartsOn: weekStartsOn);
      case PeriodKind.month:
        return monthContaining(moment);
    }
  }

  /// Periode harian: tengah malam sampai tengah malam berikutnya.
  BudgetPeriodRange dayContaining(DateTime moment) {
    final start = DateTime(moment.year, moment.month, moment.day);
    return BudgetPeriodRange(
      start: start,
      end: DateTime(start.year, start.month, start.day + 1),
      kind: PeriodKind.day,
    );
  }

  /// Periode mingguan yang memuat [moment].
  ///
  /// [weekStartsOn] mengikuti `DateTime.weekday`: 1 = Senin, 7 = Minggu.
  BudgetPeriodRange weekContaining(DateTime moment, {int weekStartsOn = 1}) {
    assert(weekStartsOn >= 1 && weekStartsOn <= 7);

    final day = DateTime(moment.year, moment.month, moment.day);
    final offset = (day.weekday - weekStartsOn + 7) % 7;
    final start = DateTime(day.year, day.month, day.day - offset);

    return BudgetPeriodRange(
      start: start,
      end: DateTime(start.year, start.month, start.day + 7),
    );
  }

  /// Periode bulanan yang memuat [moment].
  BudgetPeriodRange monthContaining(DateTime moment) {
    final start = DateTime(moment.year, moment.month, 1);
    return BudgetPeriodRange(
      start: start,
      end: DateTime(moment.year, moment.month + 1, 1),
      kind: PeriodKind.month,
    );
  }

  /// Menghitung sisa yang dibawa dari periode sebelumnya.
  ///
  /// Rollover sengaja dibatasi hanya satu periode ke belakang, tidak
  /// berantai. Kalau dirantai sampai awal waktu, angkanya jadi liar dan
  /// tidak ada pengguna yang bisa menjelaskan dari mana asalnya.
  ///
  /// [spentInPrevious] diambil dari repository.
  int rolloverFrom({
    required int previousBaseAmount,
    required int spentInPrevious,
    bool allowNegative = true,
  }) {
    final leftover = previousBaseAmount - spentInPrevious;
    if (leftover < 0 && !allowNegative) return 0;
    return leftover;
  }
}
