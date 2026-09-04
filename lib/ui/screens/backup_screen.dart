/// Cadangkan dan pulihkan seluruh data lewat satu file JSON.
///
/// Sampai sync dibangun, file inilah satu-satunya jalan keluar data. Kalau
/// HP hilang atau aplikasi dipasang ulang, tanpa file ini semuanya habis.
///
/// Memulihkan menimpa seluruh isi aplikasi, jadi selalu lewat dialog
/// konfirmasi yang menyebutkan isi filenya lebih dulu. Menimpa data
/// keuangan karena salah pilih file adalah kesalahan yang tidak bisa
/// diurungkan.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:chacing/data/backup.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/format.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);

    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final json = await service.exportJson();

      // File ditulis ke direktori sementara, bukan ke penyimpanan bersama.
      // Share sheet yang menyalinnya ke tujuan pilihan pengguna, jadi
      // aplikasi tidak perlu izin tulis ke mana-mana.
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${service.suggestedFileName()}');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Cadangan Chacing',
          text: 'Cadangan data Chacing',
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat cadangan: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;

    final picked = await FilePicker.pickFile(
      dialogTitle: 'Pilih file cadangan',
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);

    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bytes = await picked.readAsBytes();
      final source = utf8.decode(bytes);

      // Diperiksa dulu tanpa menyentuh database, supaya file yang salah
      // ditolak sebelum ada satu baris pun yang terhapus.
      final contents = service.inspect(source);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _RestoreConfirmation(
          contents: contents,
          fileName: picked.name,
        ),
      );
      if (confirmed != true) return;

      await service.restore(source);
      messenger.showSnackBar(
        const SnackBar(content: Text('Data berhasil dipulihkan.')),
      );
    } on BackupFormatException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal memulihkan: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cadangkan & pulihkan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Seluruh transaksi, kategori, dompet, dan budget disimpan ke '
            'satu file JSON. Simpan di Drive atau kirim ke dirimu sendiri, '
            'lalu pulihkan kapan saja di HP mana pun.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file),
            label: const Text('Buat cadangan'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.download),
            label: const Text('Pulihkan dari file'),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 28),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memulihkan menimpa semuanya',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data yang ada sekarang diganti seluruhnya dengan isi '
                    'file, bukan digabung. Buat cadangan dulu kalau di HP '
                    'ini masih ada catatan yang belum tersimpan di mana pun.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreConfirmation extends StatelessWidget {
  const _RestoreConfirmation({required this.contents, required this.fileName});

  final BackupContents contents;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exportedAt = contents.exportedAt;

    return AlertDialog(
      title: const Text('Pulihkan data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fileName, style: theme.textTheme.bodySmall),
          if (exportedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dibuat ${formatFullDate(exportedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text('${contents.transactions} transaksi'),
          Text('${contents.categories} kategori'),
          Text('${contents.wallets} dompet'),
          if (contents.budgets > 0) Text('${contents.budgets} budget'),
          const SizedBox(height: 12),
          const Text(
            'Semua data di HP ini akan diganti dengan isi file tersebut.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Pulihkan'),
        ),
      ],
    );
  }
}
