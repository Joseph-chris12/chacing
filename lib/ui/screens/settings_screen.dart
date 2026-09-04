/// Pengaturan tampilan.
///
/// Isinya sengaja sedikit. Halaman pengaturan yang panjang biasanya
/// menandakan keputusan yang tidak berani diambil oleh pembuatnya, dan
/// setiap pilihan tambahan adalah satu hal lagi yang harus dipahami
/// pengguna sebelum bisa memakai aplikasinya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/providers.dart';

const _themeLabels = <ThemeMode, ({String title, String subtitle})>{
  ThemeMode.light: (
    title: 'Terang',
    subtitle: 'Putih dan merah muda, seperti logonya.',
  ),
  ThemeMode.dark: (
    title: 'Gelap',
    subtitle: 'Lebih nyaman dipakai malam hari.',
  ),
  ThemeMode.system: (
    title: 'Ikuti sistem',
    subtitle: 'Berganti sendiri mengikuti pengaturan HP.',
  ),
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Mode warna', style: theme.textTheme.titleSmall),
          ),
          // `RadioGroup` menggantikan `groupValue`/`onChanged` per baris
          // yang sudah usang sejak Flutter 3.32.
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                for (final entry in _themeLabels.entries)
                  RadioListTile<ThemeMode>(
                    value: entry.key,
                    title: Text(entry.value.title),
                    subtitle: Text(entry.value.subtitle),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Pilihan ini tersimpan di HP ini saja dan tidak ikut ke '
              'berkas cadangan.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
