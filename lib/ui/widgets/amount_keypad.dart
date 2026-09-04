/// Papan angka khusus nominal.
///
/// Bukan keyboard sistem. Alasannya bukan gaya-gayaan:
///
///  * Keyboard sistem butuh waktu muncul dan menutupi separuh layar.
///  * Tombol angkanya kecil karena harus berbagi tempat dengan huruf.
///  * Tidak ada tombol `000`, padahal hampir semua nominal rupiah
///    berakhiran tiga nol.
///
/// Tombolnya besar dan berada di area jempol karena layar ini dipakai
/// sambil berdiri di kasir, satu tangan.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chacing/domain/amount_input.dart';

class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.amount,
    required this.onChanged,
  });

  final int amount;
  final ValueChanged<int> onChanged;

  /// Aturan penyusunan nominalnya ada di [AmountInput], bukan di sini.
  /// Widget ini cuma mengurus tampilan dan getaran.
  AmountInput get _input => AmountInput(amount);

  void _emit(AmountInput next) {
    if (next.value == amount) return;
    HapticFeedback.selectionClick();
    onChanged(next.value);
  }

  void _append(int digit) => _emit(_input.append(digit));

  void _appendTripleZero() => _emit(_input.appendTripleZero());

  void _backspace() => _emit(_input.backspace());

  void _clear() {
    if (_input.isEmpty) return;
    HapticFeedback.mediumImpact();
    onChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row([_digit(1), _digit(2), _digit(3)]),
        _row([_digit(4), _digit(5), _digit(6)]),
        _row([_digit(7), _digit(8), _digit(9)]),
        _row([
          _KeypadButton(
            label: '000',
            onTap: _appendTripleZero,
            enabled: amount != 0,
          ),
          _digit(0),
          _KeypadButton(
            icon: Icons.backspace_outlined,
            onTap: _backspace,
            // Tahan untuk mengosongkan — lebih cepat daripada menekan
            // hapus sembilan kali setelah salah ketik.
            onLongPress: _clear,
            enabled: amount != 0,
          ),
        ]),
      ],
    );
  }

  Widget _digit(int value) =>
      _KeypadButton(label: '$value', onTap: () => _append(value));

  Widget _row(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final child in children)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    this.label,
    this.icon,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          // Tinggi tetap supaya tombol tetap besar di layar pendek maupun
          // panjang. 64 dp jauh di atas batas minimum 48 dp.
          height: 64,
          child: Center(
            child: icon != null
                ? Icon(icon, color: foreground, size: 26)
                : Text(
                    label!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
