/// Daftar tagihan tetap bulanan: kos, internet, cicilan, iuran.
///
/// Urutannya mengikuti tanggal jatuh tempo, karena pertanyaan yang dibawa
/// ke layar ini hampir selalu "apa yang harus dibayar berikutnya".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/fixed_bill_repository.dart';
import 'package:chacing/domain/bill_schedule.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/widgets/amount_keypad.dart';
import 'package:chacing/ui/widgets/category_picker.dart';
import 'package:chacing/ui/widgets/pay_bill_sheet.dart';

class FixedBillsScreen extends ConsumerWidget {
  const FixedBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(fixedBillsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan tetap')),
      body: bills.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
        data: (rows) {
          if (rows.isEmpty) return const _EmptyState();

          final monthly = rows.fold<int>(0, (sum, v) => sum + v.bill.amount);
          final unpaid = rows
              .where((v) => !v.schedule(now: now).isPaidThisMonth)
              .fold<int>(0, (sum, v) => sum + v.bill.amount);

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _MonthSummary(monthly: monthly, unpaid: unpaid),
              const Divider(height: 1),
              for (final view in rows)
                _BillTile(
                  view: view,
                  now: now,
                  onTap: () => openBillForm(context, ref, existing: view.bill),
                  onPay: () => openPayBill(context, ref, view),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openBillForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tagihan'),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.monthly, required this.unpaid});

  final int monthly;
  final int unpaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _Figure(label: 'Per bulan', value: formatRupiah(monthly)),
          ),
          Expanded(
            child: _Figure(
              label: 'Belum dibayar bulan ini',
              value: formatRupiah(unpaid),
              color: unpaid == 0 ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.view,
    required this.now,
    required this.onTap,
    required this.onPay,
  });

  final FixedBillView view;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = view.schedule(now: now);
    final status = schedule.status;

    final statusColor = switch (status) {
      BillStatus.overdue => theme.colorScheme.error,
      BillStatus.dueToday || BillStatus.dueSoon => theme.colorScheme.tertiary,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          '${schedule.dueDate.day}',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(view.bill.name),
      subtitle: Text(
        '${formatRupiah(view.bill.amount)} · ${schedule.label}',
        style: TextStyle(color: statusColor),
      ),
      trailing: status == BillStatus.paid
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : FilledButton.tonal(onPressed: onPay, child: const Text('Bayar')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_repeat,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Belum ada tagihan tetap', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Kos, internet, cicilan, iuran — yang dibayar tiap bulan. '
              'Chacing akan mengingatkan saat jatuh tempo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- formulir

/// Membuka formulir tagihan baru, atau menyunting [existing].
Future<void> openBillForm(
  BuildContext context,
  WidgetRef ref, {
  FixedBill? existing,
}) async {
  final wallets = ref.read(walletsProvider).value ?? const <Wallet>[];
  final categories = ref.read(categoriesProvider).value ?? const <Category>[];
  final repository = ref.read(fixedBillRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  final result = await showModalBottomSheet<_BillFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _BillForm(existing: existing, wallets: wallets, categories: categories),
  );
  if (result == null) return;

  if (result.delete) {
    await repository.softDelete(existing!.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${existing.name} dihapus dari daftar')),
    );
    return;
  }

  await repository.save(
    id: existing?.id,
    name: result.name,
    amount: result.amount,
    dueDay: result.dueDay,
    walletId: result.walletId,
    categoryId: result.categoryId,
    countInBudget: result.countInBudget,
  );
}

class _BillFormResult {
  const _BillFormResult({
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.walletId,
    required this.categoryId,
    required this.countInBudget,
  }) : delete = false;

  const _BillFormResult.delete()
    : name = '',
      amount = 0,
      dueDay = 1,
      walletId = null,
      categoryId = null,
      countInBudget = false,
      delete = true;

  final String name;
  final int amount;
  final int dueDay;
  final String? walletId;
  final String? categoryId;
  final bool countInBudget;
  final bool delete;
}

class _BillForm extends StatefulWidget {
  const _BillForm({
    required this.existing,
    required this.wallets,
    required this.categories,
  });

  final FixedBill? existing;
  final List<Wallet> wallets;
  final List<Category> categories;

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  final _nameController = TextEditingController();
  int _amount = 0;
  int _dueDay = DateTime.now().day;
  String? _walletId;
  String? _categoryId;
  bool _countInBudget = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _amount = existing.amount;
      _dueDay = existing.dueDay;
      _walletId = existing.walletId;
      _categoryId = existing.categoryId;
      _countInBudget = existing.countInBudget;
    }
    if (_walletId == null && widget.wallets.isNotEmpty) {
      _walletId = widget.wallets.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _amount > 0 && _nameController.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      _BillFormResult(
        name: _nameController.text,
        amount: _amount,
        dueDay: _dueDay,
        walletId: _walletId,
        categoryId: _categoryId,
        countInBudget: _countInBudget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Ubah tagihan' : 'Tagihan baru',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (isEditing)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(const _BillFormResult.delete()),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nama tagihan',
                  hintText: 'Kos, WiFi, cicilan motor',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatRupiah(_amount),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _amount == 0
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.25,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Daftar tanggal biasa, bukan kalender: yang dipilih
                  // adalah "tanggal berapa tiap bulan", bukan satu hari.
                  DropdownButton<int>(
                    value: _dueDay,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var day = 1; day <= 31; day++)
                        DropdownMenuItem(
                          value: day,
                          child: Text('Tiap tgl $day'),
                        ),
                    ],
                    onChanged: (day) {
                      if (day != null) setState(() => _dueDay = day);
                    },
                  ),
                ],
              ),
            ),
            if (_dueDay > 28)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Di bulan yang lebih pendek, jatuh tempo di hari terakhirnya.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              CategoryPicker(
                categories: widget.categories,
                selectedId: _categoryId,
                onSelected: (id) => setState(() => _categoryId = id),
              ),
            ],
            if (widget.wallets.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
            SwitchListTile(
              value: _countInBudget,
              onChanged: (value) => setState(() => _countInBudget = value),
              title: const Text('Hitung ke budget'),
              subtitle: Text(
                _countInBudget
                    ? 'Pembayarannya mengurangi sisa budget.'
                    : 'Dibayar dari luar budget, seperti sewa kos.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AmountKeypad(
                amount: _amount,
                onChanged: (value) => setState(() => _amount = value),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _canSave ? _save : null,
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Simpan tagihan',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
