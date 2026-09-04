/// Ringkasan budget di beranda.
///
/// Angka yang paling besar di layar adalah **sisa**, bukan yang sudah
/// terpakai. Yang ingin diketahui orang saat membuka aplikasi keuangan
/// bukan "aku sudah habis berapa" melainkan "aku masih boleh pakai berapa".
///
/// Nada tulisannya mengikuti aturan proyek: membantu, tidak menghakimi.
/// Tidak ada "Kamu boros!" di mana pun. Saat budget jebol pun kalimatnya
/// menyampaikan keadaan, bukan menyalahkan.
library;

import 'package:flutter/material.dart';

import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/ui/format.dart';

class BudgetSummary extends StatelessWidget {
  const BudgetSummary({
    super.key,
    required this.status,
    required this.onTap,
  });

  final BudgetStatus status;

  /// Membuka layar pengaturan budget.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!status.hasBudget) {
      return _NoBudgetCard(status: status, onTap: onTap);
    }

    final color = _paceColor(theme, status.pace);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sisa ${status.range.kind.thisPeriod}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(status.remaining.abs()),
                maxLines: 1,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: status.isOverBudget ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: status.usedRatio.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _paceMessage(status),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              '${formatRupiah(status.spent)} terpakai '
              'dari ${formatRupiah(status.available)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBudgetCard extends StatelessWidget {
  const _NoBudgetCard({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terpakai ${status.range.kind.thisPeriod}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(status.spent),
                maxLines: 1,
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onTap,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Atur batas pengeluaran'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _paceColor(ThemeData theme, BudgetPace pace) {
  switch (pace) {
    case BudgetPace.exceeded:
      return theme.colorScheme.error;
    case BudgetPace.tooFast:
      return theme.colorScheme.tertiary;
    case BudgetPace.comfortable:
    case BudgetPace.onTrack:
    case BudgetPace.notSet:
      return theme.colorScheme.primary;
  }
}

/// Kalimat status.
///
/// Selalu menyebut angka dan sisa waktu, karena itu yang bisa
/// ditindaklanjuti. "Terlalu cepat" saja tidak memberi tahu apa pun
/// tentang apa yang harus dilakukan.
String _paceMessage(BudgetStatus status) {
  final days = status.daysRemaining;
  final sisaWaktu = days <= 0
      ? 'Periode ini sudah selesai.'
      : days == 1
          ? 'untuk hari ini'
          : 'untuk $days hari';

  switch (status.pace) {
    case BudgetPace.notSet:
      return 'Belum ada batas pengeluaran.';

    case BudgetPace.exceeded:
      return 'Lewat ${formatRupiah(status.spent - status.available)} '
          'dari batas. Periode berikutnya mulai dari nol lagi.';

    case BudgetPace.tooFast:
      if (days <= 0) return 'Periode ini sudah selesai.';
      return 'Agak cepat. Sisanya ${formatRupiah(status.safeToSpendToday)} '
          'per hari $sisaWaktu.';

    case BudgetPace.comfortable:
      if (days <= 0) return 'Periode ini sudah selesai.';
      return 'Santai. Aman dipakai ${formatRupiah(status.safeToSpendToday)} '
          'hari ini.';

    case BudgetPace.onTrack:
      if (days <= 0) return 'Periode ini sudah selesai.';
      return 'Sesuai rencana. Aman dipakai '
          '${formatRupiah(status.safeToSpendToday)} hari ini.';
  }
}
