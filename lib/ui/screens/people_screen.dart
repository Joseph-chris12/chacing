/// Daftar orang untuk bagi tagihan.
///
/// Tidak ada akun, tidak ada undangan — cukup nama. Sebagian besar
/// patungan terjadi dengan teman yang tidak akan pernah memasang
/// aplikasi ini, dan memaksa mereka mendaftar akan membunuh fiturnya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/providers.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  Future<String?> _askName(BuildContext context, {String? initial}) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial == null ? 'Tambah orang' : 'Ubah nama'),
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleProvider);
    final repository = ref.read(personRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orang')),
      body: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final person = rows[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  person.name.characters.first.toUpperCase(),
                ),
              ),
              title: Text(person.name),
              subtitle: person.isSelf ? const Text('Kamu') : null,
              onTap: () async {
                final name =
                    await _askName(context, initial: person.name);
                if (name != null) await repository.rename(person.id, name);
              },
              // Diri sendiri tidak bisa dihapus: tanpa barisnya, porsi
              // sendiri tidak bisa dihitung dan seluruh total tagihan
              // akan masuk ke budget.
              trailing: person.isSelf
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Hapus',
                      onPressed: () => repository.softDelete(person.id),
                    ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _askName(context);
          if (name != null) await repository.create(name);
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Tambah'),
      ),
    );
  }
}
