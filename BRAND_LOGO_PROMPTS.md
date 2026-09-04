# Prompt Logo — Aplikasi Pencatat Keuangan

Kumpulan prompt siap pakai untuk digenerate di **Antigravity / Nano Banana Pro**.
Prompt ditulis dalam bahasa Inggris karena model gambar jauh lebih konsisten
dengan bahasa itu. Penjelasan tetap bahasa Indonesia.

---

## 1. Ringkasan Merek

Aplikasi pencatat keuangan pribadi dengan tiga fitur utama:

- Scan struk lewat foto
- Split bill yang menghitung porsi per orang
- Batas pengeluaran mingguan

**Nada yang dituju:** tenang, jujur, membantu — bukan menghakimi. Aplikasi
keuangan gampang terasa seperti guru galak. Logonya harus terasa ramah tapi
tetap dipercaya untuk memegang data uang.

**Kata kunci visual:** bersih, geometris, modern, hangat, sederhana.

**Yang dihindari:** kesan bank korporat yang kaku, gaya kripto/futuristik,
tumpukan koin klise, karung uang bergambar dolar.

### Kandidat nama

| Nama | Alasan | Catatan |
|---|---|---|
| **Sangu** | Bahasa Jawa untuk bekal/uang saku. Hangat, akrab. | Cek ketersediaan |
| **Patungan** | Langsung menyasar fitur split bill | Agak panjang untuk ikon |
| **Recehan** | Ringan, tidak menggurui | Bisa terkesan remeh |
| **Nota** | Menyasar fitur struk, pendek, mudah diingat | Umum, sulit didaftarkan |
| **Sisa** | Menyasar fitur budget: "sisa berapa" | Sangat pendek, kuat |
| **Duitku** | Jelas, familiar | Banyak dipakai, cek merek dulu |

> **Penting:** sebelum memilih, cek merek terdaftar di
> [pdki-indonesia.dgip.go.id](https://pdki-indonesia.dgip.go.id) dan
> ketersediaan nama di Play Store. Nama yang bentrok akan memaksamu
> mengulang seluruh branding setelah rilis.

---

## 2. Batasan Teknis Ikon Aplikasi

Ini menentukan konsep mana yang layak dipakai. Baca sebelum generate.

- **Harus terbaca di 48×48 px.** Semua detail halus akan hilang. Kalau konsep
  butuh garis tipis atau lebih dari tiga elemen, konsep itu gugur.
- **Tanpa teks di dalam ikon.** Nama aplikasi sudah muncul di bawah ikon pada
  home screen. Teks di ikon hanya jadi bubur di ukuran kecil.
- **Android adaptive icon:** kanvas 108×108 dp, tapi hanya **lingkaran tengah
  66 dp** yang dijamin selalu terlihat. Sisanya bisa terpotong oleh mask
  berbentuk lingkaran, kotak membulat, atau squircle tergantung peluncur.
  Jaga elemen utama di dalam 60% area tengah.
- **iOS:** kotak penuh, sudut dibulatkan otomatis oleh sistem. **Tidak boleh
  ada transparansi** — latar wajib solid.
- **Harus tetap jelas di mode gelap dan terang.** Uji dengan menempelkan ikon
  di atas latar putih dan latar hitam.
- **Satu bentuk, satu ide.** Ikon yang mencoba menyampaikan struk + kamera +
  grafik + rupiah sekaligus akan gagal di semua ukuran.

---

## 3. Palet Warna

Pilih satu, lalu pakai konsisten di semua prompt.

### Palet A — Hijau Tenang *(rekomendasi)*
Hijau membawa makna "aman, cukup, tumbuh" tanpa agresivitas.

```
Primary   #10B981   hijau zamrud
Deep      #065F46   hijau tua untuk kontras
Accent    #FBBF24   kuning hangat untuk sorotan
Ink       #0F172A   hampir hitam
Surface   #F8FAFC   putih tulang
```

### Palet B — Biru Terpercaya
Aman, familiar untuk aplikasi finansial, tapi paling mudah tertukar dengan app lain.

```
Primary   #2563EB
Deep      #1E3A8A
Accent    #F97316
Ink       #111827
Surface   #F9FAFB
```

### Palet C — Jingga Hangat
Paling menonjol di antara ikon lain di home screen. Cocok kalau ingin nada
ramah dan tidak formal.

```
Primary   #F97316
Deep      #9A3412
Accent    #0EA5E9
Ink       #1C1917
Surface   #FFFBEB
```

---

## 4. Konsep Logo

Sepuluh konsep, diurutkan dari yang paling saya rekomendasikan.
Tiap konsep punya prompt teks dan versi JSON.

---

### Konsep 1 — Struk yang Menjadi Grafik Naik ⭐

**Ide:** bagian bawah struk yang bergerigi berubah jadi batang grafik.
Menggabungkan "catat" dan "pantau" dalam satu bentuk.

**Kenapa bagus:** ide tunggal yang jelas, siluetnya kuat di ukuran kecil.

```
Minimalist flat vector app icon: a simple receipt shape with a
zigzag torn bottom edge, where the torn edge transforms into three
ascending bar chart columns. Geometric, bold shapes, thick strokes,
no thin lines. Solid emerald green #10B981 on off-white background.
Centered composition with generous padding. Flat design, no gradient,
no shadow, no text, no lettering. Clean vector logo style suitable
for a mobile app icon.
```

```json
{
  "subject": "receipt with torn zigzag bottom edge morphing into three ascending bar chart columns",
  "style": "flat minimalist vector logo, geometric, bold thick shapes",
  "colors": { "primary": "#10B981", "background": "#F8FAFC" },
  "composition": "centered, generous padding, single focal element",
  "constraints": ["no text", "no gradient", "no shadow", "no thin lines"],
  "output": "square app icon, 1024x1024"
}
```

**Variasi:** balik warnanya — struk putih di atas kotak hijau penuh.

---

### Konsep 2 — Lingkaran Terbagi Tidak Rata ⭐

**Ide:** lingkaran dipotong menjadi tiga bagian dengan ukuran berbeda, dipisah
celah tipis. Langsung membaca sebagai "split bill" sekaligus donut chart.

**Kenapa bagus:** paling bersih dari semua konsep, sangat kuat di 48px,
dan makna gandanya kebetulan pas dengan aplikasi.

```
Minimalist flat vector app icon: a circle divided into three unequal
segments separated by thin white gaps, like a simple donut chart with
a hollow center. Segments in three tones of emerald green: #10B981,
#065F46, and #6EE7B7. Off-white background. Perfectly centered,
geometric precision, flat design. No text, no lettering, no gradient,
no shadow, no drop shadow. Clean modern app icon.
```

```json
{
  "subject": "circle split into three unequal segments with thin separating gaps, hollow center",
  "style": "flat geometric vector logo, precise, modern",
  "colors": { "segments": ["#10B981", "#065F46", "#6EE7B7"], "background": "#F8FAFC" },
  "composition": "perfectly centered, symmetrical padding",
  "constraints": ["no text", "no gradient", "no shadow"],
  "output": "square app icon, 1024x1024"
}
```

**Variasi:** buat satu segmen berwarna kuning aksen sebagai "porsimu".

---

### Konsep 3 — Struk di Dalam Bingkai Kamera ⭐

**Ide:** sudut bingkai kamera (empat siku di pojok) mengapit siluet struk kecil.
Menyampaikan fitur andalan: memotret struk.

```
Minimalist flat vector app icon: four bold corner brackets forming a
camera viewfinder frame, with a small simple receipt shape centered
inside. Thick geometric strokes, high contrast. Emerald green #10B981
brackets and receipt on off-white background. Flat design, generous
padding, centered. No text, no lettering, no gradient, no shadow,
no realistic camera body.
```

```json
{
  "subject": "camera viewfinder corner brackets framing a small receipt silhouette",
  "style": "flat vector logo, bold thick strokes, high contrast",
  "colors": { "primary": "#10B981", "background": "#F8FAFC" },
  "constraints": ["no text", "no gradient", "no shadow", "no camera body"],
  "output": "square app icon, 1024x1024"
}
```

---

### Konsep 4 — Cincin Tujuh Segmen

**Ide:** cincin yang terbagi tujuh, mewakili tujuh hari dalam seminggu.
Beberapa segmen terisi, sisanya kosong — menggambarkan budget mingguan.

```
Minimalist flat vector app icon: a circular ring divided into seven
equal segments with small gaps between them. Four segments filled
solid emerald green #10B981, three segments filled pale green #D1FAE5.
Hollow center, off-white background. Geometric, precise, flat design.
Centered with even padding. No text, no numbers, no gradient, no shadow.
```

**Catatan:** tujuh segmen mungkin terlalu ramai di 48px. Uji dulu; kalau
gagal, kurangi jadi lima segmen dan korbankan makna harfiahnya.

---

### Konsep 5 — Koin yang Terbelah

**Ide:** lingkaran koin dengan garis belah vertikal yang sedikit bergeser,
seperti dua bagian yang dipisahkan.

```
Minimalist flat vector app icon: a simple circular coin split into two
halves by a vertical gap, with the left half shifted slightly upward.
Bold geometric shapes, no coin details or ridges. Emerald green #10B981
and deep green #065F46 halves on off-white background. Flat design,
centered, generous padding. No text, no currency symbol, no gradient,
no shadow, no metallic texture.
```

---

### Konsep 6 — Dompet Terlipat Membentuk Panah

**Ide:** siluet dompet dengan lipatan yang membentuk panah naik.

```
Minimalist flat vector app icon: a simple folded wallet silhouette
where the fold line forms an upward-pointing arrow. Bold geometric
shapes, thick strokes. Emerald green #10B981 on off-white background.
Flat design, centered composition. No text, no stitching details,
no gradient, no shadow, no realistic leather texture.
```

---

### Konsep 7 — Gelembung Struk

**Ide:** struk digambar seperti gelembung percakapan, menyiratkan bahwa
aplikasi ini "berbicara" tentang pengeluaranmu dengan ramah.

```
Minimalist flat vector app icon: a rounded speech bubble shape with a
zigzag torn bottom edge like a paper receipt. Soft rounded corners,
bold single-color fill. Warm orange #F97316 on cream background.
Flat design, centered, generous padding. No text, no lettering,
no gradient, no shadow.
```

---

### Konsep 8 — Tiga Titik Terhubung

**Ide:** tiga lingkaran berukuran berbeda dihubungkan garis, mewakili
orang-orang yang berbagi satu tagihan.

```
Minimalist flat vector app icon: three circles of different sizes
connected by thick straight lines forming a triangle arrangement.
The largest circle filled emerald green #10B981, the two smaller ones
in deep green #065F46. Off-white background, flat geometric design,
centered. No text, no faces, no human figures, no gradient, no shadow.
```

---

### Konsep 9 — Monogram Huruf Awal

**Ide:** huruf pertama nama aplikasi dibentuk dari garis lipatan struk.
Ganti `[HURUF]` dengan inisial nama pilihanmu.

```
Minimalist flat vector app icon: the letter [HURUF] constructed from
bold geometric strokes, where one stroke ends in a zigzag torn edge
like a receipt. Single letter only, heavy weight, custom geometric
letterform. Emerald green #10B981 on off-white background. Centered,
flat design, generous padding. No additional text, no gradient,
no shadow, no outline.
```

**Catatan:** ini satu-satunya konsep yang memakai huruf, dan itu boleh karena
huruf tunggal tetap terbaca di ukuran kecil. Kata utuh tidak.

---

### Konsep 10 — Bentuk "Rp" yang Disederhanakan

**Ide:** ligatur R dan p yang sangat disederhanakan menjadi satu bentuk
geometris. Paling lokal rasanya.

```
Minimalist flat vector app icon: a highly simplified geometric ligature
of the letters R and p merged into one continuous bold shape, abstract
enough to read as a symbol rather than text. Thick uniform strokes,
rounded terminals. Emerald green #10B981 on off-white background.
Centered, flat design. No gradient, no shadow, no serif details.
```

**Catatan:** paling berisiko. Bisa terbaca sebagai simbol yang kuat, bisa juga
terbaca sebagai huruf berantakan. Generate banyak variasi sebelum menilai.

---

## 5. Prompt Pendukung

### Logo horizontal (untuk splash screen dan header)

```
Horizontal lockup logo: [KONSEP ICON] positioned on the left, with the
wordmark "[NAMA APP]" on the right in a clean geometric sans-serif
typeface, medium weight, generous letter spacing. Icon height matches
cap height of the text. Emerald green icon, dark ink #0F172A wordmark,
off-white background. Balanced spacing, professional, flat vector.
```

### Versi satu warna (untuk watermark dan cetak)

```
[KONSEP ICON], rendered entirely in solid black on pure white
background. No color, no gradient, no shadow. Pure silhouette,
suitable for single-color printing and stamping.
```

### Ikon notifikasi Android

Android memaksa ikon notifikasi jadi siluet putih, jadi bentuknya harus
tetap terbaca tanpa warna sama sekali.

```
[KONSEP ICON] as a pure white silhouette on transparent background,
simplified to essential shapes only, no inner details, no color.
Must remain legible at 24x24 pixels.
```

---

## 6. Negative Prompt Universal

Tempelkan ini di akhir setiap prompt kalau hasilnya masih berantakan:

```
no text, no letters, no words, no numbers, no watermark, no signature,
no gradient, no drop shadow, no 3D rendering, no glossy reflection,
no bevel, no emboss, no photorealistic texture, no stock photo look,
no cluttered details, no thin hairlines, no mockup, no device frame,
no multiple variations in one image, no grid of options
```

Baris terakhir penting. Model sering mengeluarkan satu gambar berisi enam
varian logo dalam kisi, dan itu tidak bisa dipakai.

---

## 7. Alur Kerja yang Disarankan

1. **Pilih satu palet warna** dan pakai konsisten. Membandingkan konsep jadi
   mustahil kalau warnanya berbeda-beda.
2. **Generate 4 konsep teratas dulu**, masing-masing 4 variasi. Jangan generate
   sepuluh konsep sekaligus — kamu akan kewalahan menilai.
3. **Uji ukuran kecil segera.** Perkecil hasil ke 48px dan lihat di HP. Ini
   langkah yang paling sering dilewati dan paling sering menyelamatkan.
4. **Uji di antara ikon lain.** Tempel di screenshot home screen-mu. Logo yang
   bagus sendirian bisa hilang di antara ikon lain.
5. **Vektorkan pemenangnya.** Hasil AI berupa raster. Jiplak ulang jadi SVG di
   Figma, Inkscape, atau Illustrator supaya tajam di semua ukuran dan bisa
   diedit. Ini wajib, bukan opsional.
6. **Ekspor ukuran yang dibutuhkan:**
   - Android adaptive: foreground + background 108×108 dp
   - Play Store: 512×512 px PNG
   - iOS: 1024×1024 px PNG tanpa alpha
   - App Store dan Play Store menolak ikon dengan sudut yang sudah dibulatkan
     sendiri — kirim kotak penuh, sistem yang membulatkan

---

## 8. Catatan Hukum

Jangan meminta model meniru logo aplikasi keuangan yang sudah ada. Selain
berisiko melanggar merek dagang, hasilnya juga membuat aplikasimu terlihat
seperti tiruan. Semua prompt di file ini sengaja dirumuskan sebagai bentuk
geometris orisinal.

Setelah logo final dipilih, pertimbangkan mendaftarkan merek di DJKI,
terutama kalau kamu berencana merilis ke publik.
