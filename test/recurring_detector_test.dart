import 'package:flutter_test/flutter_test.dart';

import 'package:chacing/domain/recurring_detector.dart';

const detector = RecurringDetector();

/// Membuat deretan tagihan berulang dengan jarak [everyDays].
List<RecurringInput> series({
  required String merchant,
  required int amount,
  required int count,
  int everyDays = 30,
  DateTime? from,
  List<int> amountOverrides = const [],
  List<int> dayJitter = const [],
}) {
  final start = from ?? DateTime(2026, 1, 5);
  return [
    for (var i = 0; i < count; i++)
      RecurringInput(
        merchant: merchant,
        amount: i < amountOverrides.length ? amountOverrides[i] : amount,
        occurredAt: DateTime(
          start.year,
          start.month,
          start.day + i * everyDays + (i < dayJitter.length ? dayJitter[i] : 0),
        ),
      ),
  ];
}

void main() {
  group('mengenali langganan', () {
    test('tagihan bulanan dengan nominal sama terdeteksi', () {
      final found = detector.detect(
        series(merchant: 'Spotify', amount: 54990, count: 4),
      );

      expect(found.length, 1);
      expect(found.single.merchant, 'Spotify');
      expect(found.single.typicalAmount, 54990);
      expect(found.single.cadence, RecurringCadence.monthly);
      expect(found.single.occurrences, 4);
    });

    test('tagihan mingguan dikenali sebagai mingguan', () {
      final found = detector.detect(
        series(merchant: 'Laundry', amount: 35000, count: 5, everyDays: 7),
      );

      expect(found.single.cadence, RecurringCadence.weekly);
    });

    test('selisih beberapa hari masih dianggap satu irama', () {
      // Tanggal tagihan jarang persis sama tiap bulan.
      final found = detector.detect(
        series(
          merchant: 'Netflix',
          amount: 65000,
          count: 4,
          dayJitter: [0, 2, -1, 3],
        ),
      );

      expect(found.length, 1);
    });

    test('nominal memakai nilai tengah, bukan rata-rata', () {
      // Satu bulan kena denda; angkanya tidak boleh menggeser nilai wakil.
      final found = detector.detect(
        series(
          merchant: 'Internet',
          amount: 300000,
          count: 5,
          amountOverrides: [300000, 300000, 320000, 300000, 300000],
        ),
      );

      expect(found.single.typicalAmount, 300000);
    });
  });

  group('menolak yang bukan langganan', () {
    test('dua kali belum cukup untuk disebut pola', () {
      final found = detector.detect(
        series(merchant: 'Servis motor', amount: 150000, count: 2),
      );

      expect(found, isEmpty);
    });

    test('nominal yang berubah-ubah bukan langganan', () {
      // Belanja mingguan di minimarket yang sama, angkanya beda-beda.
      final found = detector.detect(
        series(
          merchant: 'Indomaret',
          amount: 50000,
          count: 5,
          everyDays: 7,
          amountOverrides: [32000, 78000, 51000, 95000, 40000],
        ),
      );

      expect(found, isEmpty);
    });

    test('jarak yang tidak teratur bukan langganan', () {
      final entries = [
        RecurringInput(
          merchant: 'Bengkel',
          amount: 200000,
          occurredAt: DateTime(2026, 1, 5),
        ),
        RecurringInput(
          merchant: 'Bengkel',
          amount: 200000,
          occurredAt: DateTime(2026, 1, 9),
        ),
        RecurringInput(
          merchant: 'Bengkel',
          amount: 200000,
          occurredAt: DateTime(2026, 6, 20),
        ),
      ];

      expect(detector.detect(entries), isEmpty);
    });

    test('nominal nol atau minus diabaikan', () {
      // Pindah dana tercatat sebagai nominal negatif dan tidak boleh
      // ikut terbaca sebagai langganan.
      final found = detector.detect(
        series(merchant: 'Pindah ke GoPay', amount: -200000, count: 5),
      );

      expect(found, isEmpty);
    });
  });

  group('menakar biayanya', () {
    test('biaya setahun dihitung dari iramanya', () {
      final monthly = detector
          .detect(series(merchant: 'Spotify', amount: 54990, count: 4))
          .single;
      expect(monthly.yearlyCost, 54990 * 12);

      final weekly = detector
          .detect(
            series(merchant: 'Laundry', amount: 35000, count: 5, everyDays: 7),
          )
          .single;
      expect(weekly.yearlyCost, 35000 * 52);
    });

    test('tagihan berikutnya diperkirakan dari yang terakhir', () {
      final found = detector
          .detect(
            series(
              merchant: 'Spotify',
              amount: 54990,
              count: 3,
              from: DateTime(2026, 1, 5),
            ),
          )
          .single;

      expect(found.lastSeen, DateTime(2026, 3, 6));
      expect(found.nextExpected, DateTime(2026, 4, 5));
    });

    test('yang paling mahal setahun muncul lebih dulu', () {
      final found = detector.detect([
        ...series(merchant: 'Spotify', amount: 54990, count: 4),
        ...series(merchant: 'Internet', amount: 350000, count: 4),
      ]);

      expect(found.map((c) => c.merchant), ['Internet', 'Spotify']);
    });

    test('nama tempat disamakan tanpa memandang huruf besar kecil', () {
      final found = detector.detect([
        ...series(merchant: 'spotify', amount: 54990, count: 2),
        ...series(
          merchant: 'Spotify',
          amount: 54990,
          count: 2,
          from: DateTime(2026, 3, 5),
        ),
      ]);

      expect(found.length, 1);
      expect(found.single.occurrences, 4);
    });
  });
}
