# Chacing — Kandidat Fitur

Daftar fitur yang mungkin dibangun berikutnya, beserta alasan kenapa
sebagian di antaranya sebaiknya **tidak** dibangun.

Dokumen ini bukan janji. Isinya bahan pertimbangan, dan sebagian besar
seharusnya berakhir sebagai keputusan "tidak usah".

---

## Cara membaca daftar ini

Setiap kandidat dinilai dengan tiga pertanyaan:

| Kolom | Artinya |
|---|---|
| **Nilai** | Seberapa sering ini menyelamatkan pengguna dari kejengkelan nyata |
| **Biaya** | Perkiraan waktu bangun, termasuk tes dan perbaikan setelahnya |
| **Risiko** | Apa yang rusak kalau fiturnya salah, dan seberapa sunyi rusaknya |

Risiko lebih penting daripada yang terlihat. Fitur yang salah hitung uang
tidak sekadar mengganggu — ia menghapus kepercayaan pada seluruh angka di
aplikasi, termasuk angka yang benar.

**Aturan yang dipakai di sini:** satu fitur baru harus lebih berharga
daripada memperbaiki satu keluhan dari daftar pemakaian sehari-hari.
Hampir selalu, memperbaiki keluhan menang.

---

## Sudah selesai

Ditulis di sini supaya tidak dibangun dua kali.

- Catat manual dengan papan angka sendiri, kategori sekali ketuk
- Daftar transaksi per hari dengan subtotal, geser untuk hapus
- Budget harian, mingguan, atau bulanan, dengan rollover
- "Aman dipakai hari ini" dan indikator laju
- Ringkasan per kategori, tren enam bulan, deteksi langganan
- Bagi tagihan dengan penugasan per item
- Scan struk lewat Gemini dengan kunci API milik pengguna
- Multi-dompet, pindah dana, saldo per dompet
- Cari dan saring transaksi
- Cadangkan dan pulihkan JSON
- Tema terang dan gelap

---

## Layak dipertimbangkan

### 1. Rekap utang lintas transaksi

**Nilai: tinggi · Biaya: 3–4 hari · Risiko: sedang**

Sekarang porsi tiap orang hanya terlihat di dalam satu tagihan. Kalau
patungan dengan orang yang sama lima kali sebulan, tidak ada satu tempat
pun yang menjawab "Budi total utang berapa".

Datanya sudah ada seluruhnya — tabel `payments` dan `assignments` sudah
menyimpannya sejak awal. Yang belum ada cuma layar yang menjumlahkan per
orang dan tombol untuk menandai lunas.

> **Ini kandidat terkuat di seluruh daftar.** Fitur bagi tagihan tanpa
> rekap utang menyelesaikan setengah pekerjaan: menghitung memang sudah
> benar, tapi menagihnya masih diingat sendiri di kepala.

### 2. Transaksi berulang otomatis

**Nilai: sedang · Biaya: 2–3 hari · Risiko: tinggi**

Pendeteksi langganan sudah bisa menebak mana yang berulang. Langkah
berikutnya: menawarkan mencatatnya otomatis tiap bulan.

Risikonya justru di situ. Transaksi yang muncul sendiri tanpa disadari
akan membuat angka budget bergerak tanpa sebab yang terlihat, dan
pengguna kehilangan kepercayaan pada seluruh angkanya.

Kalau dibangun: **tawarkan, jangan buat sendiri.** Pemberitahuan "Spotify
biasanya tertagih hari ini, catat sekarang?" jauh lebih aman daripada
baris yang muncul diam-diam.

### 3. Anggaran per kategori

**Nilai: sedang · Biaya: 2 hari · Risiko: rendah**

Kolom `categoryId` di tabel `budgets` sudah disiapkan tapi belum dipakai.
Batas khusus untuk "Makan" atau "Hiburan" adalah permintaan yang wajar.

Tapi hati-hati: tujuh angka yang harus diatur satu per satu jauh lebih
mudah ditinggalkan daripada satu angka yang dipahami. Kalau dibangun,
biarkan tetap opsional dan jangan pernah wajibkan saat pemasangan awal.

### 4. Widget layar utama

**Nilai: sedang · Biaya: 3–4 hari · Risiko: rendah**

Satu angka di layar utama HP: sisa budget hari ini. Tanpa membuka
aplikasi sama sekali.

Ini satu-satunya fitur di daftar yang membuat aplikasi **lebih jarang**
dibuka, dan itu justru tandanya berhasil. Butuh kode Android asli, jadi
biayanya lebih tinggi dari kelihatannya.

### 5. Ekspor CSV

**Nilai: rendah–sedang · Biaya: setengah hari · Risiko: rendah**

Cadangan JSON sudah menyelamatkan data, tapi tidak bisa dibuka di Excel.
Beberapa orang ingin mengolah sendiri.

Murah sekali dibangun. Tapi tanyakan dulu apakah ada yang benar-benar
memintanya — ini jenis fitur yang terdengar berguna dan tidak pernah
dipakai.

---

### 6. Membaca struk tanpa API — ML Kit dan aturan sendiri

**Nilai: sedang · Biaya: 1–2 minggu · Risiko: sedang**

Alternatif kalau tidak mau bergantung pada kunci API Gemini, atau kalau
foto struk tidak boleh keluar dari HP sama sekali.

`google_mlkit_text_recognition` berjalan di perangkat, gratis, tanpa
internet, tanpa kunci. Yang diberikannya cuma teks mentah beserta kotak
posisinya — mengubah itu jadi item dan nominal adalah pekerjaan sendiri.

Struk Indonesia lebih teratur daripada kelihatannya: nominal rata kanan
dengan pemisah titik, dan kata kuncinya berulang — `PPN`, `PB1`, `Pajak`,
`Subtotal`, `Total`, `Tunai`, `Kembali`. Kotak posisi dipakai untuk
memasangkan nama item di kiri dengan harganya di kanan.

Kelemahannya rapi di awal lalu menua: setiap format struk baru butuh
aturan baru, dan ekornya tidak pernah habis.

> **Gabungan yang paling masuk akal:** ML Kit membaca teksnya di HP, lalu
> hanya **teksnya** yang dikirim ke model bahasa — bukan fotonya. Jauh
> lebih murah, bisa dipakai penyedia mana pun, dan yang keluar dari HP
> jadi jauh lebih sedikit.

---

## Dinilai dan ditolak

### Melatih model pembaca struk sendiri

**Nilai: rendah · Biaya: 1–3 bulan · Risiko: tinggi**

Terdengar seperti jawaban yang benar. Setelah dihitung, tidak.

Membaca huruf dari gambar sudah selesai dipecahkan orang lain — bagian
itu tidak perlu dilatih sama sekali. Yang sulit adalah mengubah teks jadi
`{merchant, item, harga, pajak, total}`.

Untuk itu keluarganya sudah ada: LayoutLMv3, Donut, LiLT. Datanya pun
kebetulan berpihak — **CORD, kumpulan data struk standar, isinya struk
Indonesia**, sekitar seribu lembar beranotasi dan terbuka untuk umum.

Yang membunuhnya adalah tiga hal:

| Hambatan | Kenyataannya |
|---|---|
| Pelabelan | 2–5 menit per struk. 300 struk berarti 15–25 jam, **setelah** mengumpulkan 300 struknya dulu — berbulan-bulan makan di luar |
| Penyebaran | LayoutLM sekitar 500 MB. Mengubahnya ke TFLite jarang mulus, jadi ujungnya tetap butuh server — persis yang mau dihindari dengan tidak memakai API |
| Ketepatan | Gemini membaca struk kusut dan gelap tanpa dilatih. Model kecil hasil latihan sendiri bagus di format yang pernah dilihat, lalu jatuh di format baru |

Latihannya sendiri justru bagian termurah: Colab gratis, beberapa jam.

Ambangnya kejam. Ketepatan 85% terdengar lumayan sampai disadari artinya
15% struk membawa angka salah ke catatan keuangan seseorang.

Bangun ini hanya kalau Chacing jadi produk dengan banyak pengguna, bukan
aplikasi untuk dipakai sendiri.

---

## Ditunda dengan sengaja

### Sync antar perangkat

**Nilai: tinggi · Biaya: 2–3 minggu · Risiko: sangat tinggi**

Seluruh skema sudah disiapkan untuk ini: `isDirty`, `updatedAt`,
`deletedAt`, id UUID, dan waktu disimpan sebagai teks supaya cukup halus
untuk resolusi konflik.

Tetap ditunda. Sync adalah bagian tersulit di aplikasi mana pun, dan
untuk satu pengguna dengan satu HP nilainya nol. Bangun kalau HP kedua
benar-benar dipakai, bukan sebelumnya.

### Beberapa mata uang

Ditunda tanpa batas waktu. Menambahkan mata uang berarti setiap nominal
di seluruh aplikasi butuh konteks tambahan, dan setiap penjumlahan jadi
pertanyaan "dalam mata uang apa". Biayanya menyebar ke mana-mana.

### Foto struk tersimpan di dalam aplikasi

Kolom `receiptPhotoPath` sudah terisi, tapi fotonya belum ditampilkan di
mana pun. Menambah galeri struk berarti mengurus ukuran penyimpanan,
pembersihan berkas yatim, dan ukuran cadangan. Tunggu sampai ada yang
benar-benar mencarinya.

---

## Sebaiknya tidak dibangun

Semuanya terasa masuk akal. Itulah kenapa perlu ditulis.

| Fitur | Kenapa tidak |
|---|---|
| Gamifikasi, lencana, runtutan hari | Mencatat pengeluaran bukan permainan. Runtutan yang putus membuat orang berhenti sama sekali, bukan mulai lagi |
| Skor kesehatan keuangan | Satu angka yang menghakimi, tanpa memberi tahu apa yang harus dilakukan |
| Impor rekening bank otomatis | Butuh kredensial bank pengguna. Risikonya tidak sepadan untuk aplikasi pribadi |
| Berbagi ke media sosial | Tidak ada yang mau memamerkan pengeluarannya |
| Asisten AI di dalam aplikasi | Menjawab pertanyaan yang bisa dijawab satu grafik, dengan biaya per pertanyaan |
| Onboarding bertingkat | Aplikasinya sudah bisa dipakai tanpa dijelaskan. Kalau tidak, perbaiki aplikasinya |
| Iklan | Aplikasi keuangan berisi data paling pribadi yang dipunya seseorang |

---

## Yang lebih penting daripada semua di atas

**Pakai sendiri dua minggu penuh dulu.**

Daftar keluhan dari pemakaian sungguhan lebih berharga daripada seluruh
dokumen ini. Setiap kali merasa terganggu, atau malas membuka aplikasi,
catat alasannya. Itulah peta jalan yang sebenarnya.

Kandidat di atas hanya tebakan. Keluhan sendiri adalah bukti.
