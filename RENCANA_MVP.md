# Chacing — Rencana ke MVP

Rencana pengembangan bertahap dan daftar peralatan untuk aplikasi pencatat
keuangan **Chacing**.

Asumsi: satu orang, sambilan, sekitar 10–15 jam per minggu.

---

## 1. Definisi MVP

MVP bukan "versi dengan fitur seadanya". MVP adalah **versi terkecil yang
sudah bisa menjawab satu pertanyaan penting**.

Pertanyaan untuk Chacing:

> Apakah aku sendiri mau membuka aplikasi ini setiap hari selama dua minggu
> berturut-turut tanpa memaksa diri?

Kalau jawabannya tidak, fitur scan dan split bill tidak akan menyelamatkan
apa pun. Kalau jawabannya ya, dua fitur itu akan membuatnya jauh lebih baik.

### Ukuran keberhasilan MVP

- Kamu mencatat minimal 10 transaksi per minggu, dua minggu berturut-turut
- Mencatat satu pengeluaran memakan waktu di bawah 10 detik
- Kamu tahu sisa budget mingguanmu tanpa membuka kalkulator

Kalau ketiganya tercapai, lanjut ke fase berikutnya. Kalau tidak, perbaiki
alur input dulu — jangan tambah fitur.

---

## 2. Ruang Lingkup

### Masuk MVP

- Catat pengeluaran manual: nominal, merchant, kategori, dompet, tanggal
- Daftar transaksi dengan pengelompokan per hari
- Edit dan hapus transaksi
- Budget mingguan: tetapkan jumlah, lihat sisa, lihat "aman dipakai hari ini"
- Multi-dompet: tunai, e-wallet, bank
- Kategori bawaan yang bisa diedit
- Ringkasan pengeluaran per kategori
- Backup dan restore ke file JSON

### Ditunda ke setelah MVP

| Fitur | Ditunda ke | Alasan |
|---|---|---|
| Scan struk | v0.2 | Butuh API key, biaya, dan backend proxy |
| Split bill | v0.3 | Butuh manajemen orang dan UI penugasan item |
| Login & sync | v0.4 | Paling rumit, tidak dibutuhkan satu pengguna |
| Maskot beranimasi | v0.5 | Kosmetik |
| Deteksi langganan berulang | v0.5 | Butuh data historis dulu |
| Widget home screen | v0.5 | Enak dipunya, bukan penentu |
| Grafik tren bulanan | v0.5 | Belum ada data yang layak digrafikkan |

### Jangan dibangun sama sekali di MVP

Ini daftar penting. Semuanya terasa perlu tapi tidak.

- Onboarding bertingkat dengan banyak layar
- Halaman pengaturan yang lengkap
- Mode gelap *(pakai `ThemeMode.system` saja, gratis)*
- Beberapa mata uang
- Ekspor PDF
- Analitik pengguna
- Iklan atau monetisasi

---

## 3. Jadwal Bertahap

Total sekitar **6 minggu** untuk MVP, lalu 6 minggu lagi untuk fitur andalan.

### Minggu 0 — Persiapan (2–3 hari)

- Pasang Flutter SDK, jalankan `flutter doctor` sampai bersih
- Buat proyek, siapkan Git dan repo privat di GitHub
- Pasang dependensi dasar
- Jalankan `flutter run` di HP asli, pastikan hot reload bekerja

**Selesai kalau:** aplikasi kosong berjalan di HP-mu dan hot reload lancar.

---

### Minggu 1 — Fondasi Data

- Salin `database.dart`, jalankan `build_runner`, pastikan tabel tercipta
- Salin `split_calculator.dart` dan `budget_period.dart`
- Jalankan `flutter test` — semua tes harus hijau
- Salin `transaction_repository.dart`, perbaiki error kompilasi
- Buat seeding awal: kategori bawaan, dompet tunai, baris orang "saya"
- Pasang state management, hubungkan repository

**Selesai kalau:** kamu bisa menyimpan transaksi lewat kode dan membacanya
kembali, dibuktikan dengan tes.

> **Catatan:** kode yang dibuat di sesi chat belum pernah dikompilasi.
> Sisihkan waktu untuk membereskan error kecil — import kurang, nama kelas
> hasil generate yang meleset. Ini normal.

---

### Minggu 2 — Layar Input Cepat

Ini layar terpenting di seluruh aplikasi. Kerjakan dengan serius.

- Papan angka besar khusus nominal, bukan keyboard sistem
- Pemilih kategori berupa deretan ikon, satu ketukan
- Pemilih dompet, tanggal default hari ini
- Tombol simpan besar di area jempol
- Format rupiah otomatis saat mengetik: `25000` → `Rp 25.000`

**Selesai kalau:** kamu bisa mencatat pengeluaran dalam **di bawah 10 detik**,
diukur dengan stopwatch sungguhan.

---

### Minggu 3 — Daftar & Beranda

- Daftar transaksi dikelompokkan per hari dengan subtotal harian
- Geser untuk hapus, ketuk untuk edit
- Beranda: sisa budget minggu ini, "aman dipakai hari ini", transaksi terakhir
- Keadaan kosong yang ramah

**Selesai kalau:** kamu bisa melihat seluruh pengeluaran minggu ini dalam satu
layar tanpa menggulir.

---

### Minggu 4 — Budget & Ringkasan

- Layar atur budget: jumlah mingguan, hari mulai minggu, rollover
- Indikator laju: nyaman, sesuai rencana, terlalu cepat, jebol
- Ringkasan per kategori dengan batang sederhana
- Navigasi antar minggu

**Selesai kalau:** angka di layar cocok dengan hitungan manualmu di kertas.

---

### Minggu 5 — Backup & Rapikan

- Ekspor seluruh data ke JSON lewat share sheet
- Impor dari JSON dengan konfirmasi
- Ikon aplikasi dan splash screen dari maskot
- Perbaiki bug yang menumpuk

**Selesai kalau:** kamu bisa memindahkan semua data ke HP lain dan kembali
tanpa kehilangan apa pun.

---

### Minggu 6 — Pakai Sendiri 🎯

**Jangan tambah fitur apa pun.** Pakai aplikasinya setiap hari selama dua
minggu penuh. Catat setiap kali kamu merasa terganggu, dan setiap kali kamu
malas membuka aplikasi.

Daftar keluhan itu adalah peta jalanmu berikutnya — jauh lebih berharga
daripada tebakan apa pun yang bisa dibuat sekarang.

---

### Setelah MVP

**v0.2 Scan struk (2 minggu)** — kamera dan galeri, kompres, kirim ke Gemini,
layar konfirmasi hasil, tandai item yang meragukan.

**v0.3 Split bill (2 minggu)** — kelola daftar orang, tugaskan item, hitung
porsi, rekap utang, bagikan sebagai gambar ke WhatsApp.

**v0.4 Login & sync (2 minggu)** — Firebase Auth, sync Firestore, tangani
konflik. Ini bagian tersulit; jangan diremehkan.

---

## 4. Peralatan

### Wajib

| Alat | Fungsi | Biaya |
|---|---|---|
| **Flutter SDK** | Kerangka aplikasi | Gratis |
| **Android Studio** | Android SDK, emulator, debugger | Gratis |
| **VS Code** | Editor harian, lebih ringan | Gratis |
| **Git + GitHub** | Riwayat versi, repo privat | Gratis |
| **HP Android** | Uji sungguhan, wajib untuk kamera | Punya sendiri |
| **Figma** | Rancang layar sebelum ngoding | Gratis |

Pakai Android Studio untuk hal berat — emulator, inspeksi database, profiling —
dan VS Code untuk menulis kode sehari-hari. Keduanya berbagi proyek yang sama.

### Paket Dart untuk MVP

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Database lokal
  drift: ^2.20.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4

  # Manajemen state
  flutter_riverpod: ^2.5.1

  # Utilitas
  uuid: ^4.5.1
  intl: ^0.19.0          # format rupiah dan tanggal
  collection: ^1.18.0

  # Antarmuka
  google_fonts: ^6.2.1
  flutter_slidable: ^3.1.1   # geser untuk hapus
  fl_chart: ^0.69.0          # grafik sederhana

  # Backup
  share_plus: ^10.0.2
  file_picker: ^8.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.20.0
  build_runner: ^2.4.13
  mocktail: ^1.0.4
  flutter_lints: ^4.0.0
  flutter_launcher_icons: ^0.14.1
  flutter_native_splash: ^2.4.1
```

> Nomor versi di atas adalah patokan awal. Jalankan `flutter pub upgrade`
> setelah pemasangan pertama untuk mendapat versi terbaru yang cocok.

### Ditambahkan nanti

```yaml
# v0.2 — scan struk
image_picker: ^1.1.2
flutter_image_compress: ^2.3.0
http: ^1.2.2

# v0.3 — berbagi hasil split
screenshot: ^3.0.0

# v0.4 — login dan sync
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
google_sign_in: ^6.2.1
connectivity_plus: ^6.0.5
```

### Pilihan yang perlu dijelaskan

**Riverpod, bukan Bloc atau Provider.** Bloc menuntut banyak kode tambahan
yang tidak sepadan untuk proyek satu orang. Provider lebih sederhana tapi
tidak sekuat Riverpod dalam menangani stream dari Drift. Riverpod berpasangan
sangat baik dengan `watch()` milik Drift — data di layar ikut berubah otomatis
begitu ada transaksi baru, tanpa kode tambahan.

**Drift, bukan sqflite langsung.** Drift memberi keamanan tipe saat kompilasi,
migrasi skema yang tertata, dan stream reaktif. Menulis SQL mentah dengan
sqflite berarti setiap salah ketik nama kolom baru ketahuan saat aplikasi
berjalan.

**fl_chart untuk grafik.** Cukup untuk kebutuhanmu dan ringan. Jangan pakai
pustaka grafik berat di MVP.

**intl itu wajib.** Format rupiah bukan hal sepele: tanpa desimal, pemisah
titik ribuan. `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ',
decimalDigits: 0)` menyelesaikan semuanya.

### Untuk fase scan struk

**Gemini API** paling masuk akal karena kamu sudah memakai ekosistem Google
lewat Antigravity. Kuota gratisnya cukup untuk pemakaian pribadi, dan hasilnya
langsung berupa JSON terstruktur.

Alternatifnya `google_mlkit_text_recognition` yang berjalan sepenuhnya di
perangkat, gratis dan tanpa internet, tapi hanya memberi teks mentah. Kamu
harus menulis sendiri pengurai untuk struk Indonesia yang formatnya beragam.
Untuk MVP pribadi, Gemini jauh lebih hemat waktu.

**Penting:** jangan pernah menaruh API key di dalam aplikasi. Siapa pun bisa
membongkar APK dan mengambilnya. Pakai Cloud Functions sebagai perantara,
atau selama masih dipakai sendiri, terima risikonya dan jangan sebarkan APK-nya.

---

## 5. Biaya

| Item | Biaya | Kapan |
|---|---|---|
| Semua alat pengembangan | Rp 0 | — |
| Akun developer Play Store | ~Rp 400rb (sekali seumur hidup) | Saat mau rilis publik |
| Gemini API | Gratis dalam kuota | v0.2 |
| Firebase Spark | Gratis | v0.4 |
| Firebase Blaze | Gratis dalam kuota, wajib pasang kartu | Kalau pakai Cloud Functions |
| Domain `.app` | ~Rp 250rb/tahun | Opsional |

**Sampai MVP selesai, biayanya nol rupiah.** Uji coba ke teman bisa lewat
kirim APK langsung, belum perlu Play Store.

---

## 6. Kebiasaan yang Menyelamatkan

**Commit setiap hari, sekecil apa pun.** Kalau ada yang rusak, kamu bisa
kembali ke keadaan yang bekerja.

**Tulis tes untuk hitungan uang saja.** Jangan uji tampilan di tahap ini —
terlalu mahal dan terlalu sering berubah. Tapi setiap rumus yang menyentuh
rupiah harus punya tes, karena salah hitung uang adalah bug yang membuat orang
berhenti percaya pada aplikasi.

**Naikkan `schemaVersion` setiap kali mengubah tabel.** Lupa melakukan ini
berarti data pengguna hilang saat pembaruan. Termasuk datamu sendiri.

**Uji di HP asli, bukan emulator.** Terutama untuk merasakan kecepatan dan
kenyamanan menekan tombol.

**Jangan menyempurnakan tampilan sebelum minggu 6.** Godaannya besar, tapi
tampilan yang rapi di atas alur yang salah tetap alur yang salah.

---

## 7. Yang Dikerjakan Besok

1. Pasang Flutter SDK, jalankan `flutter doctor --android-licenses`
2. `flutter create --org com.namamu chacing`
3. Salin blok `dependencies` di atas ke `pubspec.yaml`, jalankan `flutter pub get`
4. Sambungkan HP, jalankan `flutter run`, ubah satu teks, pastikan hot reload jalan
5. Buat repo privat di GitHub, commit pertama

Kalau kelima langkah itu selesai, Minggu 0 beres dan kamu siap masuk fondasi data.
