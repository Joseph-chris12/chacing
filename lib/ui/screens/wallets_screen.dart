/// Mengelola dompet: tunai, e-wallet, rekening bank, kartu kredit.
///
/// Dompet tidak pernah dihapus, hanya diarsipkan. Transaksi lama menunjuk
/// ke sini dan harus tetap bisa menampilkan namanya — dompet yang hilang
/// akan membuat riwayat belanja kehilangan konteks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/category_icons.dart';

/// Nama jenis dompet dalam bahasa Indonesia.
const _walletTypeNames = <WalletType, String>{
  WalletType.cash: 'Tunai',
  WalletType.ewallet: 'E-wallet',
  WalletType.bank: 'Rekening bank',
  WalletType.credit: 'Kartu kredit',
};

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      body: wallets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final wallet = rows[index];
            return ListTile(
              leading: CircleAvatar(
                child: Icon(walletIcon(wallet.type.name), size: 20),
              ),
              title: Text(wallet.name),
              subtitle: Text(_walletTypeNames[wallet.type] ?? wallet.type.name),
              trailing: rows.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      tooltip: 'Arsipkan',
                      onPressed: () => _archive(context, ref, wallet),
                    )
                  // Dompet terakhir tidak boleh diarsipkan: tanpa satu pun
                  // dompet, layar input tidak bisa menyimpan apa-apa.
                  : null,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWallet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(walletRepositoryProvider).archive(wallet.id);

    messenger.showSnackBar(
      SnackBar(content: Text('${wallet.name} diarsipkan')),
    );
  }

  Future<void> _addWallet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({String name, WalletType type})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _WalletForm(),
    );
    if (result == null) return;

    await ref.read(walletRepositoryProvider).create(
          name: result.name,
          type: result.type,
        );
  }
}

/// Formulir dompet baru.
///
/// Dibuat sebagai bottom sheet, bukan layar penuh: isinya cuma dua isian
/// dan pengguna sedang di tengah pekerjaan lain.
class _WalletForm extends StatefulWidget {
  const _WalletForm();

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  final _controller = TextEditingController();
  WalletType _type = WalletType.ewallet;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        // Menyisihkan tinggi keyboard supaya isian tidak tertutup.
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dompet baru', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama',
              hintText: 'GoPay, BCA, Dana',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _walletTypeNames.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _type == entry.key,
                  onSelected: (_) => setState(() => _type = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}
