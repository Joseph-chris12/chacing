/// Lembar bayar tagihan tetap.
///
/// Nominalnya sudah terisi dari tagihan, jadi untuk kos atau internet
/// cukup satu ketukan "Bayar". Papan angkanya tetap ada untuk tagihan
/// yang tiap bulan berubah, seperti listrik atau air.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/fixed_bill_repository.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/widgets/amount_keypad.dart';

/// Membuka lembar bayar untuk [view], lalu mencatat pembayarannya.
Future<void> openPayBill(
  BuildContext context,
  WidgetRef ref,
  FixedBillView view,
) async {
  final wallets = ref.read(walletsProvider).value ?? const <Wallet>[];
  if (wallets.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  final result = await showModalBottomSheet<({int amount, String walletId})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PayBillForm(bill: view.bill, wallets: wallets),
  );
  if (result == null) return;

  final transactionId = await ref
      .read(fixedBillRepositoryProvider)
      .recordPayment(
        billId: view.bill.id,
        amount: result.amount,
        walletId: result.walletId,
      );

  messenger.showSnackBar(
    SnackBar(
      content: Text('${view.bill.name} dibayar ${formatRupiah(result.amount)}'),
      // Membatalkan cukup menghapus transaksinya — tagihan otomatis kembali
      // muncul sebagai belum dibayar karena pembayarannya tidak ada lagi.
      action: SnackBarAction(
        label: 'Batalkan',
        onPressed: () =>
            ref.read(transactionRepositoryProvider).softDelete(transactionId),
      ),
    ),
  );
}

class _PayBillForm extends StatefulWidget {
  const _PayBillForm({required this.bill, required this.wallets});

  final FixedBill bill;
  final List<Wallet> wallets;

  @override
  State<_PayBillForm> createState() => _PayBillFormState();
}

class _PayBillFormState extends State<_PayBillForm> {
  late int _amount = widget.bill.amount;
  late String _walletId =
      widget.wallets.any((w) => w.id == widget.bill.walletId)
      ? widget.bill.walletId!
      : widget.wallets.first.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changed = _amount != widget.bill.amount;

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
              'Bayar ${widget.bill.name}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.bill.countInBudget
                  ? 'Dihitung sebagai pengeluaran budget.'
                  : 'Tidak mengurangi budget.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(_amount),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Papan angka menambah digit di belakang, jadi mengetik di atas
            // nominal yang sudah terisi menghasilkan angka aneh. Petunjuk ini
            // hilang begitu nominalnya diubah.
            Text(
              changed
                  ? 'Biasanya ${formatRupiah(widget.bill.amount)}'
                  : 'Nominal beda bulan ini? Tahan tombol hapus untuk '
                        'mengosongkan, lalu ketik ulang.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.wallets.length > 1) ...[
              const SizedBox(height: 12),
              Text('Dari dompet', style: theme.textTheme.labelMedium),
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
                onPressed: _amount > 0
                    ? () =>
                          Navigator.of(context)
                              .pop((amount: _amount, walletId: _walletId))
                    : null,
                icon: const Icon(Icons.check),
                label: Text(
                  'Bayar ${formatRupiah(_amount)}',
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
