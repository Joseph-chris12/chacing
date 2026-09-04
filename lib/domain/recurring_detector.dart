/// Menebak pengeluaran yang berulang: langganan, cicilan, tagihan bulanan.
///
/// Gunanya bukan sekadar informasi. Langganan adalah jenis pengeluaran
/// yang paling mudah lupa — uangnya keluar sendiri tiap bulan tanpa
/// pernah dirasakan sebagai keputusan belanja. Memunculkannya kembali ke
/// permukaan biasanya langsung menghasilkan satu dua pembatalan.
///
/// Semua tebakan bersifat dugaan, bukan kepastian. Karena itu ambangnya
/// dibuat ketat: lebih baik melewatkan langganan yang benar daripada
/// menuduh belanja biasa sebagai langganan dan membuat daftarnya penuh
/// sampah yang tidak dipercaya.
library;

/// Satu pengeluaran yang dilihat oleh pendeteksi.
class RecurringInput {
  const RecurringInput({
    required this.merchant,
    required this.amount,
    required this.occurredAt,
  });

  final String merchant;
  final int amount;
  final DateTime occurredAt;
}

/// Irama pengulangan yang dikenali.
enum RecurringCadence {
  weekly('Mingguan', 7),
  monthly('Bulanan', 30),
  yearly('Tahunan', 365);

  const RecurringCadence(this.label, this.days);

  final String label;
  final int days;
}

/// Dugaan langganan beserta bukti yang mendasarinya.
class RecurringCandidate {
  const RecurringCandidate({
    required this.merchant,
    required this.typicalAmount,
    required this.cadence,
    required this.occurrences,
    required this.lastSeen,
  });

  final String merchant;

  /// Nominal yang paling mewakili, diambil dari nilai tengah.
  ///
  /// Nilai tengah, bukan rata-rata: satu bulan yang kebetulan mahal
  /// karena denda keterlambatan tidak boleh menggeser angkanya.
  final int typicalAmount;

  final RecurringCadence cadence;
  final int occurrences;
  final DateTime lastSeen;

  /// Perkiraan tanggal tagihan berikutnya.
  DateTime get nextExpected => DateTime(
        lastSeen.year,
        lastSeen.month,
        lastSeen.day + cadence.days,
      );

  /// Perkiraan biaya setahun, untuk menakar apakah layak dipertahankan.
  ///
  /// Rp 50.000 sebulan terdengar kecil sampai ditulis sebagai Rp 600.000
  /// setahun — dan bentuk kedua itulah yang membuat orang memutuskan.
  int get yearlyCost => switch (cadence) {
        RecurringCadence.weekly => typicalAmount * 52,
        RecurringCadence.monthly => typicalAmount * 12,
        RecurringCadence.yearly => typicalAmount,
      };
}

class RecurringDetector {
  const RecurringDetector({
    this.minimumOccurrences = 3,
    this.amountTolerance = 0.12,
    this.intervalTolerance = 0.25,
  });

  /// Berapa kali harus terlihat sebelum dianggap berulang.
  ///
  /// Dua kali bukan pola — dua kali bisa saja kebetulan. Tiga kali dengan
  /// jarak yang mirip baru mulai berarti sesuatu.
  final int minimumOccurrences;

  /// Selisih nominal yang masih dianggap sama, sebagai pecahan.
  final double amountTolerance;

  /// Selisih jarak hari yang masih dianggap satu irama.
  final double intervalTolerance;

  List<RecurringCandidate> detect(Iterable<RecurringInput> entries) {
    final byMerchant = <String, List<RecurringInput>>{};
    for (final entry in entries) {
      if (entry.amount <= 0) continue;
      byMerchant
          .putIfAbsent(_normalize(entry.merchant), () => [])
          .add(entry);
    }

    final candidates = <RecurringCandidate>[];

    for (final group in byMerchant.values) {
      if (group.length < minimumOccurrences) continue;

      final sorted = [...group]
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

      final amounts = sorted.map((e) => e.amount).toList()..sort();
      final typical = _median(amounts);
      if (typical <= 0) continue;

      // Nominal harus konsisten. Belanja di minimarket yang sama tiap
      // minggu dengan angka berbeda-beda bukan langganan.
      final consistent = sorted.every(
        (e) => (e.amount - typical).abs() <= typical * amountTolerance,
      );
      if (!consistent) continue;

      final gaps = <int>[];
      for (var i = 1; i < sorted.length; i++) {
        gaps.add(
          sorted[i].occurredAt.difference(sorted[i - 1].occurredAt).inDays,
        );
      }
      if (gaps.isEmpty) continue;

      final typicalGap = _median(gaps..sort());
      final cadence = _cadenceFor(typicalGap);
      if (cadence == null) continue;

      // Jaraknya juga harus konsisten, bukan hanya rata-ratanya kebetulan
      // pas. Tiga transaksi berdempetan lalu satu jauh di belakang punya
      // rata-rata yang mirip bulanan tanpa jadi langganan.
      final steady = gaps.every(
        (gap) => (gap - typicalGap).abs() <= typicalGap * intervalTolerance,
      );
      if (!steady) continue;

      candidates.add(
        RecurringCandidate(
          merchant: sorted.last.merchant,
          typicalAmount: typical,
          cadence: cadence,
          occurrences: sorted.length,
          lastSeen: sorted.last.occurredAt,
        ),
      );
    }

    // Yang paling mahal setahun lebih dulu: itu yang paling layak
    // ditimbang ulang.
    candidates.sort((a, b) => b.yearlyCost.compareTo(a.yearlyCost));
    return candidates;
  }

  RecurringCadence? _cadenceFor(int gapDays) {
    for (final cadence in RecurringCadence.values) {
      if ((gapDays - cadence.days).abs() <= cadence.days * intervalTolerance) {
        return cadence;
      }
    }
    return null;
  }

  /// Nama tempat disamakan agar "Spotify" dan "spotify  " jadi satu.
  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  int _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }
}
