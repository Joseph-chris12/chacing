/// Membuka file database di penyimpanan aplikasi.
///
/// Dipisah dari [AppDatabase] supaya tes bisa memakai database in-memory
/// tanpa menyentuh path_provider atau file sungguhan.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Nama file: `chacing.sqlite` di direktori dokumen aplikasi.
QueryExecutor openConnection() => driftDatabase(name: 'chacing');
