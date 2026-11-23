import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'backend.dart';

/// Reads and writes MotorcycleCare data in Supabase (Auth, Database, Storage).
/// Tables and policies are created by supabase/schema.sql.
class SupabaseBackend implements Backend {
  SupabaseClient get _db => Supabase.instance.client;

  static const _receiptBucket = 'receipts';

  /// Mechanic and admin tables are added in the next database step.
  static const _later = 'Mechanic and admin accounts are not connected to the database yet. '
      'Run the app without supabase.json to try them with demo data.';

  @override
  bool get isDemo => false;

  // ---------------------------------------------------------------- auth
  @override
  Future<UserAccount?> restoreSession() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    return _profileOf(user);
  }

  Future<UserAccount> _profileOf(User user) async {
    final row = await _db
        .from('profiles')
        .select('full_name, email, role, workshop_name, active')
        .eq('id', user.id)
        .maybeSingle();
    final metaName = user.userMetadata?['full_name'] as String?;
    return UserAccount(
      id: user.id,
      role: UserRole.values.asNameMap()[row?['role'] as String? ?? 'owner'] ?? UserRole.owner,
      workshopName: row?['workshop_name'] as String?,
      active: row?['active'] as bool? ?? true,
      fullName: (row?['full_name'] as String?)?.isNotEmpty == true ? row!['full_name'] as String : (metaName ?? ''),
      email: user.email ?? (row?['email'] as String? ?? ''),
    );
  }

  @override
  Future<UserAccount> signIn(String email, String password) async {
    try {
      final res = await _db.auth.signInWithPassword(email: email.trim(), password: password);
      return _profileOf(res.user!);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login credentials')) {
        throw const BackendException('Email or password is incorrect. Please try again.');
      }
      if (m.contains('email not confirmed')) {
        throw const BackendException('Confirm your email first. Open the link we sent to your inbox, then log in.');
      }
      throw BackendException(e.message);
    }
  }

  @override
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    UserRole role = UserRole.owner,
    String? workshopName,
    String? staffCode,
  }) async {
    if (role != UserRole.owner) throw const BackendException(_later);
    try {
      final res = await _db.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      if (res.session != null) {
        // Activity diagram: Create User Account → Log In (the user logs in themselves).
        await _db.auth.signOut();
        return false;
      }
      return true; // email confirmation is switched on in Supabase Auth
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') || m.contains('already exists')) {
        throw const BackendException('An account with this email already exists. Log in instead.');
      }
      throw BackendException(e.message);
    }
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  // ---------------------------------------------------------------- catalog
  @override
  Future<(List<CatalogModel>, List<MaintenanceRule>)> loadCatalog() async {
    final cats = await _db.from('catalog_models').select().order('id');
    final rules = await _db.from('maintenance_rules').select().order('id');
    return (
      cats.map((r) => CatalogModel(
            id: '${r['id']}',
            make: r['make'] as String,
            model: r['model'] as String,
            type: MotoType.values.byName(r['motorcycle_type'] as String),
            year: r['model_year'] as int,
          )).toList(),
      rules.map((r) => MaintenanceRule(
            id: 'R-${r['id']}',
            catalogId: '${r['catalog_id']}',
            componentKey: r['component_key'] as String,
            componentName: r['component_name'] as String,
            intervalKm: r['interval_km'] as int,
            intervalMonths: r['interval_months'] as int,
            source: r['source_reference'] as String? ?? '',
          )).toList(),
    );
  }

  // ---------------------------------------------------------------- motorcycles
  Motorcycle _moto(Map<String, dynamic> r) => Motorcycle(
        id: r['id'] as String,
        ownerId: r['owner_id'] as String,
        catalogId: '${r['catalog_id']}',
        plate: r['plate'] as String,
        odometer: r['odometer'] as int,
        odometerUpdatedAt: DateTime.parse(r['odometer_updated_at'] as String),
        registrationOdometer: r['registration_odometer'] as int,
        registeredAt: DateTime.parse(r['registered_at'] as String),
      );

  @override
  Future<List<Motorcycle>> loadMotorcycles(String userId) async {
    final rows = await _db.from('motorcycles').select().eq('owner_id', userId).order('created_at');
    return rows.map(_moto).toList();
  }

  @override
  Future<Motorcycle> addMotorcycle({
    required String ownerId,
    required String catalogId,
    required String plate,
    required int odometer,
  }) async {
    try {
      final row = await _db
          .from('motorcycles')
          .insert({
            'owner_id': ownerId,
            'catalog_id': int.parse(catalogId),
            'plate': plate,
            'odometer': odometer,
            'registration_odometer': odometer,
          })
          .select()
          .single();
      return _moto(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw BackendException('Plate $plate is already registered in MotorcycleCare.');
      throw BackendException('Could not save the motorcycle (${e.message}).');
    }
  }

  @override
  Future<void> updateOdometer(String motorcycleId, int odometer, DateTime date) async {
    await _db
        .from('motorcycles')
        .update({'odometer': odometer, 'odometer_updated_at': _date(date)})
        .eq('id', motorcycleId);
  }

  // ---------------------------------------------------------------- records
  @override
  Future<List<MaintenanceRecord>> loadRecords(List<String> motorcycleIds) async {
    if (motorcycleIds.isEmpty) return [];
    final rows = await _db
        .from('maintenance_records')
        .select('*, maintenance_record_items(component_key, description)')
        .inFilter('motorcycle_id', motorcycleIds);
    return rows.map((r) {
      final items = <String, String>{
        for (final i in (r['maintenance_record_items'] as List))
          i['component_key'] as String: i['description'] as String? ?? '',
      };
      final path = r['receipt_path'] as String?;
      return MaintenanceRecord(
        id: r['id'] as String,
        motorcycleId: r['motorcycle_id'] as String,
        date: DateTime.parse(r['service_date'] as String),
        odometer: r['odometer'] as int,
        items: items,
        workshop: r['workshop'] as String?,
        receipt: path == null
            ? null
            : Receipt(name: r['receipt_name'] as String? ?? path.split('/').last, storagePath: path),
      );
    }).toList();
  }

  @override
  Future<MaintenanceRecord> addRecord({
    required String userId,
    required String motorcycleId,
    required DateTime date,
    required int odometer,
    required Map<String, String> items,
    String? workshop,
    Receipt? receipt,
    String? recordedByName,
  }) async {
    final row = await _db
        .from('maintenance_records')
        .insert({
          'motorcycle_id': motorcycleId,
          'service_date': _date(date),
          'odometer': odometer,
          'workshop': workshop,
        })
        .select('id')
        .single();
    final recordId = row['id'] as String;

    try {
      await _db.from('maintenance_record_items').insert([
        for (final e in items.entries) {'record_id': recordId, 'component_key': e.key, 'description': e.value},
      ]);

      Receipt? saved;
      if (receipt?.path != null) {
        final ext = _extension(receipt!.name);
        final storagePath = '$userId/$recordId.$ext';
        await _db.storage.from(_receiptBucket).upload(
              storagePath,
              File(receipt.path!),
              fileOptions: FileOptions(contentType: _mime(ext)),
            );
        await _db
            .from('maintenance_records')
            .update({'receipt_path': storagePath, 'receipt_name': receipt.name})
            .eq('id', recordId);
        saved = receipt.withStoragePath(storagePath);
      }

      return MaintenanceRecord(
        id: recordId,
        motorcycleId: motorcycleId,
        date: date,
        odometer: odometer,
        items: items,
        workshop: workshop,
        receipt: saved,
      );
    } catch (e) {
      // Keep the data consistent: remove the half-saved record (items cascade).
      await _db.from('maintenance_records').delete().eq('id', recordId);
      if (e is StorageException) {
        throw BackendException('The receipt could not be uploaded (${e.message}). Nothing was saved, please try again.');
      }
      rethrow;
    }
  }

  @override
  Future<String?> receiptUrl(Receipt receipt) async {
    final path = receipt.storagePath;
    if (path == null) return null;
    return _db.storage.from(_receiptBucket).createSignedUrl(path, 60 * 60);
  }

  // ---------------------------------------------------------------- helpers
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? 'jpg' : name.substring(dot + 1).toLowerCase();
    return ext == 'jpeg' ? 'jpg' : ext;
  }

  static String _mime(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  // ---------------------------------------------------------------- mechanic + admin (database step comes later)
  @override
  Future<List<Motorcycle>> loadAllMotorcycles() async => throw const BackendException(_later);

  @override
  Future<List<UserAccount>> loadOwners() async => throw const BackendException(_later);

  @override
  Future<List<ServiceJob>> loadJobs(String mechanicId) async => throw const BackendException(_later);

  @override
  Future<ServiceJob> saveJob(ServiceJob job) async => throw const BackendException(_later);

  @override
  Future<List<Review>> loadReviews(String mechanicId) async => throw const BackendException(_later);

  @override
  Future<Workshop?> loadWorkshop(String name) async => throw const BackendException(_later);

  @override
  Future<void> updateProfile(UserAccount user) async {
    await _db.from('profiles').update({'full_name': user.fullName}).eq('id', user.id);
  }

  @override
  Future<List<UserAccount>> loadUsers() async => throw const BackendException(_later);

  @override
  Future<UserAccount> addUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? workshopName,
  }) async =>
      throw const BackendException(_later);

  @override
  Future<void> updateUser(UserAccount user) async => throw const BackendException(_later);

  @override
  Future<void> deleteUser(String userId) async => throw const BackendException(_later);

  @override
  Future<CatalogModel> saveCatalogModel(CatalogModel model) async => throw const BackendException(_later);

  @override
  Future<void> deleteCatalogModel(String id) async => throw const BackendException(_later);

  @override
  Future<MaintenanceRule> saveRule(MaintenanceRule rule) async => throw const BackendException(_later);

  @override
  Future<void> deleteRule(String id) async => throw const BackendException(_later);
}
