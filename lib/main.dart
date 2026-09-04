/// Titik masuk aplikasi.
///
/// Isinya hanya kerangka: memuat data locale, menyalakan Riverpod, dan
/// menunggu seeding selesai sebelum layar pertama digambar. Semua isi
/// layar tinggal di `ui/screens/`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:chacing/data/seed.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tanpa ini, `DateFormat` dengan locale 'id_ID' melempar error saat
  // dipanggil pertama kali — data nama bulan belum dimuat.
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  runApp(const ProviderScope(child: ChacingApp()));
}

/// Seeding dijalankan sekali saat aplikasi dibuka.
final appInitProvider = FutureProvider<void>((ref) async {
  await DatabaseSeeder(ref.watch(databaseProvider)).run();
});

class ChacingApp extends StatelessWidget {
  const ChacingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chacing',
      debugShowCheckedModeBanner: false,
      // Mode gelap mengikuti sistem — gratis, tidak perlu layar pengaturan.
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF10B981),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF10B981),
        brightness: Brightness.dark,
      ),
      home: const _Boot(),
    );
  }
}

/// Menahan layar sampai kategori dan dompet bawaan siap.
///
/// Tanpa gerbang ini, layar input bisa terbuka dengan daftar kategori
/// kosong dan tanpa dompet — dan tombol simpannya mati tanpa penjelasan.
class _Boot extends ConsumerWidget {
  const _Boot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(appInitProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Database gagal dibuka.'),
                  const SizedBox(height: 12),
                  Text(
                    '$error',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          data: (_) => const HomeScreen(),
        );
  }
}
