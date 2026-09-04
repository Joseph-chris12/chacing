/// Memasang kunci API pembaca struk.
///
/// Isinya langkah, bukan penjelasan. Layar yang muncul saat seseorang
/// sedang mencoba menyelesaikan satu pekerjaan bukan tempat membaca
/// alasan — yang perlu dibaca cuma "berikutnya ngapain".
///
/// Penjelasannya tidak dihapus, hanya dilipat: konsekuensi privasi kuota
/// gratis tetap harus bisa ditemukan sebelum ada foto yang terkirim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chacing/data/gemini_client.dart';
import 'package:chacing/providers.dart';

/// Langkah mendapatkan kunci, ditulis sependek mungkin.
const _steps = <String>[
  'Buka aistudio.google.com',
  'Masuk dengan akun Google',
  'Ketuk "Get API key"',
  'Ketuk "Create API key"',
  'Salin kunci yang muncul',
  'Tempel di kolom bawah, lalu Simpan',
];

class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  final _controller = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscured = true;
  bool _saving = false;
  bool _loadedModel = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final stored = await ref.read(settingsStoreProvider).readScanModel();
    if (!mounted) return;
    setState(() {
      _modelController.text = stored ?? '';
      _loadedModel = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty || _saving) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);

    await ref.read(apiKeyStoreProvider).write(key);
    await ref.read(settingsStoreProvider).writeScanModel(_modelController.text);
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (hasKey)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kunci sudah terpasang',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < _steps.length; i++)
            _Step(number: i + 1, text: _steps[i]),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Kunci API',
              hintText: 'AQ.Ab…',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
            ),
          ),
          const SizedBox(height: 8),
          _Details(
            modelController: _modelController,
            modelEnabled: _loadedModel,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Yang tidak perlu dibaca untuk menyelesaikan pemasangan.
///
/// Dilipat, bukan dibuang. Konsekuensi privasi kuota gratis tetap harus
/// bisa ditemukan sebelum ada satu foto pun yang terkirim, dan kolom
/// nama model adalah satu-satunya jalan keluar kalau Google menghentikan
/// model yang dipakai sekarang.
class _Details extends StatelessWidget {
  const _Details({required this.modelController, required this.modelEnabled});

  final TextEditingController modelController;
  final bool modelEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      // Garis pemisah bawaan ExpansionTile memotong tata letak yang
      // sudah rapi tanpa menambah apa pun.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Column(
        children: [
          ExpansionTile(
            title: Text('Kalau scan gagal', style: theme.textTheme.titleSmall),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: modelController,
                autocorrect: false,
                enableSuggestions: false,
                enabled: modelEnabled,
                decoration: InputDecoration(
                  labelText: 'Nama model',
                  hintText: GeminiReceiptScanner.defaultModel,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Kalau muncul kode 404, pesannya menyebut nama model '
                'pengganti. Tulis di sini, lalu Simpan.\n\n'
                'Kosongkan untuk kembali ke '
                '${GeminiReceiptScanner.defaultModel}.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          ExpansionTile(
            title: Text(
              'Fotonya dilihat Google',
              style: theme.textTheme.titleSmall,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Di kuota gratis, Google memakai apa yang dikirim — '
                'termasuk foto struk — untuk mengembangkan produknya, dan '
                'petugasnya boleh membacanya. Satu foto struk memuat di '
                'mana kamu makan, beli apa, dan kapan.\n\n'
                'Aktifkan penagihan di akun Google-mu kalau itu '
                'mengganggu; kuota berbayar tidak dipakai untuk '
                'pengembangan. Atau lewati fitur scan — semua fitur lain '
                'tetap jalan tanpa kunci ini.\n\n'
                'Kuncimu sendiri disimpan di penyimpanan aman bawaan HP, '
                'tidak ikut ke berkas cadangan, dan tidak dikirim ke mana '
                'pun selain ke Google.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
