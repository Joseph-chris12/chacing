# CLAUDE.md

Konteks proyek untuk Claude Code. Baca ini sebelum mengubah apa pun.

---

## Tentang Proyek

**Chacing** — aplikasi pencatat keuangan pribadi untuk pengguna Indonesia.

Tiga fitur utama:

1. Catat pengeluaran, dengan scan struk lewat foto
2. Split bill yang menghitung porsi per orang, bukan sekadar bagi rata
3. Batas pengeluaran mingguan

Nama berasal dari plesetan "cha-ching" (bunyi mesin kasir) dan "cacing".
Maskotnya seekor cacing.

**Bahasa:** kode, nama variabel, dan nama file dalam bahasa Inggris.
Komentar, dokumentasi, dan teks yang dilihat pengguna dalam bahasa Indonesia.

---

## Aturan Mutlak

Aturan berikut tidak boleh dilanggar. Kalau sebuah permintaan mengharuskan
melanggarnya, berhenti dan tanyakan dulu.

### 1. Uang selalu `int` rupiah penuh

Tidak ada `double`, tidak ada desimal, tidak ada floating point untuk nilai
uang yang disimpan. Rupiah tidak punya sen dalam praktik sehari-hari, dan
floating point menimbulkan galat yang tidak bisa diterima untuk data keuangan.

`double` hanya boleh dipakai sebagai perhitungan proporsi sementara di dalam
`SplitCalculator`, dan hasilnya wajib dibulatkan kembali ke `int` sebelum
keluar dari kelas itu.

### 2. Budget memakai `ownShare`, bukan `total`

Ini kesalahan yang paling mudah terjadi dan paling merusak.

- `total` = yang keluar dari dompet di kasir
- `ownShare` = porsi pengguna sendiri setelah split

Kalau pengguna menalangi makan bertujuh senilai Rp 700.000 tapi porsinya
Rp 100.000, maka `total` = 700000 dan `ownShare` = 100000. **Semua query
budget dan ringkasan pengeluaran wajib memakai `own_share`.**

`ownShare` dihitung otomatis di `TransactionRepository.save()`. Jangan pernah
menerimanya sebagai masukan langsung dari UI.

### 3. Tidak ada penghapusan permanen pada transaksi

Penghapusan transaksi mengisi kolom `deletedAt`, bukan menjalankan `DELETE`.
Tanpa tombstone, device lain tidak tahu ada penghapusan dan akan
menghidupkannya kembali saat sync.

Pengecualian yang disengaja: baris anak (`line_items`, `assignments`,
`payments`) boleh dihapus permanen saat transaksi induknya diedit, karena
baris anak tidak pernah disinkronkan sendirian.

Setiap query baca wajib menyertakan `deleted_at IS NULL`.

### 4. Semua id berupa UUID string

Bukan integer auto-increment. Dua device yang membuat data secara offline
tidak boleh menghasilkan id yang bertabrakan. Pakai `Uuid().v4()`.

### 5. Setiap tulis menyalakan `isDirty` dan memperbarui `updatedAt`

Ini yang menentukan baris mana yang perlu dikirim ke server nanti. Lupa
melakukannya berarti data diam-diam tidak pernah tersinkron.

### 6. Ubah tabel berarti menaikkan `schemaVersion`

Setiap perubahan struktur tabel wajib disertai kenaikan `schemaVersion` dan
penulisan langkah migrasi di `onUpgrade`. Lupa melakukannya berarti data
pengguna hilang saat pembaruan aplikasi.

---

## Arsitektur

```
lib/
  data/
    database.dart              skema Drift, satu-satunya tempat SQL hidup
    repositories/              satu-satunya pintu akses data
  domain/
    split_calculator.dart      hitungan split, murni Dart
    budget_period.dart         batas periode dan status budget, murni Dart
  ui/
    screens/
    widgets/
  main.dart
```

**Aturan lapisan:**

- UI tidak boleh menyentuh Drift atau SQL langsung. Selalu lewat repository.
- `domain/` tidak boleh mengimpor apa pun dari `data/` atau `ui/`. Isinya
  murni logika yang bisa diuji tanpa Flutter maupun database.
- Repository mengembalikan objek domain, bukan baris Drift mentah, kecuali
  untuk kasus baca sederhana yang sudah ada.

**State management:** Riverpod. Manfaatkan stream `watch()` milik Drift supaya
UI ikut berubah otomatis, jangan menarik data manual lalu `setState`.

---

## Perintah

```bash
# Generate ulang kode Drift setelah mengubah database.dart
dart run build_runner build --delete-conflicting-outputs

# Jalankan tes
flutter test

# Jalankan di perangkat
flutter run

# Analisa statis
flutter analyze
```

Setelah mengubah `database.dart`, **selalu** jalankan `build_runner`.
Tanpa itu, `database.g.dart` jadi usang dan errornya membingungkan.

---

## Testing

**Wajib punya tes:** semua perhitungan yang menyentuh rupiah. Salah hitung uang
adalah bug yang membuat pengguna berhenti percaya pada aplikasi.

**Tidak perlu tes:** tampilan dan widget. Di fase ini terlalu sering berubah
dan biayanya tidak sepadan.

Kasus yang wajib dijaga tetap hijau:

- Jumlah seluruh porsi split **persis sama** dengan total struk, tanpa selisih
  pembulatan sepeser pun
- Pajak dan service charge dialokasikan proporsional terhadap subtotal
  tiap orang, bukan dibagi rata
- Batas periode mingguan bersifat setengah terbuka `[start, end)`
- `safeToSpendToday` tidak pernah membagi dengan nol dan tidak pernah negatif

---

## Fase Saat Ini

**MVP.** Yang sedang dibangun:

- Input manual cepat
- Daftar transaksi
- Budget mingguan
- Multi-dompet dan kategori
- Backup dan restore JSON

**Belum dibangun, jangan tambahkan tanpa diminta:**

- Scan struk / OCR (v0.2)
- Split bill di UI (v0.3) — logikanya sudah ada, UI-nya belum
- Firebase Auth dan sync Firestore (v0.4)
- Grafik tren, deteksi langganan, widget home screen (v0.5)

Kolom sync (`isDirty`, `updatedAt`, `deletedAt`) sudah ada di skema meski
sync belum dibangun. Ini disengaja — menambahkannya belakangan jauh lebih
mahal. Tetap isi dengan benar.

---

## Yang Perlu Ditanyakan Dulu

Berhenti dan tanya sebelum:

- Menambah dependensi baru ke `pubspec.yaml`
- Mengubah struktur tabel
- Mengubah cara `ownShare` dihitung
- Menambah fitur yang ada di daftar "belum dibangun"
- Refactor besar yang menyentuh lebih dari tiga file

---

## Konvensi Kode

- Format rupiah selalu lewat `intl`:
  `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)`
- Tanggal disimpan sebagai `DateTime` waktu lokal. Indonesia tanpa DST, tapi
  hindari `add(Duration(days: n))` untuk lompatan tanggal — pakai konstruktor
  `DateTime(y, m, d + n)`
- Rentang tanggal selalu setengah terbuka `[start, end)` supaya tidak ada
  transaksi terhitung dua kali
- Nada teks untuk pengguna: membantu, tidak menghakimi. Tulis
  "Sisa Rp 240.000 untuk 3 hari", bukan "Kamu boros!"

---

## Catatan Penting

Sebagian kode di `lib/domain/` dan `lib/data/` ditulis dalam sesi chat tanpa
pernah dikompilasi. Kemungkinan besar masih ada error kecil: impor kurang,
nama kelas hasil generate yang meleset, atau parameter Drift yang berubah di
versi terbaru.

Kalau menemukan error semacam itu, perbaiki langsung — tapi **jangan mengubah
logika bisnisnya**. Rumus split, alokasi pajak, dan aturan pembulatan sudah
diverifikasi dan ada tesnya. Perbaiki sintaksisnya, pertahankan perilakunya.
