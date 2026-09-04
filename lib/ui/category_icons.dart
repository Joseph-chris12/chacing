/// Pemetaan nama ikon (disimpan sebagai teks di database) ke [IconData].
///
/// Peta ini sengaja ditulis manual dan `const`. Flutter membuang ikon yang
/// tidak terpakai saat build rilis, dan itu hanya bisa dilakukan kalau ikon
/// dirujuk sebagai konstanta. Mencari `IconData` dari string saat runtime
/// memaksa seluruh set ikon Material ikut dibundel — puluhan megabyte.
library;

import 'package:flutter/material.dart';

const _icons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'movie': Icons.movie,
  'medical_services': Icons.medical_services,
  'more_horiz': Icons.more_horiz,
  'home': Icons.home,
  'school': Icons.school,
  'pets': Icons.pets,
  'sports_esports': Icons.sports_esports,
  'card_giftcard': Icons.card_giftcard,
  'local_cafe': Icons.local_cafe,
  'fitness_center': Icons.fitness_center,
  'local_gas_station': Icons.local_gas_station,
  'phone_android': Icons.phone_android,
};

/// Ikon untuk kategori. Kategori tanpa ikon, atau dengan nama ikon yang
/// tidak dikenal, memakai penanda netral daripada gagal digambar.
IconData categoryIcon(String? name) =>
    _icons[name] ?? Icons.label_outline;

/// Nama ikon yang bisa dipilih pengguna saat membuat kategori sendiri.
List<String> get selectableIconNames => _icons.keys.toList(growable: false);

/// Ikon untuk jenis dompet.
IconData walletIcon(String type) {
  switch (type) {
    case 'cash':
      return Icons.payments;
    case 'ewallet':
      return Icons.account_balance_wallet;
    case 'bank':
      return Icons.account_balance;
    case 'credit':
      return Icons.credit_card;
    default:
      return Icons.account_balance_wallet;
  }
}
