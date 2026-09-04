/// Pengelompokan transaksi per hari beserta subtotal hariannya.
///
/// Ditulis generik dan tanpa impor Flutter maupun Drift supaya bisa diuji
/// sebagai logika murni. Subtotal harian menyentuh rupiah, jadi wajib
/// punya tes.
library;

/// Satu hari berisi transaksi dan jumlah pengeluarannya.
class DailyGroup<T> {
  const DailyGroup({
    required this.date,
    required this.entries,
    required this.subtotal,
  });

  /// Tengah malam hari itu, tanpa komponen jam.
  final DateTime date;

  final List<T> entries;

  /// Jumlah pengeluaran hari itu, memakai porsi sendiri.
  final int subtotal;

  int get count => entries.length;
}

/// Mengelompokkan [items] per hari kalender, hari terbaru lebih dulu.
///
/// Di dalam satu hari, urutan asli [items] dipertahankan — pemanggilnya
/// yang menentukan mau urut jam berapa dulu, bukan fungsi ini.
///
/// [amountOf] sengaja dijadikan parameter alih-alih membaca `total`
/// langsung: yang harus dijumlahkan adalah `ownShare`, dan memisahkannya
/// begini membuat kesalahan itu tidak mungkin tersembunyi di dalam sini.
List<DailyGroup<T>> groupByDay<T>(
  Iterable<T> items, {
  required DateTime Function(T) dateOf,
  required int Function(T) amountOf,
}) {
  final buckets = <DateTime, List<T>>{};

  for (final item in items) {
    final moment = dateOf(item);
    final day = DateTime(moment.year, moment.month, moment.day);
    buckets.putIfAbsent(day, () => <T>[]).add(item);
  }

  final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));

  return [
    for (final day in days)
      DailyGroup<T>(
        date: day,
        entries: buckets[day]!,
        subtotal: buckets[day]!.fold<int>(0, (sum, e) => sum + amountOf(e)),
      ),
  ];
}
