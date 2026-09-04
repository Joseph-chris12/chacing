/// Memasang kunci API pembaca struk.
///
/// Kuncinya dimasukkan sendiri oleh pemilik aplikasi, tidak ditanam di
/// dalam APK. Kunci yang ditanam bisa diambil siapa pun yang membongkar
/// berkas aplikasinya, lalu dipakai atas tanggungan pemiliknya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/providers.dart';

class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty || _saving) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);

    await ref.read(apiKeyStoreProvider).write(key);
    ref.invalidate(hasApiKeyProvider);

    if (mounted) navigator.pop(true);
  }

  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    await ref.read(apiKeyStoreProvider).clear();
    ref.invalidate(hasApiKeyProvider);
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = ref.watch(hasApiKeyProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunci pembaca struk'),
        actions: [
          if (hasKey)
            TextButton(onPressed: _remove, child: const Text('Hapus')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasKey)
            Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline,
                    color: theme.colorScheme.primary),
                title: const Text('Kunci sudah terpasang'),
                subtitle: const Text(
                  'Isi kolom di bawah untuk menggantinya.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Kunci API Gemini',
              hintText: 'AQ.Ab…',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan kunci'),
            ),
          ),
          const SizedBox(height: 28),
          Text('Cara mendapatkannya', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '1. Buka aistudio.google.com dengan akun Google-mu.\n'
            '2. Pilih "Get API key", lalu buat kunci baru.\n'
            '3. Salin kuncinya dan tempel di kolom atas.\n\n'
            'Kunci baru dari AI Studio berawalan "AQ.Ab". Yang '
            'berawalan "AIza" sudah tidak dilayani Google sejak '
            'September 2026.\n\n'
            'Kuotanya cukup untuk memindai beberapa struk sehari.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kenapa harus kunci sendiri',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Kunci yang ditanam di dalam aplikasi bisa diambil '
                    'siapa pun yang membongkar berkasnya, lalu dipakai atas '
                    'tagihan pemiliknya. Karena itu kuncimu disimpan di '
                    'penyimpanan aman bawaan HP, tidak ikut ke berkas '
                    'cadangan, dan tidak pernah dikirim ke mana pun selain '
                    'ke Google.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Di kuota gratis, fotonya dilihat Google',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google memakai apa yang dikirim lewat kuota gratis — '
                    'termasuk foto struk — untuk mengembangkan produknya, '
                    'dan petugasnya boleh membacanya. Satu foto struk '
                    'memuat di mana kamu makan, beli apa, dan kapan.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kalau itu mengganggu, aktifkan penagihan di akun '
                    'Google-mu; kuota berbayar tidak dipakai untuk '
                    'pengembangan. Atau lewati saja fitur scan — semua '
                    'fitur lain tetap jalan tanpa kunci ini.',
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
