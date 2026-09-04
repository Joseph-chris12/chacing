/// Layar pengaturan budget: berapa, dan untuk rentang berapa lama.
///
/// Tiga pilihan periode, bukan satu yang dipaksakan, karena cara orang
/// memegang uang berbeda-beda. Yang gajian bulanan berpikir per bulan.
/// Yang uangnya pas-pasan berpikir per hari. Memaksa semuanya ke mingguan
/// membuat angkanya harus dihitung ulang di kepala tiap kali dilihat —
/// dan begitu itu terjadi, aplikasinya berhenti dipakai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/domain/budget_period.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/widgets/amount_keypad.dart';

class BudgetSettingsScreen extends ConsumerStatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  ConsumerState<BudgetSettingsScreen> createState() =>
      _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen> {
  PeriodKind _period = PeriodKind.week;
  int _amount = 0;
  bool _rollover = false;
  bool _saving = false;
  bool _loadedExisting = false;

  bool get _canSave => _amount > 0 && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(budgetRepositoryProvider).save(
            period: _period,
            amount: _amount,
            rollover: _rollover,
          );
      if (mounted) navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan budget: $error')),
      );
    }
  }

  Future<void> _disable() async {
    final navigator = Navigator.of(context);
    await ref.read(budgetRepositoryProvider).disable();
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = ref.watch(activeBudgetProvider).value;

    // Isi sekali dari budget yang sudah ada, lalu biarkan pengguna yang
    // pegang kendali. Menyetel ulang tiap build akan membatalkan ketikan
    // begitu stream mengirim nilai baru.
    if (!_loadedExisting && existing != null) {
      _loadedExisting = true;
      _period = existing.period;
      _amount = existing.amount;
      _rollover = existing.rollover;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur budget'),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: _saving ? null : _disable,
              child: const Text('Matikan'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Batas pengeluaran',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<PeriodKind>(
                        segments: [
                          for (final kind in PeriodKind.values)
                            ButtonSegment(
                              value: kind,
                              label: Text(kind.label),
                            ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (selection) =>
                            setState(() => _period = selection.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatRupiah(_amount),
                          maxLines: 1,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _amount == 0
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.25)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'per ${_period.unit}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (_amount > 0) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _PaceHint(period: _period, amount: _amount),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _rollover,
                      onChanged: (value) => setState(() => _rollover = value),
                      title: const Text('Bawa sisa ke periode berikutnya'),
                      subtitle: Text(
                        _rollover
                            ? 'Sisa ${_period.thisPeriod} menambah jatah '
                                'periode berikutnya.'
                            : 'Setiap periode mulai dari angka yang sama.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: AmountKeypad(
                amount: _amount,
                onChanged: (value) => setState(() => _amount = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _canSave ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _saving ? 'Menyimpan…' : 'Simpan budget',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menerjemahkan budget ke angka harian supaya pilihannya terasa nyata.
///
/// "Rp 3.000.000 sebulan" sulit dinilai. "Sekitar Rp 100.000 per hari"
/// langsung bisa dibandingkan dengan kebiasaan sendiri.
class _PaceHint extends StatelessWidget {
  const _PaceHint({required this.period, required this.amount});

  final PeriodKind period;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calculator = const BudgetPeriodCalculator();
    final range = calculator.periodContaining(DateTime.now(), period);
    final perDay = range.totalDays == 0 ? amount : amount ~/ range.totalDays;

    if (period == PeriodKind.day) {
      return Text(
        'Kira-kira ${formatRupiah(amount * 30)} sebulan.',
        style: theme.textTheme.bodySmall,
      );
    }

    return Text(
      'Kira-kira ${formatRupiah(perDay)} per hari.',
      style: theme.textTheme.bodySmall,
    );
  }
}
