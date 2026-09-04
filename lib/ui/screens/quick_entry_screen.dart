/// Layar input cepat — layar terpenting di seluruh aplikasi.
///
/// Target yang harus dipenuhi: mencatat satu pengeluaran dalam **di bawah
/// 10 detik**, diukur dengan stopwatch sungguhan.
///
/// Semua keputusan tata letak di sini tunduk pada target itu:
///
///  * Nominal diketik dengan papan angka sendiri, langsung terlihat saat
///    layar dibuka. Tidak ada ketukan pembuka.
///  * Kategori sekali ketuk dari deretan ikon, bukan dropdown.
///  * Dompet dan tanggal sudah terisi default yang benar 95% waktu, jadi
///    biasanya tidak disentuh sama sekali.
///  * Nama merchant boleh kosong. Mengetik huruf itu lambat, dan kategori
///    sudah cukup untuk mengingat "Rp 25.000 buat makan".
///  * Tombol simpan besar dan menempel di bawah, di jangkauan jempol.
///
/// Jalur tercepat: ketik angka, ketuk kategori, ketuk simpan. Tiga gerakan.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/data/repositories/transaction_repository.dart';
import 'package:chacing/domain/split_calculator.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/category_icons.dart';
import 'package:chacing/ui/format.dart';
import 'package:chacing/ui/widgets/amount_keypad.dart';
import 'package:chacing/ui/widgets/category_picker.dart';

class QuickEntryScreen extends ConsumerStatefulWidget {
  const QuickEntryScreen({super.key, this.existing});

  /// Transaksi yang sedang disunting. Null berarti mencatat yang baru.
  final Transaction? existing;

  @override
  ConsumerState<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends ConsumerState<QuickEntryScreen> {
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  /// Catatan disembunyikan sampai diminta. Sebagian besar pencatatan
  /// tidak butuh catatan, dan isian tambahan di jalur tercepat hanya
  /// memperlambat yang lewat setiap hari.
  bool _showNote = false;

  int _amount = 0;
  String? _categoryId;
  String? _walletId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing == null) return;

    _amount = existing.total;
    _categoryId = existing.categoryId;
    _walletId = existing.walletId;
    _date = existing.occurredAt;
    _merchantController.text = existing.merchant;
    _noteController.text = existing.note ?? '';
    _showNote = (existing.note ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSave => _amount > 0 && _walletId != null && !_saving;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      // Pengeluaran yang belum terjadi bukan pengeluaran.
      lastDate: now,
      // Belum ada `locale:` di sini. Kalender berbahasa Indonesia butuh
      // paket `flutter_localizations`, dan menambah dependensi harus
      // ditanyakan dulu. Sementara ini kalendernya berbahasa Inggris —
      // jarang dibuka karena tanggal sudah default hari ini.
    );

    if (picked != null) setState(() => _date = picked);
  }

  /// Waktu kejadian.
  ///
  /// Untuk hari ini dipakai jam sekarang supaya urutan transaksi dalam satu
  /// hari mengikuti urutan pencatatan. Untuk tanggal lampau dipakai tengah
  /// hari — jam yang tidak pernah salah masuk ke hari sebelum atau sesudahnya.
  DateTime get _occurredAt {
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;

    return isToday
        ? now
        : DateTime(_date.year, _date.month, _date.day, 12);
  }

  String _merchantOrFallback(List<Category> categories) {
    final typed = _merchantController.text.trim();
    if (typed.isNotEmpty) return typed;

    // Tanpa nama merchant, nama kategori jauh lebih berguna daripada
    // baris kosong saat melihat daftar minggu depan.
    if (_categoryId != null) {
      for (final category in categories) {
        if (category.id == _categoryId) return category.name;
      }
    }
    return 'Pengeluaran';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repository = ref.read(transactionRepositoryProvider);
    final existing = widget.existing;

    try {
      // Layar ini hanya menyunting nominal, kategori, dompet, tanggal, dan
      // nama. Semua yang tidak tampil di sini harus ikut dibawa kembali:
      // `save` selalu menulis ulang seluruh baris anak dari draft, jadi
      // draft yang tidak lengkap akan menghapus item dan split diam-diam.
      final items = existing == null
          ? const <LineItem>[]
          : await repository.itemsOf(existing.id);
      final assignments = existing == null
          ? const <Assignment>[]
          : await repository.assignmentsOf(existing.id);
      final payments = existing == null
          ? const <String, int>{}
          : await repository.paymentsOf(existing.id);

      await repository.save(
        TransactionDraft(
          id: existing?.id,
          walletId: _walletId!,
          categoryId: _categoryId,
          merchant: _merchantOrFallback(categories),
          occurredAt: _occurredAt,
          total: _amount,
          tax: existing?.tax ?? 0,
          serviceCharge: existing?.serviceCharge ?? 0,
          discount: existing?.discount ?? 0,
          excludeFromBudget: existing?.excludeFromBudget ?? false,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          receiptPhotoPath: existing?.receiptPhotoPath,
          source: existing?.source ?? TransactionSource.manual,
          items: items,
          assignments: assignments,
          payments: payments,
        ),
      );

      // Getaran halus sebagai ganti bunyi "cha-ching" — bisa dirasakan
      // tanpa mengganggu orang lain di tempat umum.
      await HapticFeedback.mediumImpact();
      if (mounted) navigator.pop(true);
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
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);

    // Dompet pertama dipilih otomatis. Sebagian besar orang hanya punya
    // satu dompet aktif, jadi ini menghapus satu ketukan dari alur.
    //
    // Diisi langsung di sini, bukan lewat `ref.listen` dengan `setState`:
    // dompet datang dari stream, jadi kedatangannya sudah memicu build
    // ulang sendiri. Memanggil `setState` dari dalam build justru error.
    final walletRows = wallets.value;
    if (_walletId == null && walletRows != null && walletRows.isNotEmpty) {
      _walletId = walletRows.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
          tooltip: 'Batal',
        ),
        title: Text(_isEditing ? 'Ubah pengeluaran' : 'Catat pengeluaran'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DateChip(date: _date, onPick: _pickDate),
                    _AmountDisplay(amount: _amount),
                    const SizedBox(height: 8),
                    categories.when(
                      loading: () => const SizedBox(height: 82),
                      error: (error, _) => SizedBox(
                        height: 82,
                        child: Center(child: Text('Kategori gagal dimuat: $error')),
                      ),
                      data: (rows) => CategoryPicker(
                        categories: rows,
                        selectedId: _categoryId,
                        onSelected: (id) => setState(() => _categoryId = id),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _merchantController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Nama tempat (boleh dikosongkan)',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNote
                                  ? Icons.notes
                                  : Icons.note_add_outlined,
                            ),
                            tooltip: _showNote
                                ? 'Sembunyikan catatan'
                                : 'Tambah catatan',
                            onPressed: () =>
                                setState(() => _showNote = !_showNote),
                          ),
                        ),
                      ),
                    ),
                    if (_showNote) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _noteController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Catatan',
                            prefixIcon: Icon(Icons.notes),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _WalletChips(
                      wallets: walletRows ?? const [],
                      selectedId: _walletId,
                      onSelected: (id) => setState(() => _walletId = id),
                    ),
                    const SizedBox(height: 8),
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
                    _saving ? 'Menyimpan…' : 'Simpan',
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

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = amount == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatRupiah(amount),
          maxLines: 1,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isEmpty
                ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Tanggal, di atas nominal.
///
/// Tanggal menentukan arti angka di bawahnya — "Rp 50.000" hari ini dan
/// "Rp 50.000" minggu lalu masuk ke periode budget yang berbeda — jadi
/// dibaca lebih dulu. Hampir selalu sudah benar di "Hari ini", jadi
/// menaruhnya di atas tidak menambah satu ketukan pun.
class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.onPick});

  final DateTime date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ActionChip(
          avatar: const Icon(Icons.event, size: 18),
          label: Text(formatRelativeDate(date)),
          onPressed: onPick,
        ),
      ),
    );
  }
}

/// Pemilih dompet, di paling bawah.
///
/// Ditaruh terakhir karena paling jarang disentuh: dompet pertama sudah
/// terpilih otomatis, dan sebagian besar orang cuma punya satu yang
/// aktif. Menaruhnya di jalur utama hanya memanjangkan layar yang harus
/// dilewati untuk sampai ke tombol simpan.
class _WalletChips extends StatelessWidget {
  const _WalletChips({
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Wallet> wallets;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Satu dompet saja tidak perlu dipilih. Menampilkan satu chip yang
    // selalu terpilih hanya menambah baris tanpa memberi pilihan.
    if (wallets.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final wallet in wallets) ...[
            ChoiceChip(
              avatar: Icon(walletIcon(wallet.type.name), size: 18),
              label: Text(wallet.name),
              selected: wallet.id == selectedId,
              onSelected: (_) => onSelected(wallet.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

