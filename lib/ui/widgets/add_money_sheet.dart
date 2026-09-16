/// Lembar "Tambah uang": gaji, uang saku, kiriman, bonus.
///
/// Dibuat sebagai bottom sheet seperti pindah dana, bukan layar penuh.
/// Isiannya cuma tiga — berapa, dari mana, masuk ke dompet mana — dan
/// biasanya diisi sekali di awal bulan, bukan sepuluh kali sehari seperti
/// layar catat pengeluaran.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/theme.dart';
import 'package:chacing/ui/widgets/amount_keypad.dart';

/// Sumber pemasukan yang paling sering, supaya jarang perlu mengetik.
const _quickSources = ['Gaji', 'Uang saku', 'Kiriman', 'Bonus', 'Jualan'];

/// Membuka lembar tambah uang, lalu menyimpan hasilnya.
///
/// Memberikan [existing] berarti menyunting pemasukan yang sudah ada.
Future<void> openAddMoney(
  BuildContext context,
  WidgetRef ref, {
  Transaction? existing,
}) async {
  final wallets = ref.read(walletsProvider).value ?? const <Wallet>[];
  if (wallets.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  final result = await showModalBottomSheet<_IncomeRequest>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddMoneyForm(wallets: wallets, existing: existing),
  );
  if (result == null) return;

  await ref
      .read(transactionRepositoryProvider)
      .recordIncome(
        id: existing?.id,
        walletId: result.walletId,
        amount: result.amount,
        name: result.name,
        occurredAt: existing?.occurredAt,
        note: existing?.note,
      );

  final walletName = wallets.firstWhere((w) => w.id == result.walletId).name;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        existing == null
            ? '${formatRupiah(result.amount)} masuk ke $walletName'
            : 'Perubahan tersimpan',
      ),
    ),
  );
}

class _IncomeRequest {
  const _IncomeRequest({
    required this.walletId,
    required this.amount,
    required this.name,
  });

  final String walletId;
  final int amount;
  final String name;
}

class _AddMoneyForm extends StatefulWidget {
  const _AddMoneyForm({required this.wallets, this.existing});

  final List<Wallet> wallets;
  final Transaction? existing;

  @override
  State<_AddMoneyForm> createState() => _AddMoneyFormState();
}

class _AddMoneyFormState extends State<_AddMoneyForm> {
  final _nameController = TextEditingController();
  late String _walletId;
  int _amount = 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    // Nominal pemasukan tersimpan negatif. Di layar, uang selalu positif.
    _amount = existing == null ? 0 : -existing.total;
    _nameController.text = existing?.merchant ?? '';

    final knownWallet = widget.wallets.any((w) => w.id == existing?.walletId);
    _walletId = knownWallet ? existing!.walletId : widget.wallets.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _amount > 0;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      _IncomeRequest(
        walletId: _walletId,
        amount: _amount,
        name: _nameController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inColor = moneyInColor(theme.brightness);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Tambah uang' : 'Ubah uang masuk',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Menambah saldo dompet. Budget tidak berubah.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '+${formatRupiah(_amount)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _amount == 0
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                      : inColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Dari mana? (boleh dikosongkan)',
                prefixIcon: Icon(Icons.savings_outlined),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final source in _quickSources) ...[
                    ActionChip(
                      label: Text(source),
                      onPressed: () =>
                          setState(() => _nameController.text = source),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            if (widget.wallets.length > 1) ...[
              const SizedBox(height: 8),
              Text('Masuk ke', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final wallet in widget.wallets) ...[
                      ChoiceChip(
                        label: Text(wallet.name),
                        selected: wallet.id == _walletId,
                        onSelected: (_) =>
                            setState(() => _walletId = wallet.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AmountKeypad(
              amount: _amount,
              onChanged: (value) => setState(() => _amount = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.existing == null ? 'Tambahkan' : 'Simpan',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
