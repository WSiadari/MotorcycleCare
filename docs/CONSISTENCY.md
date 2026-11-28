# Pemetaan Diagram ke Kode

Dokumen ini memetakan elemen pada [`diagrams/MotorcycleCare.drawio`](diagrams/MotorcycleCare.drawio) ke layar,
class, method, dan tabel database MotorcycleCare.

## 1. Konvensi penamaan

| Hal | Acuan | Contoh |
|---|---|---|
| Nama sistem | MotorcycleCare | judul setiap halaman diagram, README, aplikasi |
| Aktor | Motorcycle Owner, Mechanic, Admin | `UserRole.owner.label` = "Motorcycle Owner" |
| Nama class | Class Diagram = `lib/models/models.dart` | `MotorcycleCatalog`, `ServiceRecord`, `ServiceReceipt`, `MaintenanceStatus` |
| Nama tabel dan kolom | `supabase/schema.sql` = ERD | `motorcycles.plate_number` |
| Nama field Dart | kolom dalam camelCase | `plate_number` → `Motorcycle.plateNumber`, `catalog_id` → `catalogId` |
| Nama method dan parameter | kode | `updateOdometer(m, valueKm)` di Class Diagram, Sequence Diagram, dan `AppState` |
| Status | `MaintenanceStatus { onTrack, dueSoon, overdue }` | `reminders.due_status check ('dueSoon','overdue')` |

## 2. Use Case Diagram

| Use case | Aktor | Layar | Method / data |
|---|---|---|---|
| Register Account | Owner, Mechanic, Admin | `auth/register_screen.dart` | `AppState.register(...)` → `Backend.signUp(...)` → RPC `register_role` |
| Login | Owner, Mechanic, Admin | `auth/login_screen.dart` | `AppState.login(email, password)` → `Backend.signIn` |
| Manage Motorcycles | Owner | `owner/motorcycles_screen.dart`, `owner/add_motorcycle_screen.dart` | `myMotorcycles`, `selectMotorcycle`, `addMotorcycle` |
| Update Odometer | Owner | `owner/update_odometer_screen.dart` | `updateOdometer(m, valueKm)`, `confirmOdometer(m)` |
| View Odometer History | Owner | `owner/odometer_history_screen.dart` | `readingsFor(m)`, `firstReadingOf(m)` |
| View Maintenance Schedule «include» Calculate Maintenance Status | Owner | `owner/dashboard_screen.dart`, `owner/component_detail_screen.dart` | `statusesFor(m)` |
| View Component Status «include» Calculate Maintenance Status | Owner | `owner/component_status_screen.dart` | `statusOf(m, rule)` |
| Calculate Maintenance Status «include» Determine Maintenance Interval | (sistem) | — | `ComponentStatus.calculate(...)`, `ruleFor(m, componentKey)` |
| Receive Maintenance Reminder «include» Calculate Maintenance Status | Owner | `owner/sheets.dart` (`showReminders`) | `syncReminders(m)`, `remindersFor(m)`, `markReminderRead(r)` |
| Manage Profile & Notification Settings | Owner | `owner/profile_screen.dart` | `updateMyProfile(fullName, phone, …, notificationEnabled)` |
| Rate Mechanic Service | Owner | `owner/history_screen.dart`, `owner/sheets.dart` (`showRateMechanic`) | `canRate(r)`, `rateMechanic(record, rating, comment)` |
| View Maintenance History | Owner, Mechanic | `owner/history_screen.dart`, `mechanic/mech_flow.dart` (`MechHistoryScreen`) | `recordsFor(m)`, `myServices` |
| Record Maintenance | Owner, Mechanic | `owner/record_maintenance_screen.dart`, `mechanic/mech_flow.dart` | `saveRecord(...)`, `saveService(d)` |
| Attach Service Receipt «extend» Record Maintenance | — | dua layar di atas dan `AttachReceiptScreen` | `ServiceReceipt.validateFile(fileName, sizeBytes)` |
| Notify Owner «extend» Record Maintenance | (Mechanic) | `ReviewServiceScreen` (switch Notify owner) | `saveService(d)` → `saveRecord(…, syncReminders: d.notifyOwner)` |
| Search Motorcycle | Mechanic | `mechanic/mechanic_shell.dart` (`SearchTab`) | `findByPlate(plateNumber)` |
| Add Motorcycle for Customer «extend» Search Motorcycle | (Mechanic) | `NotFoundScreen` → `AddMotorcycleScreen` (mechanic) | `addMotorcycle(…, ownerId)`, `owners` |
| View Motorcycle Information «include» Search Motorcycle | Mechanic | `MotorcycleInfoScreen` | `motorcycleById`, `ownerOf(m)`, `statusesFor(m)` |
| Manage Service Jobs | Mechanic | `_JobsTab` | `todaysJobs`, `startJob(m, note)`, `openJobFor(m)` |
| View Service Statistics & Overdue Flags | Mechanic | `mechanic/mech_more.dart` (Done Today, This Week, This Month, Services Completed, Overdue Flags) | `doneToday`, `thisWeek`, `thisMonth`, `servicesBetween`, `overdueFlags` |
| View Reviews & Rating | Mechanic | `ReviewsScreen` | `reviews`, `rating` |
| Edit Personal Info & Workshop | Mechanic | `PersonalInfoScreen`, `WorkshopScreen` | `updateMyProfile(fullName, phone, workshopName)`, `workshop` |
| Manage Users | Admin | `admin/admin_shell.dart` (`_UsersTab`), `admin/admin_forms.dart` (`UserFormScreen`) | `addUser`, `saveUser`, `deleteUser` |
| Manage Motorcycle Catalog | Admin | `_CatalogTab`, `ModelFormScreen` | `saveModel`, `deleteModel` |
| Manage Maintenance Rules | Admin | `_RulesTab`, `RuleFormScreen` | `saveRule`, `deleteRule` |
| View System Report / Export Report (CSV) «extend» | Admin | `admin/admin_reports.dart` | `loadSystemReport()`, `SystemReport.toCsv()` |
| View Recent Changes | Admin | Admin Home "Recent changes", `showAdminNotifications` | `activity` (activity_logs) |

## 3. Class Diagram

| Class | File | Tabel | Keterangan |
|---|---|---|---|
| Role | `lib/models/models.dart` | `roles` | Data tetap (3 baris dari `schema.sql`); `Role.of(roleName)`. Role tidak dikelola dari aplikasi. |
| UserRole «enumeration» | models.dart | `roles.role_name` | owner, mechanic, admin |
| UserAccount «sealed» | models.dart | `user_accounts` | Tidak ada field password; password disimpan Supabase Auth (`auth.users`). `roleId` diturunkan dari subclass. |
| MotorcycleOwner / Mechanic / Admin | models.dart | `motorcycle_owners` / `mechanics` / `admins` | `notificationEnabled`, `workshop` (FK `workshop_id`), `staffCode` |
| Workshop | models.dart | `workshops` | `closesAt` diturunkan dari `hours` |
| MotorcycleCatalog, MotorcycleType | models.dart | `motorcycle_catalog` | |
| MaintenanceRule | models.dart | `maintenance_rules` | `sourceReference`; harga contoh untuk nota demo ada di `MockData.samplePrice` |
| Motorcycle | models.dart | `motorcycles` | `applyReading(r)` sama dengan trigger `on_odometer_reading` |
| OdometerReading | models.dart | `odometer_readings` | `validate(m, valueKm)` |
| ServiceRecord ◆— 1..* ServiceRecordItem | models.dart | `service_records`, `service_record_items` | `/componentKey` di-join dari `maintenance_rules` |
| ServiceReceipt (0..1) | models.dart | `service_receipts` dan bucket `receipts` | `validateFile` adalah satu-satunya validasi file nota |
| Reminder → MaintenanceStatus | models.dart | `reminders` | `fromStatus(m, s, now)`, `sameKey(other)` = unique key tabel |
| MaintenanceStatus «enumeration» | models.dart | `reminders.due_status` | onTrack, dueSoon, overdue |
| ComponentStatus «result» | models.dart | — | hasil `calculate(...)`, tidak disimpan |
| ServiceJob, JobStatus | models.dart | `service_jobs` | |
| Review | models.dart | `reviews` | `/ownerName` di-join |
| ActivityLog | models.dart | `activity_logs` | |
| SystemReport «result» | models.dart | — | `build(users, catalog, rules, now)`, `toCsv()` |
| ServiceDraft «form state» | models.dart | — | isian form servis mekanik |
| AppState «controller» | `lib/state/app_state.dart` | — | method mechanic dan admin ada di extension `MechanicState` / `AdminState` |
| Backend «interface», MockBackend, SupabaseBackend | `lib/data/` | — | |
| ReminderNotifier «interface», LocalReminderNotifier, SilentReminderNotifier | `lib/services/` | — | |

## 4. Activity Diagram – Motorcycle Owner

| Langkah | Layar / method |
|---|---|
| Open MotorcycleCare → Already have an account? | `WelcomeScreen` |
| Register Account → Registration valid? → Create User Account / Show Registration Error | `RegisterScreen._submit` → `AppState.register` |
| Log In → Login successful? → Show Login Error | `LoginScreen._submit` → `AppState.login` |
| Manage Motorcycles → Motorcycle already registered? → Select / Add → Motorcycle valid? → Save | `MotorcyclesScreen`, `AddMotorcycleScreen` → `validatePlate`, `addMotorcycle` |
| Motorcycle Dashboard → Open profile & settings? → Edit Name / Phone & Maintenance Reminders → Save | `DashboardScreen` → `OwnerProfileScreen` → `updateMyProfile` |
| Update odometer? → Update Odometer → Odometer valid? → Save / Use Latest → Confirm Current Odometer | `UpdateOdometerScreen` → `validateOdometer`, `updateOdometer`, `confirmOdometer`, `confirmOdometerSheet` |
| View odometer history? → View Odometer History | `OdometerHistoryScreen` |
| Retrieve Maintenance Rules → Determine Interval → Calculate Maintenance Status | `rulesFor(m)`, `ruleFor`, `statusOf` → `ComponentStatus.calculate` |
| View Maintenance Schedule → View Component Status | `DashboardScreen`, `ComponentStatusScreen`, `ComponentDetailScreen` |
| View maintenance history? → Rate the mechanic? → Rate Mechanic Service | `HistoryScreen` → `showRateMechanic` → `rateMechanic` |
| Maintenance due soon or overdue? → Save Reminder → Maintenance reminders switched on? → Show Local Notification → Receive Maintenance Reminder | `syncReminders(m)` → `Backend.addReminders` → `ReminderNotifier.show`; `showReminders` |
| Perform → Record Maintenance → Attach service receipt? → Save Maintenance Record → Update Maintenance Schedule | `RecordMaintenanceScreen` → `ServiceReceipt.validateFile` → `saveRecord` → `MaintenanceSavedScreen` |
| Continue using the application? → Log Out | `showLogOut` → `AppState.logout` |

## 5. Activity Diagram – Mechanic

| Langkah | Layar / method |
|---|---|
| Open → account? → Register / Log In (sama dengan owner, ditambah nama bengkel) | `RegisterScreen` (role Mechanic + workshop) |
| Mechanic Dashboard → Open a job from Today's Jobs? → Select Job | `MechanicShell._HomeTab`, `_JobsTab` |
| Search Motorcycle → Motorcycle Found? | `SearchTab._search` → `findByPlate` |
| Motorcycle Not Found → Register it for the customer? → Add Motorcycle for Customer / No (Search Again) | `NotFoundScreen` → `AddMotorcycleScreen` → `MotorcycleAddedScreen` |
| View Motorcycle Information → View maintenance history? → View Maintenance History | `MotorcycleInfoScreen` → `MechHistoryScreen` |
| Inspect & Repair Motorcycle → Record Service Details | `startJob(m, note)`, `InspectScreen`, `ServiceDetailsScreen` |
| Attach Service Receipt? → Attach / Skip | `AttachReceiptScreen` (`ServiceReceipt.validateFile`) |
| Review Service → Service Record Complete? → Correct Service Details | `ReviewServiceScreen`, `serviceIssues(app, d)`, `ServiceDetailsScreen(correcting: true)` |
| Save Service Record → Notify owner switched on? → Update Owner's Reminders → Service Record Saved | `saveService(d)` → `saveRecord(…, syncReminders: d.notifyOwner)` → `ServiceSavedScreen` |
| Continue Using Application? → Log Out | `_ProfileTab` → `logout` → `LoggedOutScreen` |

## 6. Activity Diagram – Admin

| Langkah | Layar / method |
|---|---|
| Register Admin Account → Registration valid? (staff code) | `RegisterScreen` → `register(…, staffCode)` → `private.register_role` |
| Admin Dashboard → View Recent Changes & Notifications | `AdminShell._HomeTab`, `showAdminNotifications` → `activity` |
| Choose Module → [Users] / [Motorcycle Catalog] / [Maintenance Rules] → View → Add / Edit / Delete → Save Changes | `_UsersTab`/`UserFormScreen`, `_CatalogTab`/`ModelFormScreen`, `_RulesTab`/`RuleFormScreen` |
| [Reports] → View System Report → Share report as CSV? → Share Report (CSV) | `ReportsScreen` → `loadSystemReport()` → `SystemReport.toCsv()` → share_plus |
| Return to Admin Dashboard → Manage Another Module? → Log Out | `AdminShell`, `_logOut` |

## 7. Sequence Diagram

Lifeline: aktor, `:Screen (Flutter UI)`, `:AppState «controller»`, `:Motorcycle`, `OdometerReading`, `ServiceReceipt`,
`ComponentStatus`, `Reminder`, `:ReminderNotifier`, `SystemReport`, `:Backend «interface»`, dan Supabase.

| Bagian | Pesan utama |
|---|---|
| 1. Register Account | `register(fullName, email, password, role, workshopName, staffCode)` → `signUp(...)` → `auth.signUp` → trigger `on_auth_user_created` → `rpc('register_role', …)` / `rpc('discard_new_account')` |
| 2. Login | `login(email, password)` → `signIn(email, password)` → `loadCatalog()` · `loadMotorcycles(ownerId)` · `loadOdometerReadings(motorcycleIds)` · `loadServiceRecords(motorcycleIds)` · `loadReminders(motorcycleIds)` · `loadReviews(mechanicId, ownerId)` → `syncReminders(m)` |
| 3. Register Motorcycle | `validatePlate(v)`, `addMotorcycle(catalogId, plateNumber, odometerKm, ownerId)` → `Backend.addMotorcycle(ownerId, catalogId, plateNumber, odometerKm)` → trigger `on_motorcycle_created` |
| 4. Update Odometer & Schedule | `updateOdometer(m, valueKm)` → `OdometerReading.validate(m, valueKm)` → `addOdometerReading(motorcycleId, valueKm, recordedBy)` → `applyReading(r)`; `statusesFor(m)` → loop `ComponentStatus.calculate(rule, currentKm, baseKm, baseDate, lastRecord, today)` |
| 5. Record Maintenance & Receipt | `validateFile(fileName, sizeBytes)` → `saveRecord(motorcycle, serviceDate, odometerKm, items, workshopName, receipt, syncReminders)` → `addServiceRecord(record)` → upload `<record_id>/<file>` (rollback bila gagal) |
| 6. Admin Management | `addUser`/`saveUser`/`deleteUser` (Edge Functions, RPC `admin_update_user`), `saveModel`/`saveCatalogModel`, `saveRule`, `loadSystemReport()` → `SystemReport.build(...)` → `toCsv()`, `addActivityLog(log)` |
| 7. Reminder Notification | `syncReminders(m)`: `statusesFor(m)` → loop `Reminder.fromStatus(m, s, now)` → `sameKey(other)` → `addReminders(reminders)` → alt `notificationEnabled` → `ReminderNotifier.show(reminder, title)`; `markReminderRead(r)` → `markReminderRead(reminderId, readAt)` |
| 8. Mechanic History | `findByPlate(plateNumber)` → alt not found / found → `recordsFor(m)` · `statusesFor(m)` · `ownerOf(m)` → opt `receiptUrl(receipt)` |

## 8. ERD dan schema.sql

Tabel dan kolom pada ERD sama dengan `supabase/schema.sql`, termasuk urutan kolom, tipe SQL (uuid, bigint,
smallint, int, text, boolean, timestamptz, date), PK/FK/UQ, nilai `check`, dan unique gabungan. Relasi memakai
notasi crow's foot dengan multiplicity `1`, `0..1`, `0..*`, dan `1..*`.

| Tabel | Class | Data store DFD | Trigger / fungsi terkait |
|---|---|---|---|
| roles, user_accounts, motorcycle_owners, mechanics, admins, staff_codes | Role, UserAccount, MotorcycleOwner, Mechanic, Admin | D1 | `on_auth_user_created`, `private.register_role`, `private.set_user_role`, `private.admin_update_user`, `private.update_my_profile`, `private.discard_new_account` |
| workshops | Workshop | D12 | `private.find_or_create_workshop` |
| motorcycle_catalog | MotorcycleCatalog | D3 | |
| maintenance_rules | MaintenanceRule | D4 | |
| motorcycles | Motorcycle | D2 | `on_motorcycle_created` (bacaan odometer pertama) |
| odometer_readings | OdometerReading | D7 | `before_odometer_reading` (nilai tidak boleh turun), `on_odometer_reading` (`current_odometer`) |
| service_records, service_record_items | ServiceRecord, ServiceRecordItem | D5 | `on_service_item_created` (menghapus reminder komponen yang diservis) |
| service_receipts | ServiceReceipt | D8 | storage policy `can_read_receipt_object` / `can_write_receipt_object` |
| reminders | Reminder | D6 | unique (motorcycle_id, rule_id, due_status) |
| service_jobs | ServiceJob | D9 | |
| reviews | Review | D10 | policy: hanya owner yang motornya pernah diservis mekanik tersebut |
| activity_logs | ActivityLog | D11 | |

`auth.users` (Supabase Auth) dan bucket `receipts` digambar sebagai catatan, bukan sebagai tabel `public`.

## 9. DFD

Data store (nama sama di Level 1 dan Level 2, tabel ditulis di dalam kurung):
D1 User Accounts · D2 Motorcycle Data · D3 Motorcycle Catalog · D4 Maintenance Rules · D5 Service Records ·
D6 Reminders · D7 Odometer Readings · D8 Service Receipts · D9 Service Jobs · D10 Reviews · D11 Activity Logs ·
D12 Workshops.

| Proses Level 1 | Kode | Store |
|---|---|---|
| 1.0 Register / Login Account (1.1 Validate Registration Data, 1.2 Create User Account, 1.3 Verify Login Credentials, 1.4 Send Account Confirmation, 1.5 Update Profile & Notification Settings) | `register`, `login`, `restoreSession`, `updateMyProfile`; `Backend.signUp/signIn/updateProfile`; RPC `register_role`, `update_my_profile` | D1, D11, D12 |
| 2.0 Manage Motorcycles (2.1 Validate, 2.2 Save, 2.3 Provide Information, 2.4 Search by Plate) | `validatePlate`, `addMotorcycle`, `findByPlate`, `Backend.addMotorcycle`, `loadOwners` | D1, D2, D3, D7 |
| 3.0 Update Odometer (3.1 Validate, 3.2 Save, 3.3 Send Update, 3.4 Provide History) | `OdometerReading.validate`, `updateOdometer`, `confirmOdometer`, `readingsFor`, `Backend.addOdometerReading` | D2, D7 |
| 4.0 Manage Maintenance Schedule & Status (4.1–4.3 status, 4.4 Generate Reminder, 4.5 Reminders & Mark as Read) | `statusesFor`, `ComponentStatus.calculate`, `syncReminders`, `ReminderNotifier.show`, `remindersFor`, `markReminderRead` | D1, D2, D4, D5, D6, D7 |
| 5.0 Record Maintenance & Service Receipt (5.1 Validate, 5.2 Save, 5.3 Attach Receipt) | `minServiceOdometer`, `serviceIssues`, `saveRecord`, `saveService`, `ServiceReceipt.validateFile`, `Backend.addServiceRecord`, `saveJob` | D2, D5, D7, D8, D9 |
| 6.0 View History & Component Status (6.1–6.4, 6.5 Compute Service Statistics) | `recordsFor`, `myServices`, `statusOf`, `overdueFlags`, `doneToday/thisWeek/thisMonth`, `receiptUrl` | D2, D4, D5, D7, D8 |
| 7.0 Administer System Data (7.1 Users, 7.2 Catalog, 7.3 Rules, 7.4 Generate System Report, 7.5 Recent Changes) | `addUser/saveUser/deleteUser` (Edge Functions dan RPC), `saveModel/deleteModel`, `saveRule/deleteRule`, `loadSystemReport`, `activity`/`addActivityLog` | D1, D3, D4, D11, D12 |
| 8.0 Manage Service Jobs & Reviews (tanpa halaman Level 2) | `todaysJobs`, `startJob`, `saveJob`, `reviews`, `rating`, `rateMechanic`, `Backend.addReview/loadReviews` | D5, D9, D10 |

DFD Level 0 memiliki 41 alur eksternal. Setiap alur muncul di Level 1 dengan label yang sama pada proses yang
menanganinya, dan alur proses 1.0–7.0 muncul lagi di halaman Level 2 masing-masing. Entitas dan data store dapat
digambar lebih dari sekali pada satu halaman agar garis tidak bersilangan.

## 10. Catatan desain

1. **Field mengikuti kolom.** Field Dart memakai nama kolom dalam camelCase (`catalogId`, `plateNumber`,
   `currentOdometer`, `odometerKm`, `serviceDate`, `workshopName`, `sourceReference`, `modelYear`,
   `motorcycleType`). Id bertipe String di Dart (uuid atau bigint di database).
2. **Role.** `UserAccount` adalah sealed class dengan subclass `MotorcycleOwner`, `Mechanic`, dan `Admin`. Password
   tidak disimpan di model; data demo menyimpannya di `MockData.passwords`.
3. **Registrasi Mechanic dan Admin.** Setiap akun baru dibuat sebagai Owner oleh trigger. Setelah sign-up, aplikasi
   memanggil RPC `register_role` (wrapper security invoker untuk `private.register_role`, security definer). Fungsi
   ini memeriksa nama bengkel atau staff code di `staff_codes`, dan hanya berlaku untuk akun baru (kurang dari
   30 menit, belum memiliki motor). Bila pemeriksaan gagal, `discard_new_account` menghapus akun tersebut sehingga
   email dapat dipakai lagi. Role tidak pernah dibaca dari metadata sign-up.
4. **Pengelolaan user oleh Admin.** Penambahan user melalui Edge Function `admin-create-user`, perubahan melalui RPC
   `admin_update_user` (satu transaksi), dan penghapusan melalui Edge Function `admin-delete-user`. Service role key
   hanya tersedia di Edge Function, tidak di aplikasi. Admin tidak dapat mengubah role atau menonaktifkan akunnya
   sendiri.
5. **Perubahan role.** Owner yang masih memiliki motor tidak dapat diganti role-nya (FK `motorcycles.owner_id` →
   `motorcycle_owners`). Aturan ini berlaku di backend demo dan di database.
6. **Odometer.** Setiap update atau konfirmasi menyimpan satu baris `odometer_readings`. Bacaan pertama dibuat
   trigger saat motor didaftarkan, dan `current_odometer` diperbarui oleh trigger. Status komponen yang belum pernah
   diservis dihitung dari bacaan pertama.
7. **Reminder.** Reminder disimpan setelah status dihitung: saat login, saat odometer disimpan, dan saat servis
   disimpan. Unique key (motor, aturan, status) mencegah duplikat, sehingga dueSoon dan overdue menjadi dua reminder
   terpisah. Servis pada sebuah komponen menghapus reminder komponen itu (trigger). Notifikasi bersifat lokal di
   perangkat owner; switch "Notify owner" pada mekanik memperbarui reminder owner secara langsung.
8. **Nota servis.** `ServiceReceipt.validateFile` menerima JPG, PNG, WEBP, dan HEIC dengan ukuran maksimal 5 MB;
   bucket `receipts` menerapkan batas yang sama. File baru disimpan di `<record_id>/<file>`. Policy baca mencari
   baris `service_receipts` melalui `storage_path`, sehingga nota dari skema versi 1 tetap dapat dibuka. Mekanik
   hanya dapat membaca nota yang ia catat sendiri.
9. **Item servis** mereferensikan `rule_id` dengan `on delete restrict`, sehingga aturan yang sudah dipakai di
   riwayat tidak dapat dihapus.
10. **Review.** Owner dapat menilai mekanik yang pernah mencatat servis pada motornya (Rate Mechanic Service).
    Syarat ini juga diperiksa oleh policy database.
11. **Proses 8.0** (Manage Service Jobs & Reviews) merupakan proses primitif di Level 1, tanpa halaman Level 2.
12. **Activity log.** Recent changes pada dashboard Admin diambil dari `activity_logs`, yang berisi perubahan oleh
    admin serta registrasi mechanic dan admin yang dicatat oleh server.

## 11. Batasan

- Registrasi Mechanic dan Admin membutuhkan sesi login tepat setelah sign-up, sehingga opsi **Confirm email** di
  Supabase Auth harus dimatikan.
- `discard_new_account` menghapus baris `auth.users` dari fungsi security definer. Bila hak tersebut tidak tersedia
  pada project Supabase, akun tetap ada sebagai Owner dan pesan error tetap ditampilkan.
- Tidak ada push notification ke perangkat owner saat mekanik menyimpan servis. Reminder tetap tersimpan dan tampil
  di aplikasi owner.
- Scan nomor plat dengan kamera belum tersedia; plat dimasukkan secara manual.
