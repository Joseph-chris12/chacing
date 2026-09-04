/// Memindai struk lewat foto.
///
/// Alurnya sengaja berhenti di layar konfirmasi sebelum menyimpan. Yang
/// keluar dari OCR adalah tebakan, dan tebakan tidak boleh diam-diam
/// menjadi catatan keuangan — baris yang kurang yakin disorot supaya
/// yang perlu diperiksa terlihat lebih dulu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/gemini_client.dart';
import 'package:chacing/data/receipt_capture.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/domain/receipt_draft.dart';
import 'package:chacing/domain/split_calculator.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/screens/api_key_screen.dart';
import 'package:chacing/ui/widgets/category_picker.dart';

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  bool _busy = false;
  String? _error;
  ReceiptDraft? _draft;
  String? _photoPath;
  String? _categoryId;
  String? _walletId;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final navigator = Navigator.of(context);

    try {
      final captured = await ref.read(receiptCaptureProvider).capture(source);
      if (!mounted) return;

      setState(() {
        _busy = false;
        if (captured != null) {
          _draft = captured.draft;
          _photoPath = captured.photoPath;
        }
      });
    } on MissingApiKeyException {
      if (!mounted) return;
      setState(() => _busy = false);
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ApiKeyScreen()),
      );
    } on ReceiptScanException catch (error) {
      _fail(error.message);
    } on ReceiptParseException catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('Gagal membaca struk: $error');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _busy = false;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _walletId == null || _busy) return;

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(transactionRepositoryProvider).save(
            TransactionDraft(
              walletId: _walletId!,
              categoryId: _categoryId,
              merchant: draft.merchant ?? 'Struk',
              occurredAt: draft.occurredAt ?? DateTime.now(),
              total: draft.total,
              tax: draft.tax,
              serviceCharge: draft.serviceCharge,
              discount: draft.discount,
              source: TransactionSource.ocrReceipt,
              receiptPhotoPath: _photoPath,
              // Sudah dikonfirmasi manusia di layar ini, jadi tidak perlu
              // ditandai butuh peninjauan lagi.
              needsReview: false,
              items: [
                for (var i = 0; i < draft.items.length; i++)
                  LineItem(
                    id: '${DateTime.now().microsecondsSinceEpoch}-$i',
                    name: draft.items[i].name,
                    quantity: draft.items[i].quantity,
                    unitPrice: draft.items[i].unitPrice,
                  ),
              ],
            ),
          );

      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Struk tersimpan')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    _walletId ??= wallets.isEmpty ? null : wallets.first.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan struk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_outlined),
            tooltip: 'Kunci API',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
            ),
          ),
        ],
      ),
      body: _busy
          ? const _Scanning()
          : _draft == null
              ? _Chooser(error: _error, onPick: _pick)
              : _Review(
                  draft: _draft!,
                  categoryId: _categoryId,
                  onCategory: (id) => setState(() => _categoryId = id),
                  onRetake: () => setState(() {
                    _draft = null;
                    _photoPath = null;
                  }),
                ),
      bottomNavigationBar: _draft == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _walletId == null ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text('Simpan ${formatRupiah(_draft!.total)}'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser({required this.error, required this.onPick});

  final String? error;
  final void Function(ImageSource) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (error != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Icon(
          Icons.receipt_long_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Foto struknya, sisanya dibaca otomatis.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Hasilnya selalu ditampilkan dulu untuk kamu periksa sebelum '
          'disimpan.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => onPick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Ambil foto'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => onPick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pilih dari galeri'),
          ),
        ),
      ],
    );
  }
}

class _Scanning extends StatelessWidget {
  const _Scanning();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('Membaca struk…', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('Biasanya beberapa detik.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatRupiah(amount), style: style),
        ],
      ),
    );
  }
}

/// Layar konfirmasi hasil pembacaan.
class _Review extends ConsumerWidget {
  const _Review({
    required this.draft,
    required this.categoryId,
    required this.onCategory,
    required this.onRetake,
  });

  final ReceiptDraft draft;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.merchant ?? 'Tanpa nama',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (draft.occurredAt != null)
                      Text(
                        formatFullDate(draft.occurredAt!),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Ulangi'),
              ),
            ],
          ),
        ),
        for (final warning in draft.warnings) _WarningCard(text: warning),
        const SizedBox(height: 12),
        CategoryPicker(
          categories: categories,
          selectedId: categoryId,
          onSelected: onCategory,
        ),
        const Divider(height: 24),
        for (final item in draft.items)
          ListTile(
            dense: true,
            leading: item.isDoubtful
                ? Icon(Icons.help_outline, color: theme.colorScheme.tertiary)
                : const Icon(Icons.check, size: 18),
            title: Text(item.name),
            subtitle: item.quantity > 1
                ? Text('${item.quantity} × ${formatRupiah(item.unitPrice)}')
                : null,
            trailing: Text(formatRupiah(item.total)),
          ),
        if (draft.hasDoubtfulItems)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Baris bertanda tanya kurang terbaca jelas. Periksa angkanya '
              'sebelum menyimpan.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.tertiary),
            ),
          ),
        const Divider(height: 24),
        _TotalRow(label: 'Subtotal item', amount: draft.itemsTotal),
        if (draft.tax != 0) _TotalRow(label: 'Pajak', amount: draft.tax),
        if (draft.serviceCharge != 0)
          _TotalRow(label: 'Service', amount: draft.serviceCharge),
        if (draft.discount != 0)
          _TotalRow(label: 'Diskon', amount: -draft.discount),
        _TotalRow(label: 'Total', amount: draft.total, emphasized: true),
      ],
    );
  }
}

/// Peringatan ditaruh di atas daftar, bukan di bawah: kalau angkanya
/// tidak cocok, itu yang harus dilihat lebih dulu.
class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
