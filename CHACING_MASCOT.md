# Chacing — Panduan Maskot & Logo

Maskot cacing untuk aplikasi **Chacing**.
Prompt ditulis dalam bahasa Inggris agar hasil model lebih konsisten.

---

## 1. Kenapa Nama Ini Bekerja

"Cha-ching" adalah bunyi mesin kasir dalam bahasa Inggris. "Cacing" adalah
hewan cacing dalam bahasa Indonesia. Satu kata, dua makna, dan maskotnya
punya alasan yang masuk akal — bukan hewan acak yang ditempelkan.

### Yang perlu diwaspadai

**Bentrok dengan kata "caching".** Ini istilah teknis yang sangat dominan di
mesin pencari. Orang yang mengetik "chacing" kemungkinan besar akan dikoreksi
otomatis ke "caching". Cara menanganinya:

- Di Play Store, tulis judul lengkap: `Chacing — Catat & Bagi Tagihan`
- Amankan kata kunci turunan: "chacing app", "aplikasi chacing", "cacing keuangan"
- Domain: `chacing.app` atau `chacing.id` lebih aman daripada `.com`
- Pertimbangkan mengamankan `caching.app` sebagai pengalihan kalau tersedia

**Pengucapan ganda.** Orang Indonesia akan membaca "ca-cing", orang asing
"cha-ching". Ini justru kekuatan — biarkan, jangan diluruskan. Jadikan bahan
cerita di halaman About.

**Cek merek** di [pdki-indonesia.dgip.go.id](https://pdki-indonesia.dgip.go.id)
sebelum melangkah lebih jauh.

---

## 2. Prinsip Penting: Maskot ≠ Ikon Aplikasi

Ini kesalahan yang paling sering terjadi. Kamu butuh **dua aset berbeda**:

| | Ikon aplikasi | Maskot |
|---|---|---|
| Fungsi | Dikenali di home screen | Menemani pengguna di dalam app |
| Ukuran | Sekecil 48px | 200px ke atas |
| Detail | Satu bentuk, tanpa wajah | Wajah, ekspresi, pose |
| Isi | Siluet cacing yang disederhanakan | Karakter utuh |

Maskot bermata dan bermulut akan jadi gumpalan tak terbaca di 48px. Jadi:
**ikon = bentuk cacing yang disederhanakan, maskot = karakter penuh.**

---

## 3. Desain Karakter

### Anatomi

Cacing tidak punya tangan dan kaki, dan itu justru keuntungan: bentuknya
sederhana dan mudah dijaga konsisten. Emosi disampaikan lewat **lengkungan
tubuh dan mata**, bukan gestur tangan.

- Tubuh: tabung beruas dengan ujung membulat, 5–7 ruas terlihat
- Mata: dua titik hitam sederhana. Tanpa alis — lengkungan tubuh yang bicara
- Mulut: garis kecil, sering dihilangkan saja
- Tanpa tangan. Kalau benar-benar perlu memegang sesuatu, tubuhnya melengkung
  mengelilingi benda itu
- **Tanpa topi, dasi, atau kacamata.** Aksesori membuat karakter sulit dijaga
  konsisten dan tidak menambah apa pun

### Warna

**Opsi A — Cacing koral, antarmuka hijau** *(rekomendasi)*
Maskot menonjol di atas antarmuka hijau aplikasi.

```
Maskot   #FB7185  koral lembut
Perut    #FECDD3  merah muda pucat
Mata     #1C1917
UI       #10B981  hijau zamrud
Latar    #F8FAFC
```

**Opsi B — Cacing hijau, satu keluarga warna**
Lebih menyatu, terasa lebih tenang, tapi maskot kurang menonjol.

```
Maskot   #34D399
Perut    #A7F3D0
Mata     #0F172A
Aksen    #FBBF24
Latar    #F8FAFC
```

---

## 4. Langkah Pertama: Model Sheet

**Kerjakan ini sebelum apa pun.** Nano Banana Pro bisa menjaga konsistensi
karakter kalau diberi gambar acuan. Hasilkan satu lembar acuan dulu, lalu
lampirkan sebagai referensi di setiap generate berikutnya. Tanpa ini, setiap
gambar akan menghasilkan cacing yang berbeda.

```
Character model sheet for a cute cartoon worm mascot named Chacing.
Show the same character in three views on one sheet: front view,
three-quarter view, and side view, standing upright in a gentle
S-curve. The worm has a soft segmented tube body with rounded ends,
about six visible segments, coral pink #FB7185 body with a pale pink
#FECDD3 belly stripe. Two simple black dot eyes, no eyebrows, tiny
smile. No arms, no legs, no accessories, no hat. Clean flat vector
illustration style with bold outlines, friendly and approachable,
suitable for a finance app. Plain off-white background, evenly lit,
no shadow, no text labels.
```

Simpan hasil terbaik sebagai `chacing-reference.png`. Lampirkan di semua
prompt selanjutnya dengan kalimat:

> *Use the attached image as the character reference. Keep the exact same
> body shape, proportions, segment count, colors, and face style.*

---

## 5. Ikon Aplikasi

Empat konsep, diurutkan dari yang paling saya rekomendasikan.

### Ikon 1 — Cacing Melingkar Jadi Koin ⭐

Tubuh cacing melingkar penuh membentuk lingkaran, kepala bertemu ekor.
Terbaca sebagai koin, cincin, sekaligus cacing. Siluetnya paling kuat.

```
Minimalist flat vector app icon: a simple worm curled into a complete
circle, head meeting tail, forming a ring like a coin. Segmented tube
body with six visible segments, hollow center. Two tiny dot eyes on
the head. Coral pink #FB7185 body on off-white background. Bold thick
shapes, geometric, centered with generous padding. Flat design, no
gradient, no shadow, no text, no lettering.
```

### Ikon 2 — Cacing Berbentuk Huruf C ⭐

Tubuh melengkung membentuk huruf C dari kata Chacing. Berfungsi sebagai
monogram sekaligus karakter.

```
Minimalist flat vector app icon: a worm curved into the shape of the
letter C, thick uniform body width, rounded terminals, six visible
segments. Two small dot eyes at the top terminal. Coral pink #FB7185
on off-white background. Bold geometric letterform, centered, flat
design. No additional text, no gradient, no shadow, no outline.
```

### Ikon 3 — Cacing dengan Ruas Tujuh Hari

Tubuh melingkar dengan tepat tujuh ruas, empat berwarna penuh dan tiga pucat.
Ruasnya mewakili hari dalam seminggu dan sisa budget.

```
Minimalist flat vector app icon: a worm curled into a ring with exactly
seven distinct body segments separated by thin gaps. Four segments
filled solid coral #FB7185, three segments pale pink #FECDD3. Two tiny
dot eyes on the head segment. Hollow center, off-white background.
Geometric, precise, flat design, centered. No text, no numbers,
no gradient, no shadow.
```

**Catatan:** tujuh ruas berisiko terlalu ramai di 48px. Uji dulu; kalau gagal,
pakai Ikon 1.

### Ikon 4 — Cacing Muncul dari Struk

Kepala cacing menyembul dari balik lembar struk. Menyampaikan fitur scan,
tapi paling ramai dari keempatnya.

```
Minimalist flat vector app icon: a small worm head peeking out from
behind a simple receipt shape with a zigzag torn bottom edge. Only the
head and two body segments visible. Coral pink #FB7185 worm, white
receipt with emerald green #10B981 outline, off-white background.
Bold shapes, flat design, centered. No text, no lettering, no gradient,
no shadow.
```

---

## 6. Ekspresi untuk Status Budget

Ini bagian paling berguna. Maskot menyampaikan status budget tanpa perlu
kalimat yang menghakimi.

**Aturan nada:** cacing ini **tidak pernah marah atau kecewa pada pengguna.**
Saat budget jebol, dia ikut sedih, bukan menegur. Aplikasi keuangan yang
menyalahkan penggunanya akan dihapus dalam seminggu.

### Nyaman — pengeluaran santai

```
[LAMPIRKAN GAMBAR ACUAN]
Same worm character, standing in a relaxed upright S-curve, eyes closed
in a happy arc, small content smile, body slightly bouncing. Cheerful
and calm. Flat vector illustration, plain off-white background,
no shadow, no text.
```

### Aman — sesuai rencana

```
Same worm character, upright neutral posture, simple open dot eyes,
small friendly smile, calm and steady. Flat vector illustration,
plain off-white background, no shadow, no text.
```

### Terlalu cepat — laju pengeluaran tinggi

```
Same worm character, body leaning forward with a slight wobble, eyes
open wide with mild concern, small worried mouth, one body segment
raised as if pausing. Concerned but gentle, not angry, not scolding.
Flat vector illustration, plain off-white background, no shadow, no text.
```

### Jebol — budget habis

```
Same worm character, body slumped and drooping into a low curve, eyes
looking down softly, small sympathetic frown. Sad and deflated but
still warm and supportive, never angry or judgmental. Flat vector
illustration, plain off-white background, no shadow, no text.
```

### Merayakan — target tercapai

```
Same worm character, body arched upward in a joyful curve, eyes closed
in happy arcs, wide smile, small sparkle marks around it. Celebratory
and warm. Flat vector illustration, plain off-white background,
no shadow, no text.
```

---

## 7. Ilustrasi untuk Layar Kosong

Layar kosong adalah kesan pertama pengguna baru. Jangan biarkan polos.

### Belum ada transaksi

```
Same worm character sitting curled beside a single blank receipt,
looking up with curious open eyes and a small smile, one body segment
resting on the receipt edge. Friendly and inviting. Flat vector
illustration, plain background, generous white space, no shadow, no text.
```

### Sedang memindai struk

```
Same worm character curved into an arc over a receipt, eyes focused
downward on it as if reading carefully, small concentrated expression.
Flat vector illustration, plain background, no shadow, no text.
```

### Bagi tagihan

```
Three copies of the same worm character in different sizes, arranged
side by side around a shared receipt, each looking at it with friendly
open eyes. Same character design for all three, only scale differs.
Flat vector illustration, plain background, no shadow, no text.
```

### Belum ada teman tersimpan

```
Same worm character waving one raised body segment in greeting, looking
slightly to the side with a warm smile, standing beside an empty
dotted-outline circle. Flat vector illustration, plain background,
no shadow, no text.
```

---

## 8. Ide Antarmuka yang Muncul dari Maskot

Ini bukan prompt, tapi cara memakai maskotnya sebagai elemen fungsional.
Ide-ide inilah yang membuat maskot terasa menyatu, bukan tempelan.

**Cacing sebagai progress bar.** Panjang tubuh cacing di layar utama mewakili
sisa budget minggu ini. Awal minggu dia panjang dan tegak, akhir minggu
memendek. Kalau jebol, tubuhnya melorot. Ini menyampaikan angka tanpa angka.

**Ruas tubuh sebagai hari.** Tujuh ruas, satu ruas memudar tiap hari berlalu.

**Cacing menarik struk.** Animasi saat OCR sedang berjalan: cacing menarik
lembar struk masuk ke layar.

**Bunyi "cha-ching".** Suara halus saat transaksi tersimpan. Ini menyambungkan
nama, maskot, dan pengalaman pakai jadi satu. Buat pelan dan bisa dimatikan —
orang mencatat pengeluaran di tempat umum.

---

## 9. Negative Prompt Universal

Tempelkan di akhir setiap prompt kalau hasilnya melenceng:

```
no arms, no legs, no hands, no feet, no hat, no glasses, no clothing,
no accessories, no realistic worm, no earthworm photograph, no slimy
texture, no soil, no dirt, no apple, no snake, no caterpillar,
no antennae, no text, no letters, no watermark, no gradient,
no drop shadow, no 3D render, no glossy highlight, no multiple
variations in one image, no grid of options
```

Tiga yang paling penting: **no realistic worm** (mencegah hasil menjijikkan),
**no caterpillar** (model sering menambahkan kaki dan antena), dan
**no grid of options** (model sering mengeluarkan enam varian dalam satu kisi).

---

## 10. Urutan Kerja

1. Generate **model sheet** dulu. Ulangi sampai dapat karakter yang kamu suka.
   Semua bergantung pada langkah ini.
2. Simpan sebagai gambar acuan, lampirkan di setiap generate berikutnya.
3. Generate **empat konsep ikon**, uji di 48px sebelum menilai apa pun.
4. Generate **lima ekspresi** untuk status budget.
5. Generate **empat ilustrasi layar kosong**.
6. **Vektorkan** ikon terpilih jadi SVG. Wajib — hasil AI berupa raster dan
   akan pecah di ukuran besar.
7. Ekspor: Android adaptive 108×108 dp, Play Store 512×512 px,
   iOS 1024×1024 px tanpa alpha.

Kalau di langkah 1 karakternya belum terasa pas, jangan lanjut. Memperbaiki
karakter setelah dua puluh ilustrasi jadi berarti mengulang semuanya.
