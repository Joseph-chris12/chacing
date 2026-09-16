/// Kartu saldo di beranda, pengganti kartu budget bagi yang memilihnya.
///
/// Menjawab pertanyaan yang berbeda dari kartu budget. Budget bertanya
/// "masih boleh pakai berapa?"; saldo bertanya "uangku tinggal berapa?".
/// Banyak orang tidak pernah menetapkan budget, dan bagi mereka pertanyaan
/// kedua jauh lebih berguna daripada kartu yang terus mengajak mengatur
/// batas pengeluaran.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/category_icons.dart';
import 'package:chacing/ui/format.dart';

class BalanceSummary extends ConsumerWidget {
  const BalanceSummary({super.key, required this.onTap});

  /// Membuka layar dompet, tempat saldo tiap dompet disetel.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = ref.watch(totalBalanceProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final balances = ref.watch(walletBalancesProvider).value ?? const {};
    final status = ref.watch(budgetStatusProvider);

    final isNegative = total < 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo semua dompet',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(total),
                maxLines: 1,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isNegative ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keluar ${status.range.kind.thisPeriod}: '
              '${formatRupiah(status.spent)}',
              style: theme.textTheme.bodyMedium,
            ),
            // Saldo minus hampir selalu berarti saldo dompetnya belum pernah
            // disetel: dompet baru mulai dari nol, lalu tiap belanja
            // menguranginya. Kalimatnya menunjuk ke perbaikan, bukan menegur.
            if (isNegative) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Samakan dengan isi dompet'),
              ),
            ],
            if (wallets.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final wallet in wallets)
                    _WalletChip(
                      wallet: wallet,
                      balance: balances[wallet.id] ?? 0,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.wallet, required this.balance});

  final Wallet wallet;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            walletIcon(wallet.type.name),
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(wallet.name, style: theme.textTheme.labelMedium),
          const SizedBox(width: 6),
          Text(
            formatRupiah(balance),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: balance < 0 ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
