# MotorcycleCare

MotorcycleCare adalah aplikasi Android untuk mencatat dan memantau perawatan motor. Aplikasi ini dipakai oleh
tiga role: **Motorcycle Owner** memantau jadwal servis tiap komponen berdasarkan odometer dan waktu,
**Mechanic** mencari motor pelanggan dan mencatat servis, dan **Admin** mengelola akun, katalog motor, serta
aturan perawatan. Status komponen menjadi *due soon* saat pemakaian mencapai 80 % interval dan *overdue* saat
mencapai 100 % (km atau bulan, mana yang lebih dulu).

## Fitur

**Motorcycle Owner**
- Registrasi dan login
- Menambah dan memilih motor dari katalog
- Update dan konfirmasi odometer, beserta riwayat bacaan odometer
- Jadwal perawatan dan status setiap komponen
- Pengingat perawatan yang tersimpan, dengan notifikasi lokal
- Mencatat perawatan beserta foto nota servis (JPG, PNG, WEBP, HEIC, maks. 5 MB)
- Riwayat perawatan, termasuk nama mekanik yang mencatat
- Memberi rating kepada mekanik yang pernah menservis motor
- Profil dan pengaturan notifikasi

**Mechanic**
- Registrasi dengan nama bengkel dan login
- Mencari motor berdasarkan nomor plat, dan mendaftarkan motor untuk pelanggan
- Antrean pekerjaan hari ini
- Inspeksi, pencatatan servis, dan lampiran nota
- Memperbarui pengingat pemilik saat servis disimpan
- Riwayat servis, statistik (hari ini, minggu ini, bulan ini) dan daftar komponen overdue
- Rating dan ulasan dari pemilik motor
- Data pribadi dan data bengkel

**Admin**
- Registrasi dengan staff code dan login
- Mengelola user (tambah, ubah, nonaktifkan, hapus)
- Mengelola katalog motor dan aturan perawatan
- Laporan sistem dengan ekspor CSV
- Daftar perubahan terbaru (*recent changes*)

## Teknologi

- Flutter dan Dart (SDK `>=3.4.0 <4.0.0`)
- Supabase: Auth, Database (PostgreSQL dengan Row Level Security), Storage, dan Edge Functions
- Package utama:
  - `supabase_flutter`: koneksi ke Supabase
  - `image_picker`: memilih foto nota
  - `flutter_local_notifications`: notifikasi pengingat
  - `share_plus`: membagikan laporan CSV
  - `google_fonts` dan `flutter_svg`: font dan ikon

## Struktur Folder

```
lib/
├── main.dart          # entry point, memilih backend demo atau Supabase
├── app.dart           # MaterialApp dan pemulihan sesi login
├── config.dart        # URL dan key Supabase dari --dart-define
├── models/            # model domain, sesuai tabel database
├── data/              # interface Backend, data demo, dan implementasi Supabase
├── state/             # AppState: state dan logika aplikasi untuk semua role
├── services/          # notifikasi pengingat lokal
├── screens/           # layar aplikasi: auth/, owner/, mechanic/, admin/
├── theme/             # warna dan tema
├── widgets/           # komponen UI dan ikon yang dipakai bersama
└── utils/             # format angka dan tanggal
supabase/
├── schema.sql         # tabel, trigger, fungsi, RLS, dan storage policy
├── seed.sql           # katalog motor, aturan perawatan, bengkel, dan staff code
├── migration_v2.sql   # migrasi dari skema versi 1
└── functions/         # Edge Functions admin-create-user dan admin-delete-user
```

## Menjalankan Aplikasi

**Prasyarat**
- Flutter SDK 3.22 atau lebih baru
- Android SDK (melalui Android Studio), dengan emulator atau perangkat Android

**Mode data demo**

```bash
flutter pub get
flutter run
```

Tanpa konfigurasi Supabase, aplikasi berjalan dengan data demo di memori. Data kembali ke kondisi awal setiap
kali aplikasi dibuka ulang.

**Build APK**

```bash
flutter build apk --release
```

File APK ada di `build/app/outputs/flutter-apk/app-release.apk`.

## Akun Demo

| Role | Email | Password |
|---|---|---|
| Motorcycle Owner | rizky@mail.com | rizky123 |
| Mechanic | budi@mail.com | budi123 |
| Admin | dina@mail.com | dina123 |

Untuk registrasi akun Admin baru, gunakan staff code `ADM-2026`. Akun demo lainnya tercantum di
`lib/data/mock_data.dart`.

## Konfigurasi Supabase (opsional)

1. Buat project baru di Supabase.
2. Di SQL Editor, jalankan `supabase/schema.sql`, lalu `supabase/seed.sql`. Untuk project yang masih memakai
   skema versi 1, jalankan `supabase/migration_v2.sql` lebih dulu.
3. Di **Authentication → Sign In / Providers → Email**, matikan **Confirm email**. Pengaturan ini dibutuhkan untuk
   registrasi Mechanic dan Admin.
4. Deploy Edge Functions:
   ```bash
   npx supabase functions deploy admin-create-user
   npx supabase functions deploy admin-delete-user
   ```
5. Salin `supabase.example.json` menjadi `supabase.json`, lalu isi `SUPABASE_URL` dan `SUPABASE_KEY` dengan
   Project URL dan *publishable key*. File `supabase.json` sudah tercantum di `.gitignore` dan tidak boleh
   di-commit.
6. Jalankan aplikasi:
   ```bash
   flutter run --dart-define-from-file=supabase.json
   ```

`.vscode/launch.json` juga menyediakan dua konfigurasi: **MotorcycleCare (Supabase)** dan
**MotorcycleCare (demo data)**.

## Dokumen Desain

- `docs/diagrams/MotorcycleCare.drawio`: use case diagram, class diagram, activity diagram (Motorcycle Owner,
  Mechanic, Admin), sequence diagram, ERD, dan DFD level 0 sampai 2.
- `docs/CONSISTENCY.md`: pemetaan elemen diagram ke layar, class, dan tabel database.
- File Figma di root repo: desain antarmuka untuk setiap role.
  - `MotorcycleCare – User App Prototype.fig`
  - `MotorcycleCare - Mechanic UI (Orange).fig`
  - `MotorcycleCare — Admin App.fig`
