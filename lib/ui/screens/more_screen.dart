/// Semua yang tidak muat di bilah bawah.
///
/// Dikelompokkan menurut seberapa sering disentuh, bukan menurut
/// kemiripan teknisnya: yang dibuka tiap minggu di atas, yang dibuka
/// sekali seumur pemasangan di bawah.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/screens/api_key_screen.dart';
import 'package:chacing/ui/screens/backup_screen.dart';
import 'package:chacing/ui/screens/budget_settings_screen.dart';
import 'package:chacing/ui/screens/categories_screen.dart';
import 'package:chacing/ui/screens/people_screen.dart';
import 'package:chacing/ui/screens/search_screen.dart';
import 'package:chacing/ui/screens/settings_screen.dart';
import 'package:chacing/ui/screens/trend_screen.dart';
import 'package:chacing/ui/screens/wallets_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(activeBudgetProvider).value;
    final wallets = ref.watch(walletsProvider).value?.length ?? 0;
    final people = ref.watch(peopleProvider).value?.length ?? 0;
    final hasApiKey = ref.watch(hasApiKeyProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        children: [
          const _GroupLabel('Sehari-hari'),
          _Tile(
            icon: Icons.search,
            title: 'Cari transaksi',
            subtitle: 'Menurut nama tempat, kategori, atau dompet',
            onTap: () => _open(context, const SearchScreen()),
          ),
          _Tile(
            icon: Icons.show_chart,
            title: 'Tren bulanan',
            subtitle: 'Enam bulan terakhir dan dugaan langganan',
            onTap: () => _open(context, const TrendScreen()),
          ),
          const Divider(height: 24),
          const _GroupLabel('Pengaturan uang'),
          _Tile(
            icon: Icons.flag_outlined,
            title: 'Budget',
            subtitle: budget == null
                ? 'Belum ditetapkan'
                : '${formatRupiah(budget.amount)} per '
                    '${budget.period.unit}',
            onTap: () => _open(context, const BudgetSettingsScreen()),
          ),
          _Tile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Dompet',
            subtitle: '$wallets dompet aktif',
            onTap: () => _open(context, const WalletsScreen()),
          ),
          _Tile(
            icon: Icons.label_outline,
            title: 'Kategori',
            onTap: () => _open(context, const CategoriesScreen()),
          ),
          _Tile(
            icon: Icons.people_outline,
            title: 'Orang',
            subtitle: '$people orang untuk bagi tagihan',
            onTap: () => _open(context, const PeopleScreen()),
          ),
          const Divider(height: 24),
          const _GroupLabel('Aplikasi'),
          _Tile(
            icon: Icons.palette_outlined,
            title: 'Tampilan',
            subtitle: _themeLabel(ref.watch(themeModeProvider)),
            onTap: () => _open(context, const SettingsScreen()),
          ),
          _Tile(
            icon: Icons.key_outlined,
            title: 'Kunci pembaca struk',
            subtitle: hasApiKey ? 'Sudah terpasang' : 'Belum dipasang',
            onTap: () => _open(context, const ApiKeyScreen()),
          ),
          _Tile(
            icon: Icons.backup_outlined,
            title: 'Cadangkan & pulihkan',
            subtitle: 'Simpan semuanya ke satu berkas JSON',
            onTap: () => _open(context, const BackupScreen()),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Terang',
        ThemeMode.dark => 'Gelap',
        ThemeMode.system => 'Ikuti sistem',
      };
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
