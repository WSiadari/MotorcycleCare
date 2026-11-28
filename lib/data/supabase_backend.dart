import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'backend.dart';

/// Reads and writes MotorcycleCare data in Supabase (Auth, Database, Storage, Edge Functions).
/// Tables, triggers, RPC functions and policies come from supabase/schema.sql.
class SupabaseBackend implements Backend {
  SupabaseClient get _db => Supabase.instance.client;

  static const _receiptBucket = 'receipts';

  /// user_accounts with its role and subtype row (same select as the admin Edge Functions).
  static const _accountSelect = 'user_id, email, full_name, phone, active, role_id, created_at, roles(role_name), '
      'motorcycle_owners(notification_enabled), mechanics(workshop_id, workshops(*)), admins(staff_code)';

  static const _recordSelect = '*, service_record_items(item_id, record_id, rule_id, work_description, '
      'maintenance_rules(component_key)), service_receipts(*), user_accounts(full_name)';

  @override
  bool get isDemo => false;

  String get _uid => _db.auth.currentUser!.id;

  // ---------------------------------------------------------------- row mapping
  static Map<String, dynamic>? _one(Object? v) =>
      v is List ? (v.isEmpty ? null : v.first as Map<String, dynamic>) : v as Map<String, dynamic>?;

  static DateTime _ts(Object? v) => DateTime.parse(v as String).toLocal();

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Workshop _workshop(Map<String, dynamic> r) => Workshop(
        workshopId: '${r['workshop_id']}',
        name: r['name'] as String,
        address: r['address'] as String?,
        city: r['city'] as String?,
        hours: r['hours'] as String?,
        phone: r['phone'] as String?,
      );

  static UserAccount _account(Map<String, dynamic> r) {
    final roleName = _one(r['roles'])?['role_name'] as String? ?? 'owner';
    final owner = _one(r['motorcycle_owners']);
    final ws = _one(_one(r['mechanics'])?['workshops']);
    return UserAccount.create(
      role: UserRole.values.byName(roleName),
      userId: r['user_id'] as String,
      email: r['email'] as String? ?? '',
      fullName: r['full_name'] as String? ?? '',
      phone: r['phone'] as String?,
      active: r['active'] as bool? ?? true,
      createdAt: r['created_at'] == null ? null : _ts(r['created_at']),
      notificationEnabled: owner?['notification_enabled'] as bool? ?? true,
      workshop: ws == null ? null : _workshop(ws),
      staffCode: _one(r['admins'])?['staff_code'] as String?,
    );
  }

  static MotorcycleCatalog _catalog(Map<String, dynamic> r) => MotorcycleCatalog(
        catalogId: '${r['catalog_id']}',
        motorcycleType: MotorcycleType.values.byName(r['motorcycle_type'] as String),
        make: r['make'] as String,
        model: r['model'] as String,
        modelYear: r['model_year'] as int,
      );

  static MaintenanceRule _rule(Map<String, dynamic> r) => MaintenanceRule(
        ruleId: '${r['rule_id']}',
        catalogId: '${r['catalog_id']}',
        componentKey: r['component_key'] as String,
        componentName: r['component_name'] as String,
        intervalKm: r['interval_km'] as int,
        intervalMonths: r['interval_months'] as int,
        sourceReference: r['source_reference'] as String? ?? '',
      );

  static Motorcycle _moto(Map<String, dynamic> r) => Motorcycle(
        motorcycleId: r['motorcycle_id'] as String,
        ownerId: r['owner_id'] as String,
        catalogId: '${r['catalog_id']}',
        plateNumber: r['plate_number'] as String,
        currentOdometer: r['current_odometer'] as int,
        odometerUpdatedAt: _ts(r['odometer_updated_at']),
        createdAt: _ts(r['created_at']),
      );

  static OdometerReading _reading(Map<String, dynamic> r) => OdometerReading(
        readingId: '${r['reading_id']}',
        motorcycleId: r['motorcycle_id'] as String,
        valueKm: r['value_km'] as int,
        recordedAt: _ts(r['recorded_at']),
        recordedBy: r['recorded_by'] as String?,
      );

  static ServiceReceipt _receipt(Map<String, dynamic> r) => ServiceReceipt(
        receiptId: '${r['receipt_id']}',
        recordId: r['record_id'] as String,
        fileName: r['file_name'] as String,
        storagePath: r['storage_path'] as String?,
        uploadedAt: r['uploaded_at'] == null ? null : _ts(r['uploaded_at']),
      );

  static ServiceRecord _record(Map<String, dynamic> r) {
    final receipt = _one(r['service_receipts']);
    return ServiceRecord(
      recordId: r['record_id'] as String,
      motorcycleId: r['motorcycle_id'] as String,
      mechanicId: r['mechanic_id'] as String?,
      recordedByUserId: r['recorded_by_user_id'] as String?,
      serviceDate: DateTime.parse(r['service_date'] as String),
      odometerKm: r['odometer_km'] as int,
      workshopName: r['workshop_name'] as String?,
      createdAt: r['created_at'] == null ? null : _ts(r['created_at']),
      items: [
        for (final i in (r['service_record_items'] as List? ?? const []))
          ServiceRecordItem(
            itemId: '${i['item_id']}',
            recordId: i['record_id'] as String,
            ruleId: '${i['rule_id']}',
            componentKey: _one(i['maintenance_rules'])?['component_key'] as String? ?? '',
            workDescription: i['work_description'] as String? ?? '',
          ),
      ],
      receipt: receipt == null ? null : _receipt(receipt),
      recordedByName: _one(r['user_accounts'])?['full_name'] as String?,
    );
  }

  static Reminder _reminder(Map<String, dynamic> r) => Reminder(
        reminderId: '${r['reminder_id']}',
        motorcycleId: r['motorcycle_id'] as String,
        ruleId: '${r['rule_id']}',
        message: r['message'] as String,
        dueStatus: MaintenanceStatus.values.byName(r['due_status'] as String),
        dueDate: DateTime.parse(r['due_date'] as String),
        createdAt: _ts(r['created_at']),
        readAt: r['read_at'] == null ? null : _ts(r['read_at']),
      );

  static ServiceJob _job(Map<String, dynamic> r) => ServiceJob(
        jobId: '${r['job_id']}',
        motorcycleId: r['motorcycle_id'] as String,
        mechanicId: r['mechanic_id'] as String,
        note: r['note'] as String? ?? '',
        status: JobStatus.values.byName(r['status'] as String),
        createdAt: _ts(r['created_at']),
      );

  static Review _review(Map<String, dynamic> r) => Review(
        reviewId: '${r['review_id']}',
        mechanicId: r['mechanic_id'] as String,
        ownerId: r['owner_id'] as String,
        rating: r['rating'] as int,
        comment: r['comment'] as String? ?? '',
        createdAt: _ts(r['created_at']),
        ownerName: _one(_one(r['motorcycle_owners'])?['user_accounts'])?['full_name'] as String? ?? 'Owner',
      );

  static ActivityLog _log(Map<String, dynamic> r) => ActivityLog(
        logId: '${r['log_id']}',
        actorId: r['actor_id'] as String?,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String? ?? '',
        icon: r['icon'] as String? ?? 'info',
        createdAt: _ts(r['created_at']),
      );

  /// PostgREST puts filter values in the URL, so long id lists are sent in parts.
  Future<List<Map<String, dynamic>>> _inChunks(
      List<String> ids, Future<List<Map<String, dynamic>>> Function(List<String> part) query) async {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 80) {
      rows.addAll(await query(ids.sublist(i, i + 80 > ids.length ? ids.length : i + 80)));
    }
    return rows;
  }

  static BackendException _error(PostgrestException e, [String? fallback]) {
    // RAISE EXCEPTION messages from private.* functions and triggers are written for users.
    if (e.code == 'P0001' || e.code == '23514' || e.code == '42501' || e.code == 'P0002') {
      return BackendException(e.message);
    }
    return BackendException(fallback ?? 'Something went wrong (${e.message}).');
  }

  // ---------------------------------------------------------------- auth
  @override
  Future<UserAccount?> restoreSession() async {
    if (_db.auth.currentUser == null) return null;
    final me = await _myAccount();
    if (me == null || !me.active) {
      await _db.auth.signOut();
      return null;
    }
    return me;
  }

  Future<UserAccount?> _myAccount() async {
    final row = await _db.from('user_accounts').select(_accountSelect).eq('user_id', _uid).maybeSingle();
    return row == null ? null : _account(row);
  }

  @override
  Future<UserAccount> signIn(String email, String password) async {
    try {
      await _db.auth.signInWithPassword(email: email.trim(), password: password);
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
    final me = await _myAccount();
    if (me == null) {
      await _db.auth.signOut();
      throw const BackendException('This account has no MotorcycleCare profile. Contact the admin.');
    }
    if (!me.active) {
      await _db.auth.signOut();
      throw const BackendException('This account is inactive. Contact the admin to activate it again.');
    }
    return me;
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
    final AuthResponse res;
    try {
      // Only the display name goes into the metadata. The database never reads a role from it.
      res = await _db.auth.signUp(email: email.trim(), password: password, data: {'full_name': fullName.trim()});
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') || m.contains('already exists')) {
        throw const BackendException('An account with this email already exists. Log in instead.');
      }
      throw BackendException(e.message);
    }
    if (res.session == null) {
      if (role != UserRole.owner) {
        throw const BackendException('Mechanic and Admin accounts need "Confirm email" switched off in Supabase Auth. '
            'Your account was created as Motorcycle Owner; ask an admin to change the role.');
      }
      return true; // email confirmation is switched on in Supabase Auth
    }
    if (role != UserRole.owner) {
      // private.register_role checks the staff code, the workshop and that the account is new.
      try {
        await _db.rpc('register_role', params: {
          'p_role': role.name,
          'p_workshop_name': workshopName?.trim(),
          'p_staff_code': staffCode?.trim(),
        });
      } on PostgrestException catch (e) {
        try {
          await _db.rpc('discard_new_account'); // remove the half-created account
        } catch (_) {}
        await _db.auth.signOut();
        throw _error(e, 'The account could not be created (${e.message}).');
      }
    }
    await _db.auth.signOut();
    return false;
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<UserAccount> updateProfile({
    required UserAccount user,
    required String fullName,
    String? phone,
    String? workshopName,
    bool? notificationEnabled,
  }) async {
    try {
      await _db.rpc('update_my_profile', params: {
        'p_full_name': fullName.trim(),
        'p_phone': phone?.trim(),
        'p_workshop_name': workshopName?.trim(),
        'p_notification_enabled': notificationEnabled,
      });
    } on PostgrestException catch (e) {
      throw _error(e);
    }
    return (await _myAccount())!;
  }

  // ---------------------------------------------------------------- catalog
  @override
  Future<(List<MotorcycleCatalog>, List<MaintenanceRule>)> loadCatalog() async {
    final cats = await _db.from('motorcycle_catalog').select().order('catalog_id');
    final rules = await _db.from('maintenance_rules').select().order('rule_id');
    return (cats.map(_catalog).toList(), rules.map(_rule).toList());
  }

  // ---------------------------------------------------------------- motorcycles
  @override
  Future<List<Motorcycle>> loadMotorcycles(String ownerId) async {
    final rows = await _db.from('motorcycles').select().eq('owner_id', ownerId).order('created_at');
    return rows.map(_moto).toList();
  }

  @override
  Future<List<Motorcycle>> loadAllMotorcycles() async {
    final rows = await _db.from('motorcycles').select().order('created_at');
    return rows.map(_moto).toList();
  }

  @override
  Future<(Motorcycle, OdometerReading)> addMotorcycle({
    required String ownerId,
    required String catalogId,
    required String plateNumber,
    required int odometerKm,
  }) async {
    try {
      final row = await _db
          .from('motorcycles')
          .insert({
            'owner_id': ownerId,
            'catalog_id': int.parse(catalogId),
            'plate_number': plateNumber,
            'current_odometer': odometerKm,
          })
          .select()
          .single();
      final moto = _moto(row);
      // written by the on_motorcycle_created trigger
      final first = await _db
          .from('odometer_readings')
          .select()
          .eq('motorcycle_id', moto.motorcycleId)
          .order('reading_id')
          .limit(1)
          .single();
      return (moto, _reading(first));
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw BackendException('Plate $plateNumber is already registered in MotorcycleCare.');
      throw _error(e, 'Could not save the motorcycle (${e.message}).');
    }
  }

  // ---------------------------------------------------------------- odometer
  @override
  Future<List<OdometerReading>> loadOdometerReadings(List<String> motorcycleIds) async {
    final rows = await _inChunks(motorcycleIds,
        (part) => _db.from('odometer_readings').select().inFilter('motorcycle_id', part).order('recorded_at'));
    return rows.map(_reading).toList();
  }

  @override
  Future<OdometerReading> addOdometerReading({
    required String motorcycleId,
    required int valueKm,
    required String recordedBy,
  }) async {
    try {
      final row = await _db
          .from('odometer_readings')
          .insert({'motorcycle_id': motorcycleId, 'value_km': valueKm, 'recorded_by': recordedBy, 'recorded_at': _now()})
          .select()
          .single();
      return _reading(row); // current_odometer is updated by the on_odometer_reading trigger
    } on PostgrestException catch (e) {
      throw _error(e, 'Could not save the odometer (${e.message}).');
    }
  }

  // ---------------------------------------------------------------- service records
  @override
  Future<List<ServiceRecord>> loadServiceRecords(List<String> motorcycleIds) async {
    final rows = await _inChunks(
        motorcycleIds, (part) => _db.from('service_records').select(_recordSelect).inFilter('motorcycle_id', part));
    return rows.map(_record).toList();
  }

  @override
  Future<ServiceRecord> addServiceRecord(ServiceRecord record) async {
    final Map<String, dynamic> row;
    try {
      row = await _db
          .from('service_records')
          .insert({
            'motorcycle_id': record.motorcycleId,
            'mechanic_id': record.mechanicId,
            'recorded_by_user_id': record.recordedByUserId,
            'service_date': _date(record.serviceDate),
            'odometer_km': record.odometerKm,
            'workshop_name': record.workshopName,
          })
          .select('record_id, created_at')
          .single();
    } on PostgrestException catch (e) {
      throw _error(e, 'Could not save the service record (${e.message}).');
    }
    final recordId = row['record_id'] as String;
    String? uploaded;

    try {
      final itemRows = await _db
          .from('service_record_items')
          .insert([
            for (final i in record.items)
              {'record_id': recordId, 'rule_id': int.parse(i.ruleId), 'work_description': i.workDescription},
          ])
          .select('item_id, rule_id');
      final itemIds = {for (final r in itemRows) '${r['rule_id']}': '${r['item_id']}'};

      ServiceReceipt? receipt;
      final picked = record.receipt;
      if (picked != null && picked.localPath != null) {
        // Stored at "<record_id>/<record_id>.<ext>"; the storage policy checks the recorder.
        final path = '$recordId/$recordId.${picked.extension}';
        await _db.storage.from(_receiptBucket).upload(
              path,
              File(picked.localPath!),
              fileOptions: FileOptions(contentType: picked.mimeType),
            );
        uploaded = path;
        final receiptRow = await _db
            .from('service_receipts')
            .insert({'record_id': recordId, 'file_name': picked.fileName, 'storage_path': path})
            .select()
            .single();
        final stored = _receipt(receiptRow);
        receipt = ServiceReceipt(
          receiptId: stored.receiptId,
          recordId: recordId,
          fileName: stored.fileName,
          storagePath: stored.storagePath,
          uploadedAt: stored.uploadedAt,
          localPath: picked.localPath, // keeps showing the picked photo without downloading it again
          sizeBytes: picked.sizeBytes,
        );
      }

      return record.copyWith(
        recordId: recordId,
        createdAt: _ts(row['created_at']),
        items: [for (final i in record.items) i.copyWith(itemId: itemIds[i.ruleId], recordId: recordId)],
        receipt: receipt,
      );
    } catch (e) {
      // Keep the data consistent: remove the half-saved record (items and receipt row cascade).
      if (uploaded != null) {
        try {
          await _db.storage.from(_receiptBucket).remove([uploaded]);
        } catch (_) {}
      }
      await _db.from('service_records').delete().eq('record_id', recordId);
      if (e is StorageException) {
        throw BackendException('The receipt could not be uploaded (${e.message}). Nothing was saved, please try again.');
      }
      if (e is PostgrestException) throw _error(e, 'Could not save the service record (${e.message}).');
      rethrow;
    }
  }

  @override
  Future<String?> receiptUrl(ServiceReceipt receipt) async {
    final path = receipt.storagePath;
    if (path == null) return null;
    return _db.storage.from(_receiptBucket).createSignedUrl(path, 60 * 60);
  }

  // ---------------------------------------------------------------- reminders
  @override
  Future<List<Reminder>> loadReminders(List<String> motorcycleIds) async {
    final rows = await _inChunks(motorcycleIds,
        (part) => _db.from('reminders').select().inFilter('motorcycle_id', part).order('created_at'));
    return rows.map(_reminder).toList();
  }

  @override
  Future<List<Reminder>> addReminders(List<Reminder> reminders) async {
    if (reminders.isEmpty) return const [];
    // unique (motorcycle_id, rule_id, due_status): existing reminders are skipped, only new rows come back
    final rows = await _db
        .from('reminders')
        .upsert([
          for (final r in reminders)
            {
              'motorcycle_id': r.motorcycleId,
              'rule_id': int.parse(r.ruleId),
              'message': r.message,
              'due_status': r.dueStatus.name,
              'due_date': _date(r.dueDate),
            },
        ], onConflict: 'motorcycle_id,rule_id,due_status', ignoreDuplicates: true)
        .select();
    return rows.map(_reminder).toList();
  }

  @override
  Future<void> markReminderRead(String reminderId, DateTime readAt) async {
    await _db
        .from('reminders')
        .update({'read_at': readAt.toUtc().toIso8601String()}).eq('reminder_id', int.parse(reminderId));
  }

  // ---------------------------------------------------------------- jobs + reviews
  @override
  Future<List<MotorcycleOwner>> loadOwners() async {
    final rows = await _db.from('user_accounts').select(_accountSelect).eq('role_id', 1).order('full_name');
    return rows.map(_account).whereType<MotorcycleOwner>().toList();
  }

  @override
  Future<List<ServiceJob>> loadJobs(String mechanicId) async {
    final rows = await _db.from('service_jobs').select().eq('mechanic_id', mechanicId).order('created_at');
    return rows.map(_job).toList();
  }

  @override
  Future<ServiceJob> saveJob(ServiceJob job) async {
    if (job.jobId.isEmpty) {
      final row = await _db
          .from('service_jobs')
          .insert({
            'motorcycle_id': job.motorcycleId,
            'mechanic_id': job.mechanicId,
            'note': job.note,
            'status': job.status.name,
          })
          .select()
          .single();
      return _job(row);
    }
    await _db.from('service_jobs').update({'status': job.status.name}).eq('job_id', int.parse(job.jobId));
    return job;
  }

  @override
  Future<List<Review>> loadReviews({String? mechanicId, String? ownerId}) async {
    var q = _db.from('reviews').select('*, motorcycle_owners(user_accounts(full_name))');
    if (mechanicId != null) q = q.eq('mechanic_id', mechanicId);
    if (ownerId != null) q = q.eq('owner_id', ownerId);
    final rows = await q.order('created_at', ascending: false);
    return rows.map(_review).toList();
  }

  @override
  Future<Review> addReview(Review review) async {
    try {
      final row = await _db
          .from('reviews')
          .insert({
            'mechanic_id': review.mechanicId,
            'owner_id': review.ownerId,
            'rating': review.rating,
            'comment': review.comment.trim(),
          })
          .select('*, motorcycle_owners(user_accounts(full_name))')
          .single();
      return _review(row);
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw const BackendException('You can only rate a mechanic who serviced your motorcycle.');
      throw _error(e);
    }
  }

  // ---------------------------------------------------------------- admin
  @override
  Future<List<UserAccount>> loadUsers() async {
    final rows = await _db.from('user_accounts').select(_accountSelect).order('full_name');
    return rows.map(_account).toList();
  }

  /// Calls an admin Edge Function; it checks the caller and holds the service role key.
  Future<Map<String, dynamic>> _adminFunction(String name, Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke(name, body: body);
      return (res.data as Map).cast<String, dynamic>();
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw BackendException(message ?? 'The admin service is not available (${e.status}). '
          'Deploy the $name Edge Function (see README).');
    }
  }

  @override
  Future<UserAccount> addUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? workshopName,
  }) async {
    final data = await _adminFunction('admin-create-user', {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'password': password,
      'role': role.name,
      'workshop_name': workshopName?.trim(),
    });
    return _account((data['user'] as Map).cast<String, dynamic>());
  }

  @override
  Future<UserAccount> updateUser(UserAccount user) async {
    try {
      await _db.rpc('admin_update_user', params: {
        'p_user_id': user.userId,
        'p_full_name': user.fullName,
        'p_phone': user.phone,
        'p_role': user.role.name,
        'p_active': user.active,
        'p_workshop_name': user is Mechanic ? user.workshopName : null,
      });
    } on PostgrestException catch (e) {
      throw _error(e);
    }
    final row = await _db.from('user_accounts').select(_accountSelect).eq('user_id', user.userId).single();
    return _account(row);
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _adminFunction('admin-delete-user', {'user_id': userId});
  }

  @override
  Future<MotorcycleCatalog> saveCatalogModel(MotorcycleCatalog model) async {
    final values = {
      'motorcycle_type': model.motorcycleType.name,
      'make': model.make,
      'model': model.model,
      'model_year': model.modelYear,
    };
    try {
      final row = model.catalogId.isEmpty
          ? await _db.from('motorcycle_catalog').insert(values).select().single()
          : await _db
              .from('motorcycle_catalog')
              .update(values)
              .eq('catalog_id', int.parse(model.catalogId))
              .select()
              .single();
      return _catalog(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw BackendException('${model.name} (${model.modelYear}) is already in the catalog.');
      throw _error(e);
    }
  }

  @override
  Future<void> deleteCatalogModel(String catalogId) async {
    try {
      await _db.from('motorcycle_catalog').delete().eq('catalog_id', int.parse(catalogId));
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        final used = await _db.from('motorcycles').select('motorcycle_id').eq('catalog_id', int.parse(catalogId));
        final n = used.length;
        throw BackendException('$n registered motorcycle${n == 1 ? ' uses' : 's use'} this model, so it cannot be deleted.');
      }
      throw _error(e);
    }
  }

  @override
  Future<MaintenanceRule> saveRule(MaintenanceRule rule) async {
    final values = {
      'catalog_id': int.parse(rule.catalogId),
      'component_key': rule.componentKey,
      'component_name': rule.componentName,
      'interval_km': rule.intervalKm,
      'interval_months': rule.intervalMonths,
      'source_reference': rule.sourceReference,
    };
    try {
      final row = rule.ruleId.isEmpty
          ? await _db.from('maintenance_rules').insert(values).select().single()
          : await _db.from('maintenance_rules').update(values).eq('rule_id', int.parse(rule.ruleId)).select().single();
      return _rule(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw BackendException('This model already has a ${rule.componentName} rule.');
      throw _error(e);
    }
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    try {
      await _db.from('maintenance_rules').delete().eq('rule_id', int.parse(ruleId));
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const BackendException('Service records use this rule, so it cannot be deleted.');
      }
      throw _error(e);
    }
  }

  @override
  Future<List<ActivityLog>> loadActivityLogs() async {
    final rows = await _db.from('activity_logs').select().order('created_at', ascending: false).limit(50);
    return rows.map(_log).toList();
  }

  @override
  Future<ActivityLog> addActivityLog(ActivityLog log) async {
    final row = await _db
        .from('activity_logs')
        .insert({'actor_id': _uid, 'title': log.title, 'subtitle': log.subtitle, 'icon': log.icon})
        .select()
        .single();
    return _log(row);
  }

  @override
  Future<SystemReport> loadSystemReport() async {
    final users = await loadUsers();
    final (catalog, rules) = await loadCatalog();
    return SystemReport.build(users: users, catalog: catalog, rules: rules, now: DateTime.now());
  }
}
