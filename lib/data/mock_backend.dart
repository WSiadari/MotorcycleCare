import '../models/models.dart';
import 'backend.dart';
import 'mock_data.dart';

/// In-memory backend with sample data. Used when Supabase is not configured.
/// It follows the same rules as supabase/schema.sql (triggers, unique keys, server checks),
/// so the demo behaves like the real database.
class MockBackend implements Backend {
  final _users = MockData.buildUsers();
  final _passwords = Map<String, String>.of(MockData.passwords);
  final _workshops = [...MockData.workshops];
  final _catalog = [...MockData.catalog];
  final _rules = MockData.buildRules();
  final _motorcycles = MockData.buildMotorcycles();
  final _readings = MockData.buildReadings();
  final _records = MockData.buildRecords();
  final _reminders = <Reminder>[];
  final _jobs = MockData.buildJobs();
  final _reviews = MockData.buildReviews();
  final _logs = MockData.buildActivityLogs();
  int _seq = 100;

  String _id(String prefix) => '$prefix${_seq++}';

  @override
  bool get isDemo => true;

  UserAccount _user(String id) => _users.firstWhere((u) => u.userId == id);

  // ---------------------------------------------------------------- auth
  @override
  Future<UserAccount?> restoreSession() async => null;

  @override
  Future<UserAccount> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    final user = _users.where((u) => u.email.toLowerCase() == e).firstOrNull;
    if (user == null || _passwords[user.email] != password) {
      throw const BackendException('Email or password is incorrect. Please try again.');
    }
    if (!user.active) {
      throw const BackendException('This account is inactive. Contact the admin to activate it again.');
    }
    return user;
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
    final e = email.trim().toLowerCase();
    if (_users.any((u) => u.email.toLowerCase() == e)) {
      throw const BackendException('This email is already registered. Log in or use another email.');
    }
    // Same checks as private.register_role.
    final code = staffCode?.trim().toUpperCase();
    if (role == UserRole.admin && !MockData.staffCodes.contains(code)) {
      throw const BackendException('Staff code is not valid. Ask the head admin for your code.');
    }
    if (role == UserRole.mechanic && (workshopName ?? '').trim().isEmpty) {
      throw const BackendException('Enter the workshop where you work.');
    }
    final user = UserAccount.create(
      role: role,
      userId: _id('u'),
      fullName: fullName.trim(),
      email: e,
      createdAt: DateTime.now(),
      workshop: role == UserRole.mechanic ? _findOrCreateWorkshop(workshopName!) : null,
      staffCode: role == UserRole.admin ? code : null,
    );
    _users.add(user);
    _passwords[e] = password;
    if (user is Mechanic) {
      _logs.add(ActivityLog(
          logId: _id('l'),
          actorId: user.userId,
          title: 'New mechanic registered',
          subtitle: user.workshopName ?? '',
          icon: 'wrench',
          createdAt: DateTime.now()));
    } else if (user is Admin) {
      _logs.add(ActivityLog(
          logId: _id('l'),
          actorId: user.userId,
          title: 'New admin registered',
          subtitle: user.fullName,
          icon: 'shield',
          createdAt: DateTime.now()));
    }
    return false;
  }

  @override
  Future<void> signOut() async {}

  Workshop _findOrCreateWorkshop(String name) {
    final n = name.trim();
    final found = _workshops.where((w) => w.name.toLowerCase() == n.toLowerCase()).firstOrNull;
    if (found != null) return found;
    final w = Workshop(workshopId: _id('w'), name: n);
    _workshops.add(w);
    return w;
  }

  @override
  Future<UserAccount> updateProfile({
    required UserAccount user,
    required String fullName,
    String? phone,
    String? workshopName,
    bool? notificationEnabled,
  }) async {
    final ws = user is Mechanic && (workshopName ?? '').trim().isNotEmpty ? _findOrCreateWorkshop(workshopName!) : null;
    final updated = _user(user.userId).copyWith(
      fullName: fullName.trim(),
      phone: (phone ?? '').trim(),
      notificationEnabled: notificationEnabled,
      workshop: ws,
    );
    _replaceUser(updated);
    return updated;
  }

  void _replaceUser(UserAccount user) {
    final i = _users.indexWhere((u) => u.userId == user.userId);
    if (i >= 0) _users[i] = user;
  }

  // ---------------------------------------------------------------- catalog
  @override
  Future<(List<MotorcycleCatalog>, List<MaintenanceRule>)> loadCatalog() async => (List.of(_catalog), List.of(_rules));

  // ---------------------------------------------------------------- motorcycles + odometer
  @override
  Future<List<Motorcycle>> loadMotorcycles(String ownerId) async =>
      _motorcycles.where((m) => m.ownerId == ownerId).toList();

  @override
  Future<List<Motorcycle>> loadAllMotorcycles() async => List.of(_motorcycles);

  @override
  Future<(Motorcycle, OdometerReading)> addMotorcycle({
    required String ownerId,
    required String catalogId,
    required String plateNumber,
    required int odometerKm,
  }) async {
    if (_motorcycles.any((m) => m.plateNumber == plateNumber)) {
      throw BackendException('Plate $plateNumber is already registered in MotorcycleCare.');
    }
    if (_user(ownerId) is! MotorcycleOwner) throw const BackendException('Choose a motorcycle owner.');
    final now = DateTime.now();
    final moto = Motorcycle(
      motorcycleId: _id('m'),
      ownerId: ownerId,
      catalogId: catalogId,
      plateNumber: plateNumber,
      currentOdometer: odometerKm,
      odometerUpdatedAt: now,
      createdAt: now,
    );
    _motorcycles.add(moto);
    // on_motorcycle_created trigger: first odometer reading
    final first = OdometerReading(
        readingId: _id('o'), motorcycleId: moto.motorcycleId, valueKm: odometerKm, recordedAt: now, recordedBy: ownerId);
    _readings.add(first);
    return (moto, first);
  }

  @override
  Future<List<OdometerReading>> loadOdometerReadings(List<String> motorcycleIds) async =>
      _readings.where((r) => motorcycleIds.contains(r.motorcycleId)).toList();

  @override
  Future<OdometerReading> addOdometerReading({
    required String motorcycleId,
    required int valueKm,
    required String recordedBy,
  }) async {
    final m = _motorcycles.firstWhere((m) => m.motorcycleId == motorcycleId);
    if (valueKm < m.currentOdometer) {
      throw BackendException("Odometer can't be lower than the latest reading (${m.currentOdometer} km).");
    }
    final reading = OdometerReading(
        readingId: _id('o'), motorcycleId: motorcycleId, valueKm: valueKm, recordedAt: DateTime.now(), recordedBy: recordedBy);
    _readings.add(reading);
    m.applyReading(reading); // on_odometer_reading trigger
    return reading;
  }

  // ---------------------------------------------------------------- service records
  @override
  Future<List<ServiceRecord>> loadServiceRecords(List<String> motorcycleIds) async =>
      _records.where((r) => motorcycleIds.contains(r.motorcycleId)).toList();

  @override
  Future<ServiceRecord> addServiceRecord(ServiceRecord record) async {
    final id = _id('r');
    final now = DateTime.now();
    final receipt = record.receipt;
    final saved = record.copyWith(
      recordId: id,
      createdAt: now,
      items: [for (final (i, item) in record.items.indexed) item.copyWith(itemId: '$id-${i + 1}', recordId: id)],
      receipt: receipt?.copyWith(receiptId: 'rc-$id', recordId: id, uploadedAt: now),
      recordedByName: record.recordedByUserId == null ? null : _user(record.recordedByUserId!).fullName,
    );
    _records.add(saved);
    // on_service_item_created trigger: servicing a component closes its reminders
    final rules = {for (final i in saved.items) i.ruleId};
    _reminders.removeWhere((r) => r.motorcycleId == saved.motorcycleId && rules.contains(r.ruleId));
    return saved;
  }

  @override
  Future<String?> receiptUrl(ServiceReceipt receipt) async => null;

  // ---------------------------------------------------------------- reminders
  @override
  Future<List<Reminder>> loadReminders(List<String> motorcycleIds) async =>
      _reminders.where((r) => motorcycleIds.contains(r.motorcycleId)).toList();

  @override
  Future<List<Reminder>> addReminders(List<Reminder> reminders) async {
    final created = <Reminder>[];
    for (final r in reminders) {
      if (r.dueStatus == MaintenanceStatus.onTrack) continue; // check constraint
      if (_reminders.any(r.sameKey)) continue; // unique (motorcycle_id, rule_id, due_status)
      final saved = r.copyWith(reminderId: _id('n'));
      _reminders.add(saved);
      created.add(saved);
    }
    return created;
  }

  @override
  Future<void> markReminderRead(String reminderId, DateTime readAt) async {
    final i = _reminders.indexWhere((r) => r.reminderId == reminderId);
    if (i >= 0) _reminders[i] = _reminders[i].copyWith(readAt: readAt);
  }

  // ---------------------------------------------------------------- mechanic
  @override
  Future<List<MotorcycleOwner>> loadOwners() async => _users.whereType<MotorcycleOwner>().toList();

  @override
  Future<List<ServiceJob>> loadJobs(String mechanicId) async =>
      _jobs.where((j) => j.mechanicId == mechanicId).toList();

  @override
  Future<ServiceJob> saveJob(ServiceJob job) async {
    if (job.jobId.isEmpty) {
      final saved = ServiceJob(
        jobId: _id('j'),
        motorcycleId: job.motorcycleId,
        mechanicId: job.mechanicId,
        note: job.note,
        status: job.status,
        createdAt: job.createdAt,
      );
      _jobs.add(saved);
      return saved;
    }
    _jobs.firstWhere((j) => j.jobId == job.jobId).status = job.status;
    return job;
  }

  @override
  Future<List<Review>> loadReviews({String? mechanicId, String? ownerId}) async => _reviews
      .where((r) => (mechanicId == null || r.mechanicId == mechanicId) && (ownerId == null || r.ownerId == ownerId))
      .toList();

  @override
  Future<Review> addReview(Review review) async {
    // reviews: owner insert policy — the mechanic must have serviced one of the owner's motorcycles
    final mine = {for (final m in _motorcycles) if (m.ownerId == review.ownerId) m.motorcycleId};
    if (!_records.any((r) => mine.contains(r.motorcycleId) && r.mechanicId == review.mechanicId)) {
      throw const BackendException('You can only rate a mechanic who serviced your motorcycle.');
    }
    if (review.rating < 1 || review.rating > 5) throw const BackendException('Choose 1 to 5 stars.');
    final saved = Review(
      reviewId: _id('v'),
      mechanicId: review.mechanicId,
      ownerId: review.ownerId,
      ownerName: _user(review.ownerId).fullName,
      rating: review.rating,
      comment: review.comment.trim(),
      createdAt: DateTime.now(),
    );
    _reviews.add(saved);
    return saved;
  }

  // ---------------------------------------------------------------- admin
  @override
  Future<List<UserAccount>> loadUsers() async => List.of(_users);

  @override
  Future<UserAccount> addUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? workshopName,
  }) async {
    final e = email.trim().toLowerCase();
    if (_users.any((u) => u.email.toLowerCase() == e)) {
      throw const BackendException('This email is already registered. Use another email.');
    }
    final user = UserAccount.create(
      role: role,
      userId: _id('u'),
      fullName: fullName.trim(),
      email: e,
      createdAt: DateTime.now(),
      workshop: role == UserRole.mechanic && (workshopName ?? '').trim().isNotEmpty
          ? _findOrCreateWorkshop(workshopName!)
          : null,
    );
    _users.add(user);
    _passwords[e] = password;
    return user;
  }

  @override
  Future<UserAccount> updateUser(UserAccount user) async {
    final current = _user(user.userId);
    // private.set_user_role: an owner with motorcycles keeps the owner role
    if (current is MotorcycleOwner &&
        user is! MotorcycleOwner &&
        _motorcycles.any((m) => m.ownerId == user.userId)) {
      throw const BackendException('This owner still has registered motorcycles, so the role can\'t be changed.');
    }
    final saved = user is Mechanic && user.workshop != null && user.workshop!.workshopId.isEmpty
        ? user.copyWith(workshop: _findOrCreateWorkshop(user.workshop!.name))
        : user;
    _replaceUser(saved);
    return saved;
  }

  @override
  Future<void> deleteUser(String userId) async {
    final email = _user(userId).email;
    _users.removeWhere((u) => u.userId == userId);
    _passwords.remove(email);
    // the same cascade as deleting the auth user in Supabase
    final motoIds = _motorcycles.where((m) => m.ownerId == userId).map((m) => m.motorcycleId).toSet();
    _motorcycles.removeWhere((m) => motoIds.contains(m.motorcycleId));
    _readings.removeWhere((r) => motoIds.contains(r.motorcycleId));
    _records.removeWhere((r) => motoIds.contains(r.motorcycleId));
    _reminders.removeWhere((r) => motoIds.contains(r.motorcycleId));
    _jobs.removeWhere((j) => j.mechanicId == userId || motoIds.contains(j.motorcycleId));
    _reviews.removeWhere((r) => r.mechanicId == userId || r.ownerId == userId);
  }

  @override
  Future<MotorcycleCatalog> saveCatalogModel(MotorcycleCatalog model) async {
    final dup = _catalog.any((c) =>
        c.catalogId != model.catalogId &&
        c.make.toLowerCase() == model.make.toLowerCase() &&
        c.model.toLowerCase() == model.model.toLowerCase() &&
        c.modelYear == model.modelYear);
    if (dup) throw BackendException('${model.name} (${model.modelYear}) is already in the catalog.');
    if (model.catalogId.isEmpty) {
      final saved = model.copyWith(catalogId: _id('c'));
      _catalog.add(saved);
      return saved;
    }
    _catalog[_catalog.indexWhere((c) => c.catalogId == model.catalogId)] = model;
    return model;
  }

  @override
  Future<void> deleteCatalogModel(String catalogId) async {
    final used = _motorcycles.where((m) => m.catalogId == catalogId).length;
    if (used > 0) {
      throw BackendException('$used registered motorcycle${used == 1 ? ' uses' : 's use'} this model, '
          'so it cannot be deleted.');
    }
    _catalog.removeWhere((c) => c.catalogId == catalogId);
    _rules.removeWhere((r) => r.catalogId == catalogId);
  }

  @override
  Future<MaintenanceRule> saveRule(MaintenanceRule rule) async {
    final dup = _rules
        .any((r) => r.ruleId != rule.ruleId && r.catalogId == rule.catalogId && r.componentKey == rule.componentKey);
    if (dup) throw BackendException('This model already has a ${rule.componentName} rule.');
    if (rule.ruleId.isEmpty) {
      final saved = rule.copyWith(ruleId: '${1000 + _seq++}');
      _rules.add(saved);
      return saved;
    }
    _rules[_rules.indexWhere((r) => r.ruleId == rule.ruleId)] = rule;
    return rule;
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    // service_record_items.rule_id is "on delete restrict"
    final used = _records.where((r) => r.items.any((i) => i.ruleId == ruleId)).length;
    if (used > 0) {
      throw BackendException('$used service record${used == 1 ? ' uses' : 's use'} this rule, so it cannot be deleted.');
    }
    _rules.removeWhere((r) => r.ruleId == ruleId);
    _reminders.removeWhere((r) => r.ruleId == ruleId);
  }

  @override
  Future<List<ActivityLog>> loadActivityLogs() async =>
      [..._logs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<ActivityLog> addActivityLog(ActivityLog log) async {
    final saved = ActivityLog(
        logId: _id('l'),
        actorId: log.actorId,
        title: log.title,
        subtitle: log.subtitle,
        icon: log.icon,
        createdAt: log.createdAt);
    _logs.add(saved);
    return saved;
  }

  @override
  Future<SystemReport> loadSystemReport() async =>
      SystemReport.build(users: _users, catalog: _catalog, rules: _rules, now: DateTime.now());
}
