/// Mengelola kategori.
///
/// Kategori bawaan boleh diganti nama dan ikonnya, tapi tidak boleh
/// dihapus: transaksi lama yang menunjuk ke sana akan kehilangan
/// pengelompokannya, dan ringkasan per kategori jadi bolong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/providers.dart';
import 'package:chacing/ui/category_colors.dart';
import 'package:chacing/ui/category_icons.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final category = rows[index];
            return ListTile(
              leading: Builder(
                builder: (context) {
                  final color = categoryColor(
                    stored: category.colorValue,
                    seed: category.id,
                    brightness: Theme.of(context).brightness,
                  );
                  return CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.16),
                    foregroundColor: color,
                    child: Icon(categoryIcon(category.icon), size: 20),
                  );
                },
              ),
              title: Text(category.name),
              subtitle: category.isSystem ? const Text('Bawaan') : null,
              onTap: () => _edit(context, ref, category),
              trailing: category.isSystem
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Hapus',
                      onPressed: () => _delete(context, ref, category),
                    ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final result = await showModalBottomSheet<({String name, String icon, int color})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(
        title: 'Ubah kategori',
        initialName: category.name,
        initialIcon: category.icon,
        initialColor: category.colorValue,
        seed: category.id,
      ),
    );
    if (result == null) return;

    await ref.read(categoryRepositoryProvider).update(
          category.id,
          name: result.name,
          icon: result.icon,
          colorValue: result.color,
        );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({String name, String icon, int color})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CategoryForm(title: 'Kategori baru'),
    );
    if (result == null) return;

    await ref.read(categoryRepositoryProvider).create(
          name: result.name,
          icon: result.icon,
          colorValue: result.color,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${category.name}?'),
        content: const Text(
          'Transaksi yang memakai kategori ini tidak ikut terhapus, '
          'tapi jadi tanpa kategori.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await ref.read(categoryRepositoryProvider).softDelete(
          category.id,
        );
    if (!removed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kategori bawaan tidak bisa dihapus.')),
      );
    }
  }
}

/// Formulir kategori: nama, ikon, dan warna.
///
/// Ikon dan warna dipilih dari daftar tetap, bukan diketik atau diambil
/// dari pemilih warna bebas. Warna bebas menghasilkan kuning pucat yang
/// tidak terbaca di atas putih, dan dua kategori yang nyaris sama
/// warnanya jadi tidak bisa dibedakan di grafik.
class _CategoryForm extends StatefulWidget {
  const _CategoryForm({
    required this.title,
    this.initialName,
    this.initialIcon,
    this.initialColor,
    this.seed,
  });

  final String title;
  final String? initialName;
  final String? initialIcon;
  final int? initialColor;

  /// Id kategori, dipakai menentukan warna bawaan saat belum pernah
  /// dipilih supaya yang tampil di formulir sama dengan yang di grafik.
  final String? seed;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late String _icon = widget.initialIcon ?? selectableIconNames.first;
  late Color _color = categoryColor(
    stored: widget.initialColor,
    seed: widget.seed ?? widget.initialName ?? 'baru',
    brightness: Brightness.light,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      (name: name, icon: _icon, color: encodeCategoryColor(_color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Pratinjau memakai kecerahan tema yang sedang aktif supaya yang
    // terlihat di formulir sama dengan yang nanti muncul di grafik.
    final preview = categoryColor(
      stored: encodeCategoryColor(_color),
      seed: widget.seed ?? '',
      brightness: theme.brightness,
    );

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
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: preview.withValues(alpha: 0.16),
                  foregroundColor: preview,
                  child: Icon(categoryIcon(_icon), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama',
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text('Ikon', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final name in selectableIconNames)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _IconChoice(
                        icon: categoryIcon(name),
                        selected: _icon == name,
                        onTap: () => setState(() => _icon = name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Warna di grafik', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in categoryPalette)
                  _ColorChoice(
                    color: swatch,
                    selected: isSameSwatch(swatch, _color),
                    onTap: () => setState(() => _color = swatch),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // Tanda pilih berupa cincin di luar, bukan mengubah warnanya,
            // supaya warna yang dilihat persis warna yang tersimpan.
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 56,
          child: Icon(
            icon,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
