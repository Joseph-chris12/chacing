/// Kerangka utama dengan bilah navigasi di bawah.
///
/// Tiga tujuan pertama adalah tempat, dua berikutnya adalah pekerjaan.
/// Beranda, ringkasan, dan lainnya ditahan hidup di [IndexedStack] supaya
/// posisi guliran dan periode yang sedang dilihat tidak mundur ke awal
/// tiap kali berpindah.
///
/// Scan dan bagi tagihan sengaja tidak jadi tab. Keduanya adalah alur
/// sekali jalan yang berakhir dengan menyimpan lalu menutup diri —
/// menahannya sebagai tab akan meninggalkan draft setengah jadi yang
/// menempel di bilah bawah tanpa pernah selesai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/ui/screens/home_screen.dart';
import 'package:chacing/ui/screens/more_screen.dart';
import 'package:chacing/ui/screens/scan_receipt_screen.dart';
import 'package:chacing/ui/screens/split_bill_screen.dart';
import 'package:chacing/ui/screens/summary_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// Urutan tab yang benar-benar ditahan hidup.
  static const _tabs = [0, 1, 4];

  int _index = 0;

  void _onDestination(int selected) {
    switch (selected) {
      case 2:
        _push(const ScanReceiptScreen());
      case 3:
        _push(const SplitBillScreen());
      default:
        setState(() => _index = selected);
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabs.indexOf(_index),
        children: const [
          HomeScreen(),
          SummaryScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Ringkasan',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Bagi',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}
