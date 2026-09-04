/// Mesin perhitungan split bill.
///
/// Semua nominal berupa `int` dalam rupiah penuh (tanpa desimal).
/// Jangan pernah pakai `double` untuk menyimpan uang — hanya untuk
/// proporsi sementara di dalam file ini.
///
/// Aturan yang dipegang:
///  1. Pajak, service charge, dan diskon global dialokasikan proporsional
///     terhadap subtotal masing-masing orang, bukan dibagi rata.
///  2. Total dari semua porsi WAJIB persis sama dengan bagian struk yang
///     benar-benar ditugaskan ke seseorang. Sisa pembulatan dibagikan
///     dengan metode largest remainder.
///  3. Item yang belum ditugaskan ke siapa pun TIDAK dibebankan diam-diam
///     ke orang lain. Nilainya ditinggalkan di luar perhitungan dan
///     pengguna diberi peringatan.
///  4. "Siapa yang makan" (assignment) terpisah dari "siapa yang bayar"
///     (payment). Utang dihitung dari selisih keduanya.
library;

import 'dart:math' as math;

/// Satu baris item pada struk.
class LineItem {
  const LineItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
  });

  final String id;
  final String name;
  final int quantity;

  /// Harga satuan dalam rupiah.
  final int unitPrice;

  /// Diskon yang menempel pada item ini saja (bukan diskon global).
  final int discount;

  /// Nilai bersih item setelah diskon item.
  int get total => math.max(0, quantity * unitPrice - discount);
}

/// Menandakan bahwa [personId] ikut menikmati [lineItemId].
///
/// [weight] dipakai kalau pembagian tidak rata. Contoh: sate 10 tusuk
/// dimakan Andi 6 dan Budi 4 → weight 6 dan 4.
class Assignment {
  const Assignment({
    required this.lineItemId,
    required this.personId,
    this.weight = 1,
  });

  final String lineItemId;
  final String personId;
  final int weight;
}

/// Hasil perhitungan untuk satu orang.
class PersonShare {
  const PersonShare({
    required this.personId,
    required this.itemSubtotal,
    required this.adjustment,
    required this.total,
  });

  final String personId;

  /// Jumlah nilai item yang jadi porsinya, sebelum pajak dan diskon global.
  final int itemSubtotal;

  /// Bagiannya dari pajak + service - diskon global. Bisa negatif.
  final int adjustment;

  /// Yang benar-benar jadi pengeluarannya. Angka INI yang masuk budget.
  final int total;
}

/// Satu instruksi transfer untuk melunasi utang.
class Settlement {
  const Settlement({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amount,
  });

  final String fromPersonId;
  final String toPersonId;
  final int amount;
}

class SplitResult {
  const SplitResult({
    required this.shares,
    required this.settlements,
    required this.warnings,
    this.unallocated = 0,
  });

  final List<PersonShare> shares;

  /// Daftar transfer minimal agar semua orang impas.
  final List<Settlement> settlements;

  /// Masalah yang ditemukan tapi tidak fatal. Tampilkan ke pengguna
  /// supaya bisa dikoreksi, jangan disembunyikan.
  final List<String> warnings;

  /// Bagian dari total struk yang tidak ditugaskan ke siapa pun.
  ///
  /// Nol kalau semua item sudah punya pemilik. Kalau tidak nol, jumlah
  /// seluruh [shares] memang lebih kecil dari total struk — itu disengaja.
  final int unallocated;

  PersonShare? shareOf(String personId) {
    for (final s in shares) {
      if (s.personId == personId) return s;
    }
    return null;
  }
}

class SplitCalculator {
  const SplitCalculator();

  /// Menghitung porsi tiap orang beserta rekomendasi transfer.
  ///
  /// [tax], [serviceCharge], dan [globalDiscount] adalah nilai yang berlaku
  /// untuk seluruh struk. [receiptTotal] adalah total yang tercetak di struk;
  /// dipakai untuk validasi dan sebagai target pembulatan. Kalau null,
  /// target dihitung dari item.
  ///
  /// [payments] memetakan personId ke jumlah yang dia bayarkan di kasir.
  SplitResult calculate({
    required List<LineItem> items,
    required List<Assignment> assignments,
    int tax = 0,
    int serviceCharge = 0,
    int globalDiscount = 0,
    int? receiptTotal,
    Map<String, int> payments = const {},
  }) {
    final warnings = <String>[];

    final assignmentsByItem = <String, List<Assignment>>{};
    for (final a in assignments) {
      if (a.weight <= 0) {
        warnings.add('Bobot tidak valid untuk ${a.personId}, diabaikan.');
        continue;
      }
      assignmentsByItem.putIfAbsent(a.lineItemId, () => []).add(a);
    }

    // Porsi eksak tiap orang, disimpan sebagai double sementara.
    final exactSubtotal = <String, double>{};

    /// Nilai seluruh item di struk, termasuk yang belum ditugaskan.
    var itemsSubtotal = 0;

    /// Nilai item yang sudah punya pemilik. Inilah dasar pembagian —
    /// memakai [itemsSubtotal] di sini berarti membebankan item yatim
    /// ke orang lain tanpa mereka sadari.
    var assignedSubtotal = 0;

    for (final item in items) {
      itemsSubtotal += item.total;
      final itemAssignments = assignmentsByItem[item.id];

      if (itemAssignments == null || itemAssignments.isEmpty) {
        warnings.add('Item "${item.name}" belum ditugaskan ke siapa pun.');
        continue;
      }

      assignedSubtotal += item.total;

      final totalWeight =
          itemAssignments.fold<int>(0, (sum, a) => sum + a.weight);

      for (final a in itemAssignments) {
        final portion = item.total * a.weight / totalWeight;
        exactSubtotal[a.personId] = (exactSubtotal[a.personId] ?? 0) + portion;
      }
    }

    final adjustments = tax + serviceCharge - globalDiscount;
    final computedTotal = itemsSubtotal + adjustments;

    if (receiptTotal != null && receiptTotal != computedTotal) {
      final diff = receiptTotal - computedTotal;
      warnings.add(
        'Total struk ($receiptTotal) tidak cocok dengan hasil hitung '
        '($computedTotal), selisih $diff. Periksa kembali item atau pajak.',
      );
    }

    /// Total seluruh struk, termasuk bagian yang belum ditugaskan.
    final fullTarget = receiptTotal ?? computedTotal;

    if (exactSubtotal.isEmpty) {
      return SplitResult(
        shares: const [],
        settlements: const [],
        warnings: [...warnings, 'Tidak ada item yang ditugaskan.'],
        unallocated: fullTarget,
      );
    }

    /// Bagian dari [fullTarget] yang benar-benar ditanggung orang.
    ///
    /// Karena pajak dan diskon dialokasikan proporsional terhadap subtotal,
    /// porsi item yang ditugaskan menanggung proporsi yang sama dari
    /// pajak dan diskon.
    final assignedTarget = itemsSubtotal == 0
        ? 0
        : (fullTarget * assignedSubtotal / itemsSubtotal).round();

    final unallocated = fullTarget - assignedTarget;
    if (unallocated != 0) {
      warnings.add(
        'Rp $unallocated dari total struk tidak ditugaskan ke siapa pun '
        'dan tidak ikut dibagi.',
      );
    }

    // Skala dari subtotal item ke total akhir. Karena pajak dan diskon
    // dialokasikan proporsional, satu faktor sudah cukup.
    final scale =
        assignedSubtotal == 0 ? 0.0 : assignedTarget / assignedSubtotal;

    final exactTotals = <String, double>{
      for (final e in exactSubtotal.entries) e.key: e.value * scale,
    };

    final roundedTotals = _largestRemainderRound(exactTotals, assignedTarget);
    final roundedSubtotals =
        _largestRemainderRound(exactSubtotal, assignedSubtotal);

    final shares = <PersonShare>[];
    final personIds = roundedTotals.keys.toList()..sort();
    for (final personId in personIds) {
      final total = roundedTotals[personId]!;
      final subtotal = roundedSubtotals[personId]!;
      shares.add(
        PersonShare(
          personId: personId,
          itemSubtotal: subtotal,
          adjustment: total - subtotal,
          total: total,
        ),
      );
    }

    final totalPaid = payments.values.fold<int>(0, (sum, v) => sum + v);
    if (payments.isNotEmpty && totalPaid != fullTarget) {
      warnings.add(
        'Jumlah yang dibayarkan ($totalPaid) tidak sama dengan '
        'total ($fullTarget).',
      );
    }

    return SplitResult(
      shares: shares,
      settlements: _settle(shares: shares, payments: payments),
      warnings: warnings,
      unallocated: unallocated,
    );
  }

  /// Membulatkan nilai pecahan ke rupiah bulat sambil menjamin
  /// jumlahnya persis sama dengan [target].
  ///
  /// Setiap nilai dibulatkan ke bawah dulu, lalu sisa rupiah dibagikan
  /// satu per satu ke pemilik pecahan terbesar. Urutan personId dipakai
  /// sebagai penentu saat pecahannya sama, supaya hasilnya konsisten
  /// setiap kali dihitung ulang.
  Map<String, int> _largestRemainderRound(
    Map<String, double> exact,
    int target,
  ) {
    final result = <String, int>{};
    final remainders = <MapEntry<String, double>>[];
    var allocated = 0;

    final keys = exact.keys.toList()..sort();
    for (final key in keys) {
      final value = exact[key]!;
      final floored = value.floor();
      result[key] = floored;
      allocated += floored;
      remainders.add(MapEntry(key, value - floored));
    }

    if (remainders.isEmpty) return result;

    var leftover = target - allocated;

    remainders.sort((a, b) {
      final cmp = b.value.compareTo(a.value);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });

    // Kalau leftover negatif (bisa terjadi saat diskon besar), kurangi
    // dari pecahan terkecil.
    if (leftover < 0) {
      final ascending = remainders.reversed.toList();
      var i = 0;
      while (leftover < 0) {
        final key = ascending[i % ascending.length].key;
        result[key] = result[key]! - 1;
        leftover++;
        i++;
      }
      return result;
    }

    for (var i = 0; i < leftover; i++) {
      final key = remainders[i % remainders.length].key;
      result[key] = result[key]! + 1;
    }

    return result;
  }

  /// Menyusun transfer minimal dari saldo tiap orang.
  ///
  /// Saldo positif berarti orang itu menalangi dan berhak menerima uang.
  /// Algoritma greedy: pemberi utang terbesar dipertemukan dengan penerima
  /// terbesar sampai semua saldo nol.
  List<Settlement> _settle({
    required List<PersonShare> shares,
    required Map<String, int> payments,
  }) {
    if (payments.isEmpty) return const [];

    final balances = <String, int>{};
    for (final share in shares) {
      balances[share.personId] = (payments[share.personId] ?? 0) - share.total;
    }
    // Orang yang ikut bayar tapi tidak makan apa pun tetap dihitung.
    for (final entry in payments.entries) {
      balances.putIfAbsent(entry.key, () => entry.value);
    }

    final creditors = <MapEntry<String, int>>[];
    final debtors = <MapEntry<String, int>>[];
    final keys = balances.keys.toList()..sort();
    for (final key in keys) {
      final balance = balances[key]!;
      if (balance > 0) creditors.add(MapEntry(key, balance));
      if (balance < 0) debtors.add(MapEntry(key, -balance));
    }

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final settlements = <Settlement>[];
    var i = 0;
    var j = 0;
    var creditLeft = creditors.isEmpty ? 0 : creditors.first.value;
    var debtLeft = debtors.isEmpty ? 0 : debtors.first.value;

    while (i < creditors.length && j < debtors.length) {
      final amount = math.min(creditLeft, debtLeft);
      if (amount > 0) {
        settlements.add(
          Settlement(
            fromPersonId: debtors[j].key,
            toPersonId: creditors[i].key,
            amount: amount,
          ),
        );
      }
      creditLeft -= amount;
      debtLeft -= amount;

      if (creditLeft == 0) {
        i++;
        if (i < creditors.length) creditLeft = creditors[i].value;
      }
      if (debtLeft == 0) {
        j++;
        if (j < debtors.length) debtLeft = debtors[j].value;
      }
    }

    return settlements;
  }
}
