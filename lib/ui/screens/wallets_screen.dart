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
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/widgets/amount_keypad.dart';

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
    final balances = ref.watch(walletBalancesProvider).value ?? const {};
    final canTransfer = (wallets.value?.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet'),
        actions: [
          if (canTransfer)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Pindah dana',
              onPressed: () => _transfer(context, ref, wallets.value!),
            ),
        ],
      ),
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
              subtitle: Text(
                '${_walletTypeNames[wallet.type] ?? wallet.type.name}'
                ' · ${formatRupiah(balances[wallet.id] ?? 0)}',
              ),
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

  /// Memindahkan uang antar dompet sendiri.
  ///
  /// Dicatat sebagai sepasang transaksi yang dikecualikan dari budget.
  /// Memindahkan uang bukan pengeluaran — menghitungnya sebagai
  /// pengeluaran akan menggandakan angkanya saat uang itu benar-benar
  /// dibelanjakan nanti.
  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    List<Wallet> wallets,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<_TransferRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransferForm(wallets: wallets),
    );
    if (result == null) return;

    await ref.read(transactionRepositoryProvider).transfer(
          fromWalletId: result.fromId,
          toWalletId: result.toId,
          amount: result.amount,
        );

    messenger.showSnackBar(
      SnackBar(content: Text('${formatRupiah(result.amount)} dipindahkan')),
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

/// Permintaan pindah dana dari formulir ke pemanggilnya.
class _TransferRequest {
  const _TransferRequest({
    required this.fromId,
    required this.toId,
    required this.amount,
  });

  final String fromId;
  final String toId;
  final int amount;
}

class _TransferForm extends StatefulWidget {
  const _TransferForm({required this.wallets});

  final List<Wallet> wallets;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  late String _fromId = widget.wallets.first.id;
  late String _toId = widget.wallets[1].id;
  int _amount = 0;

  bool get _canSubmit => _amount > 0 && _fromId != _toId;

  /// Menukar asal dan tujuan.
  ///
  /// Memilih dompet yang sama di kedua sisi lebih sering berarti "aku
  /// salah pilih arah" daripada benar-benar ingin dua-duanya sama, jadi
  /// sisi lawannya yang digeser, bukan pilihan yang baru saja ditekan.
  void _setFrom(String id) {
    setState(() {
      if (id == _toId) _toId = _fromId;
      _fromId = id;
    });
  }

  void _setTo(String id) {
    setState(() {
      if (id == _fromId) _fromId = _toId;
      _toId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pindah dana', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tidak dihitung sebagai pengeluaran.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(formatRupiah(_amount), style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          _WalletRow(
            label: 'Dari',
            wallets: widget.wallets,
            selectedId: _fromId,
            onSelected: _setFrom,
          ),
          const SizedBox(height: 8),
          _WalletRow(
            label: 'Ke',
            wallets: widget.wallets,
            selectedId: _toId,
            onSelected: _setTo,
          ),
          const SizedBox(height: 12),
          AmountKeypad(
            amount: _amount,
            onChanged: (value) => setState(() => _amount = value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _canSubmit
                  ? () => Navigator.of(context).pop(
                        _TransferRequest(
                          fromId: _fromId,
                          toId: _toId,
                          amount: _amount,
                        ),
                      )
                  : null,
              child: const Text('Pindahkan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.label,
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
  });

  final String label;
  final List<Wallet> wallets;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final wallet in wallets) ...[
                  ChoiceChip(
                    label: Text(wallet.name),
                    selected: wallet.id == selectedId,
                    onSelected: (_) => onSelected(wallet.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
