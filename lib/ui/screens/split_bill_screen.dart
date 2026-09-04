/// Bagi tagihan: menghitung porsi tiap orang, bukan sekadar bagi rata.
///
/// Inti fiturnya ada pada penugasan per item. Kalau tagihan dibagi rata,
/// orang yang cuma minum es teh ikut menanggung steak orang lain — dan
/// itulah yang membuat patungan terasa tidak adil. Di sini tiap item
/// ditugaskan ke siapa yang benar-benar menikmatinya, lalu pajak dan
/// service dialokasikan proporsional terhadap porsi masing-masing.
///
/// Hitungannya sendiri tidak tinggal di sini. Semua rumus ada di
/// [SplitCalculator] yang sudah punya tes sendiri; layar ini hanya
/// menyusun masukannya dan menampilkan hasilnya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/domain/split_calculator.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';

/// Satu baris tagihan yang sedang disusun, beserta siapa yang menikmatinya.
class _ItemDraft {
  _ItemDraft({
    required this.id,
    required this.name,
    required this.amount,
    Set<String>? personIds,
  }) : personIds = personIds ?? <String>{};

  final String id;
  String name;
  int amount;
  final Set<String> personIds;
}

class SplitBillScreen extends ConsumerStatefulWidget {
  const SplitBillScreen({super.key});

  @override
  ConsumerState<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends ConsumerState<SplitBillScreen> {
  final _merchantController = TextEditingController();
  final List<_ItemDraft> _items = [];

  int _tax = 0;
  int _serviceCharge = 0;
  int _discount = 0;
  String? _payerId;
  String? _walletId;
  String? _categoryId;
  final DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _merchantController.dispose();
    super.dispose();
  }

  int get _itemsSubtotal =>
      _items.fold<int>(0, (sum, item) => sum + item.amount);

  int get _billTotal => _itemsSubtotal + _tax + _serviceCharge - _discount;

  bool get _canSave =>
      _items.isNotEmpty &&
      _items.any((item) => item.personIds.isNotEmpty) &&
      _walletId != null &&
      !_saving;

  /// Menyusun masukan untuk mesin split dari isian di layar.
  ({List<LineItem> items, List<Assignment> assignments}) _splitInput() {
    final items = <LineItem>[];
    final assignments = <Assignment>[];

    for (final draft in _items) {
      items.add(
        LineItem(
          id: draft.id,
          name: draft.name,
          quantity: 1,
          unitPrice: draft.amount,
        ),
      );
      for (final personId in draft.personIds) {
        // Bobot dibiarkan 1: dalam satu item, semua yang ditugaskan
        // dianggap menikmati sama rata. Ketidakrataan yang sebenarnya
        // sudah terwakili oleh item mana ditugaskan ke siapa.
        assignments.add(
          Assignment(lineItemId: draft.id, personId: personId),
        );
      }
    }

    return (items: items, assignments: assignments);
  }

  SplitResult? get _result {
    if (_items.isEmpty) return null;

    final input = _splitInput();
    if (input.assignments.isEmpty) return null;

    return const SplitCalculator().calculate(
      items: input.items,
      assignments: input.assignments,
      tax: _tax,
      serviceCharge: _serviceCharge,
      globalDiscount: _discount,
      receiptTotal: _billTotal,
      payments: _payerId == null ? const {} : {_payerId!: _billTotal},
    );
  }

  Future<void> _editItem({_ItemDraft? existing}) async {
    final people = ref.read(peopleProvider).value ?? const <Person>[];
    final result = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(
        people: people,
        existing: existing,
        onAddPerson: (name) =>
            ref.read(personRepositoryProvider).create(name),
      ),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        _items.add(result);
      } else {
        existing
          ..name = result.name
          ..amount = result.amount;
        existing.personIds
          ..clear()
          ..addAll(result.personIds);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final input = _splitInput();

    try {
      final saved = await ref.read(transactionRepositoryProvider).save(
            TransactionDraft(
              walletId: _walletId!,
              categoryId: _categoryId,
              merchant: _merchantController.text.trim().isEmpty
                  ? 'Patungan'
                  : _merchantController.text.trim(),
              occurredAt: _date,
              total: _billTotal,
              tax: _tax,
              serviceCharge: _serviceCharge,
              discount: _discount,
              items: input.items,
              assignments: input.assignments,
              payments: _payerId == null ? const {} : {_payerId!: _billTotal},
            ),
          );

      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Tersimpan. Porsimu ${formatRupiah(saved.ownShare)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = ref.watch(peopleProvider).value ?? const <Person>[];
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final self = ref.watch(selfPersonProvider);

    // Bawaan yang benar hampir selalu: dompet pertama, dan yang bayar
    // adalah diri sendiri. Menalangi dulu lalu ditagih belakangan adalah
    // pola patungan yang paling umum.
    _walletId ??= wallets.isEmpty ? null : wallets.first.id;
    _payerId ??= self?.id;

    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Bagi tagihan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _merchantController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Nama tempat',
              prefixIcon: Icon(Icons.storefront_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Item',
            action: TextButton.icon(
              onPressed: () => _editItem(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada item. Tambahkan tiap pesanan, lalu tandai '
                'siapa yang menikmatinya.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (final item in _items)
              _ItemTile(
                item: item,
                people: people,
                onTap: () => _editItem(existing: item),
                onDelete: () => setState(() => _items.remove(item)),
              ),
          const SizedBox(height: 12),
          _ExtrasRow(
            tax: _tax,
            serviceCharge: _serviceCharge,
            discount: _discount,
            onChanged: (tax, service, discount) => setState(() {
              _tax = tax;
              _serviceCharge = service;
              _discount = discount;
            }),
          ),
          const Divider(height: 28),
          _SectionHeader(title: 'Yang menalangi di kasir'),
          Wrap(
            spacing: 8,
            children: [
              for (final person in people)
                ChoiceChip(
                  label: Text(person.isSelf ? '${person.name} (aku)' : person.name),
                  selected: _payerId == person.id,
                  onSelected: (_) => setState(() => _payerId = person.id),
                ),
            ],
          ),
          const Divider(height: 28),
          if (result != null)
            _ResultCard(result: result, people: people, total: _billTotal)
          else
            Text(
              'Tandai minimal satu item ke seseorang untuk melihat '
              'pembagiannya.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total tagihan', style: theme.textTheme.labelSmall),
                    Text(
                      formatRupiah(_billTotal),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _canSave ? _save : null,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        ?action,
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.people,
    required this.onTap,
    required this.onDelete,
  });

  final _ItemDraft item;
  final List<Person> people;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = people
        .where((person) => item.personIds.contains(person.id))
        .map((person) => person.isSelf ? 'aku' : person.name)
        .toList();

    // Item tanpa pemilik ditandai jelas. Mesin split tidak membebankannya
    // ke orang lain, jadi kalau dibiarkan, bagian itu tidak akan tertagih
    // ke siapa pun dan selisihnya baru ketahuan saat menghitung uang.
    final unassigned = names.isEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(item.name),
        subtitle: Text(
          unassigned ? 'Belum ditandai ke siapa pun' : names.join(', '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: unassigned
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatRupiah(item.amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Hapus item',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pajak, service charge, dan diskon.
///
/// Ketiganya dilipat di balik satu baris karena warung dan kaki lima
/// tidak memakainya sama sekali — dan itu mayoritas patungan di sini.
class _ExtrasRow extends StatefulWidget {
  const _ExtrasRow({
    required this.tax,
    required this.serviceCharge,
    required this.discount,
    required this.onChanged,
  });

  final int tax;
  final int serviceCharge;
  final int discount;
  final void Function(int tax, int serviceCharge, int discount) onChanged;

  @override
  State<_ExtrasRow> createState() => _ExtrasRowState();
}

class _ExtrasRowState extends State<_ExtrasRow> {
  late bool _expanded =
      widget.tax != 0 || widget.serviceCharge != 0 || widget.discount != 0;

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Pajak, service, diskon'),
        ),
      );
    }

    return Column(
      children: [
        _AmountField(
          label: 'Pajak',
          value: widget.tax,
          onChanged: (v) =>
              widget.onChanged(v, widget.serviceCharge, widget.discount),
        ),
        _AmountField(
          label: 'Service',
          value: widget.serviceCharge,
          onChanged: (v) => widget.onChanged(widget.tax, v, widget.discount),
        ),
        _AmountField(
          label: 'Diskon',
          value: widget.discount,
          onChanged: (v) =>
              widget.onChanged(widget.tax, widget.serviceCharge, v),
        ),
      ],
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value == 0 ? '' : widget.value.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: 'Rp ',
          isDense: true,
        ),
        // Hanya angka yang diterima. Nilai yang tidak terbaca dianggap
        // nol, bukan dibiarkan memakai nilai lama, supaya yang di layar
        // selalu sama dengan yang dihitung.
        onChanged: (text) =>
            widget.onChanged(int.tryParse(text.replaceAll('.', '')) ?? 0),
      ),
    );
  }
}

/// Formulir satu item: nama, nominal, dan siapa yang menikmatinya.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.people,
    required this.onAddPerson,
    this.existing,
  });

  final List<Person> people;
  final Future<String> Function(String name) onAddPerson;
  final _ItemDraft? existing;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  static const _uuid = Uuid();

  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _amountController = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.amount.toString(),
  );
  late final Set<String> _selected = {...?widget.existing?.personIds};

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  bool get _canSave => _nameController.text.trim().isNotEmpty && _amount > 0;

  Future<void> _addPerson() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah orang'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nama'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    // Orang baru langsung ikut tertandai ke item yang sedang dibuka —
    // itu satu-satunya alasan seseorang menambahkannya di tengah alur ini.
    final id = await widget.onAddPerson(trimmed);
    if (mounted) setState(() => _selected.add(id));
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Item baru' : 'Ubah item',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama item',
                hintText: 'Nasi goreng',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga',
                prefixText: 'Rp ',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Siapa yang menikmati',
                    style: theme.textTheme.titleSmall),
                TextButton.icon(
                  onPressed: _addPerson,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Orang baru'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final person in widget.people)
                  FilterChip(
                    label: Text(
                      person.isSelf ? '${person.name} (aku)' : person.name,
                    ),
                    selected: _selected.contains(person.id),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selected.add(person.id);
                      } else {
                        _selected.remove(person.id);
                      }
                    }),
                  ),
              ],
            ),
            if (_selected.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Dibagi rata ${_selected.length} orang: '
                '${formatRupiah(_amount ~/ _selected.length)} per orang.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _canSave
                    ? () => Navigator.of(context).pop(
                          _ItemDraft(
                            id: widget.existing?.id ?? _uuid.v4(),
                            name: _nameController.text.trim(),
                            amount: _amount,
                            personIds: _selected,
                          ),
                        )
                    : null,
                child: const Text('Simpan item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hasil pembagian: porsi tiap orang dan siapa harus transfer ke siapa.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.people,
    required this.total,
  });

  final SplitResult result;
  final List<Person> people;
  final int total;

  String _nameOf(String personId) {
    for (final person in people) {
      if (person.id == personId) {
        return person.isSelf ? '${person.name} (aku)' : person.name;
      }
    }
    return 'Orang';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Porsi tiap orang'),
        const SizedBox(height: 8),
        for (final share in result.shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_nameOf(share.personId))),
                Text(
                  formatRupiah(share.total),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        // Bagian yang belum ditandai sengaja ditampilkan sebagai baris
        // tersendiri, bukan disembunyikan atau dibebankan ke orang lain.
        if (result.unallocated != 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Belum ditandai',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              Text(
                formatRupiah(result.unallocated),
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        if (result.settlements.isNotEmpty) ...[
          const Divider(height: 24),
          const _SectionHeader(title: 'Siapa transfer ke siapa'),
          const SizedBox(height: 4),
          for (final settlement in result.settlements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${_nameOf(settlement.fromPersonId)} → '
                '${_nameOf(settlement.toPersonId)} '
                '${formatRupiah(settlement.amount)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
