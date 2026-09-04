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
              leading: CircleAvatar(
                child: Icon(categoryIcon(category.icon), size: 20),
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
    final result = await showModalBottomSheet<({String name, String icon})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(
        title: 'Ubah kategori',
        initialName: category.name,
        initialIcon: category.icon,
      ),
    );
    if (result == null) return;

    await ref.read(categoryRepositoryProvider).update(
          category.id,
          name: result.name,
          icon: result.icon,
        );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({String name, String icon})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CategoryForm(title: 'Kategori baru'),
    );
    if (result == null) return;

    await ref.read(categoryRepositoryProvider).create(
          name: result.name,
          icon: result.icon,
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

/// Formulir kategori: nama dan satu ikon dari daftar yang tersedia.
///
/// Ikon dipilih dari daftar tetap, bukan diketik. Nama ikon yang tidak
/// dikenal akan digambar sebagai penanda kosong, dan pengguna tidak punya
/// cara menebak nama mana yang sah.
class _CategoryForm extends StatefulWidget {
  const _CategoryForm({
    required this.title,
    this.initialName,
    this.initialIcon,
  });

  final String title;
  final String? initialName;
  final String? initialIcon;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late String _icon = widget.initialIcon ?? selectableIconNames.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, icon: _icon));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Simpan'),
            ),
          ),
        ],
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
