# MotorcycleCare — Owner, Mechanic & Admin App (Flutter)

Aplikasi Android untuk pemilik motor: daftar/login, kelola motor, update odometer,
lihat status komponen, terima pengingat, dan catat servis (dengan nota opsional).
Alurnya mengikuti **User Activity Diagram** dan use case di file `.drawio` kelompok.

Bisa jalan dengan **data demo** (tanpa setup) atau dengan **Supabase** (lihat bagian 7).
Aturan servis sama dengan yang ada di app Admin.

## 1. Yang perlu dipasang
- Flutter SDK 3.22 atau lebih baru — https://docs.flutter.dev/get-started/install
- Android Studio (untuk Android SDK + emulator) atau HP Android dengan USB debugging
- VS Code + extension **Flutter** dan **Dart**

Cek dengan: `flutter doctor`

## 2. Menjalankan di VS Code
1. Ekstrak zip ini, lalu di VS Code pilih **File → Open Folder** → folder `motorcyclecare`.
2. Buka terminal VS Code (**Ctrl + `**) dan jalankan:
   ```bash
   flutter create . --platforms=android --project-name motorcyclecare
   flutter pub get
   ```
   Perintah pertama hanya membuat folder `android/`; file di `lib/` tidak ditimpa.
3. Buka `android/app/src/main/AndroidManifest.xml`, lalu tambahkan baris ini tepat di atas `<application`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
   (Dipakai untuk mengunduh font Plus Jakarta Sans di versi release.)
4. Pilih device di pojok kanan bawah VS Code (emulator / HP), lalu tekan **F5** atau jalankan `flutter run`.

## 3. Build APK
```bash
flutter build apk --release
```
Hasilnya: `build/app/outputs/flutter-apk/app-release.apk`

## 4. Akun demo
Satu aplikasi untuk tiga aktor di use case diagram. Setelah login, aplikasi membuka dashboard sesuai role.

| Role | Email | Password | Dashboard |
|---|---|---|---|
| Owner (Users/Driver) | rizky@mail.com | rizky123 | My Motorcycles → Dashboard motor |
| Mechanic | budi@mail.com | budi123 | Mechanic Dashboard (Home · Search · Jobs · Profile) |
| Admin | dina@mail.com | dina123 | Admin Dashboard (Home · Users · Catalog · Rules · Profile) |

Akun lain di data demo: andi@mail.com, siti.rahma@mail.com, maya@mail.com (owner), dimas@mail.com (mechanic),
agung@mail.com (admin), wahyu@mail.com (owner, **inactive** — tidak bisa login). Password = nama depan + `123`.

Register akun baru: pilih **Owner / Mechanic / Admin** di layar Create Account. Mechanic mengisi nama bengkel,
Admin butuh staff code (demo: `ADM-2026`).

> Database Supabase untuk semua role dikerjakan di tahap berikutnya. Untuk sekarang jalankan **tanpa** `supabase.json`
> (cukup `flutter run`), semua data memakai data demo dan kembali ke awal setiap aplikasi dibuka ulang.

## 5. Layar Figma → file
Tampilan, warna (token "MotorcycleCare Tokens"), ikon, dan teks mengikuti file Figma
**MotorcycleCare – User App Prototype**.

| Figma | Activity diagram | File |
|---|---|---|
| A1 · Welcome | Open MotorcycleCare → Already have an account? | `screens/welcome_screen.dart` |
| A3 · Create Account | Register Account → Registration valid? → Create User Account | `screens/register_screen.dart` |
| A2 / A2b · Log In | Log In → Login successful? → Show login error | `screens/login_screen.dart` |
| B0 / B1 · My Motorcycles | Manage Motorcycles → already registered? → Select | `screens/motorcycles_screen.dart` |
| B2 · Add Motorcycle | Add Motorcycle → Motorcycle valid? → Save Motorcycle | `screens/add_motorcycle_screen.dart` |
| C1 · Motorcycle Dashboard, C2 · Log Out | Motorcycle Dashboard, Log Out | `screens/dashboard_screen.dart`, `screens/sheets.dart` |
| 02 · Update Odometer, 02b/02c · Confirm | Update odometer? → Save / Use Latest → Confirm Current Odometer | `screens/update_odometer_screen.dart` |
| 01 · Component Status | Calculate Maintenance Status → View Component Status | `screens/component_status_screen.dart` |
| 04a–04f · Detail | View Maintenance Schedule | `screens/component_detail_screen.dart` |
| 05 · Reminders | Receive Maintenance Reminder | `screens/sheets.dart` |
| 03 · Maintenance History, 06 · Receipt | View Maintenance History | `screens/history_screen.dart`, `screens/sheets.dart` |
| 07a · Record Maintenance | Record Maintenance → Attach receipt? (skip/attach) | `screens/record_maintenance_screen.dart` |
| 07c · Maintenance Saved | Save Maintenance Record → Update Maintenance Schedule | `screens/maintenance_saved_screen.dart` |

Aturan status: **Due soon** saat pemakaian ≥ 80% interval (km atau bulan, mana yang lebih dulu),
**Overdue** saat ≥ 100%.

## 6. Struktur folder (mengikuti diagram draw.io)
```
lib/
  main.dart, app.dart          entry point, login tersimpan → dashboard sesuai role
  models/models.dart           class diagram: UserAccount + UserRole, CatalogModel, MaintenanceRule,
                               Motorcycle, MaintenanceRecord (ServiceRecord), Receipt, ServiceJob, Review
  data/                        Backend (interface), MockBackend (data demo), SupabaseBackend
  state/app_state.dart         logika per aktor: owner, MechanicState, AdminState
  screens/
    home_router.dart           Log In → Login successful? → dashboard Owner / Mechanic / Admin
    auth/                      Open MotorcycleCare → Already have an account? → Register / Log In
    owner/                     user activity diagram   (Figma: User App Prototype)
    mechanic/                  mechanic activity diagram (Figma: Mechanic UI Orange)
    admin/                     admin activity diagram  (Figma: Admin App)
  theme/, widgets/, utils/     token warna, komponen, ikon, format angka/tanggal
test/widget_test.dart          unit test  →  jalankan: flutter test
```

### Alur Mechanic (mechanic activity diagram)
Mechanic Dashboard → Search Motorcycle → *Motorcycle found?* — tidak: **Motorcycle Not Found** (Add Motorcycle /
Search Again) — ya: **Motorcycle Information** → View Maintenance History → **Inspect & Repair** →
**Record Service Details** → **Attach Service Receipt?** (Upload / Take Photo / Skip) → **Review Service** →
*Service record complete?* — tidak: **Correct Details** — ya: **Save Service Record** → Service Record Saved
(history di-update) → Back to Dashboard → Log Out.

### Alur Admin (admin activity diagram)
Admin Dashboard → Choose Module (**Users · Motorcycle Catalog · Maintenance Rules**) → View list →
Add / Edit / Delete → Save Changes → kembali ke dashboard (Recent changes) → Log Out.

## 7. Menghubungkan ke Supabase

Tanpa pengaturan apa pun, app memakai **data demo** (akun Rizky). Untuk memakai database Supabase:

### a. Buat project dan tabel
1. Buka https://supabase.com/dashboard → **New project** (catat password database-nya).
2. Buka **SQL Editor → New query**, salin isi `supabase/schema.sql`, lalu klik **Run**.
3. Buat query baru lagi, salin isi `supabase/seed.sql`, lalu klik **Run** (mengisi katalog motor dan aturan servis).
4. Buka **Authentication → Sign In / Providers → Email**, matikan **Confirm email**, lalu **Save**.
   Ini supaya akun baru bisa langsung login saat development. Email bawaan Supabase hanya
   mengirim ke alamat anggota tim project, jadi tanpa SMTP sendiri email konfirmasi tidak sampai.

### b. Masukkan kunci project ke app
1. Di dashboard Supabase klik **Connect** (atau **Project Settings → API Keys**).
2. Salin **Project URL** dan **Publishable key** (`sb_publishable_...`).
   Jangan pakai *secret key* / *service_role* di aplikasi.
3. Di folder project, salin `supabase.example.json` menjadi **`supabase.json`**, lalu isi:
   ```json
   {
     "SUPABASE_URL": "https://xxxx.supabase.co",
     "SUPABASE_KEY": "sb_publishable_..."
   }
   ```
4. Tambahkan baris `supabase.json` ke file `.gitignore` supaya kunci tidak ikut ter-upload ke GitHub.

### c. Jalankan
```bash
flutter pub get
flutter run --dart-define-from-file=supabase.json
```
Atau di VS Code: buka tab **Run and Debug** (Ctrl + Shift + D), pilih **MotorcycleCare (Supabase)**, lalu tekan F5.
Pilih **MotorcycleCare (demo data)** untuk kembali ke data demo.

### d. Yang tersimpan di Supabase
| Data | Tempat |
|---|---|
| Akun & login | Authentication → Users, tabel `profiles` (role: owner / mechanic / admin) |
| Katalog & aturan servis | tabel `catalog_models`, `maintenance_rules` (dikelola Admin) |
| Motor milik user | tabel `motorcycles` |
| Riwayat servis | tabel `maintenance_records` + `maintenance_record_items` |
| Foto nota | Storage → bucket `receipts` (privat, per user) |

Row Level Security aktif: setiap user hanya bisa melihat dan mengubah motor & riwayat servisnya sendiri.
Tarik layar **My motorcycles** ke bawah untuk memuat ulang data.
