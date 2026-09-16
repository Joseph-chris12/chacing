/// Pengingat tagihan tetap di beranda.
///
/// Hanya muncul kalau ada tagihan yang lewat, jatuh tempo hari ini, atau
/// jatuh tempo dalam tiga hari — dan belum dibayar. Di hari-hari lain
/// kartu ini tidak ada sama sekali, supaya beranda tidak terbiasa diabaikan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/domain/bill_schedule.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/screens/fixed_bills_screen.dart';
import 'package:chacing/ui/widgets/pay_bill_sheet.dart';

class DueBillsCard extends ConsumerWidget {
  const DueBillsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsNeedingAttentionProvider);
    if (bills.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FixedBillsScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_repeat,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tagihan yang perlu dibayar',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            for (final view in bills)
              Builder(
                builder: (context) {
                  final schedule = view.schedule(now: now);
                  final overdue = schedule.status == BillStatus.overdue;

                  return ListTile(
                    dense: true,
                    title: Text(view.bill.name),
                    subtitle: Text(
                      '${formatRupiah(view.bill.amount)} · ${schedule.label}',
                      style: TextStyle(
                        color: overdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => openPayBill(context, ref, view),
                      child: const Text('Bayar'),
                    ),
                  );
                },
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
