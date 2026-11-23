import '../models/models.dart';
import 'backend.dart';
import 'mock_data.dart';

/// In-memory backend with sample data. Used when Supabase is not configured.
class MockBackend implements Backend {
  final _users = [...MockData.users];
  final _catalog = [...MockData.catalog];
  final _rules = MockData.buildRules();
  final _motorcycles = MockData.buildMotorcycles();
  final _records = MockData.buildRecords();
  final _jobs = MockData.buildJobs();
  final _reviews = MockData.buildReviews();
  int _seq = 100;

  String _id(String prefix) => '$prefix${_seq++}';

  @override
  bool get isDemo => true;

  // ---------------------------------------------------------------- auth
  @override
  Future<UserAccount?> restoreSession() async => null;

  @override
  Future<UserAccount> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    final user = _users.where((u) => u.email.toLowerCase() == e).firstOrNull;
    if (user == null || user.password != password) {
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
    if (role == UserRole.admin && !MockData.staffCodes.contains(staffCode?.trim().toUpperCase())) {
      throw const BackendException('Staff code is not valid. Ask the head admin for your code.');
    }
    _users.add(UserAccount(
      id: _id('u'),
      fullName: fullName.trim(),
      email: e,
      password: password,
      role: role,
      workshopName: role == UserRole.mechanic ? workshopName?.trim() : null,
      createdAt: DateTime.now(),
    ));
    return false;
  }

  @override
  Future<void> signOut() async {}

  // ---------------------------------------------------------------- owner
  @override
  Future<(List<CatalogModel>, List<MaintenanceRule>)> loadCatalog() async => (List.of(_catalog), List.of(_rules));

  @override
  Future<List<Motorcycle>> loadMotorcycles(String userId) async =>
      _motorcycles.where((m) => m.ownerId == userId).toList();

  @override
  Future<List<MaintenanceRecord>> loadRecords(List<String> motorcycleIds) async =>
      _records.where((r) => motorcycleIds.contains(r.motorcycleId)).toList();

  @override
  Future<Motorcycle> addMotorcycle({
    required String ownerId,
    required String catalogId,
    required String plate,
    required int odometer,
  }) async {
    if (_motorcycles.any((m) => m.plate == plate)) {
      throw BackendException('Plate $plate is already registered in MotorcycleCare.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final moto = Motorcycle(
      id: _id('m'),
      ownerId: ownerId,
      catalogId: catalogId,
      plate: plate,
      odometer: odometer,
      odometerUpdatedAt: today,
      registrationOdometer: odometer,
      registeredAt: today,
    );
    _motorcycles.add(moto);
    return moto;
  }

  @override
  Future<void> updateOdometer(String motorcycleId, int odometer, DateTime date) async {
    final m = _motorcycles.firstWhere((m) => m.id == motorcycleId);
    m.odometer = odometer;
    m.odometerUpdatedAt = date;
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
    final record = MaintenanceRecord(
      id: _id('r'),
      motorcycleId: motorcycleId,
      date: date,
      odometer: odometer,
      items: items,
      workshop: workshop,
      receipt: receipt,
      recordedBy: userId,
      recordedByName: recordedByName,
      createdAt: DateTime.now(),
    );
    _records.add(record);
    return record;
  }

  @override
  Future<String?> receiptUrl(Receipt receipt) async => null;

  // ---------------------------------------------------------------- mechanic
  @override
  Future<List<Motorcycle>> loadAllMotorcycles() async => List.of(_motorcycles);

  @override
  Future<List<UserAccount>> loadOwners() async => _users.where((u) => u.role == UserRole.owner).toList();

  @override
  Future<List<ServiceJob>> loadJobs(String mechanicId) async =>
      _jobs.where((j) => j.mechanicId == mechanicId).toList();

  @override
  Future<ServiceJob> saveJob(ServiceJob job) async {
    if (job.id.isEmpty) {
      final saved = ServiceJob(
        id: _id('j'),
        motorcycleId: job.motorcycleId,
        mechanicId: job.mechanicId,
        note: job.note,
        status: job.status,
        createdAt: job.createdAt,
      );
      _jobs.add(saved);
      return saved;
    }
    _jobs.firstWhere((j) => j.id == job.id).status = job.status;
    return job;
  }

  @override
  Future<List<Review>> loadReviews(String mechanicId) async => mechanicId == 'u2' ? List.of(_reviews) : [];

  @override
  Future<Workshop?> loadWorkshop(String name) async =>
      MockData.workshops.where((w) => w.name.toLowerCase() == name.trim().toLowerCase()).firstOrNull;

  @override
  Future<void> updateProfile(UserAccount user) async => _replaceUser(user);

  void _replaceUser(UserAccount user) {
    final i = _users.indexWhere((u) => u.id == user.id);
    if (i >= 0) _users[i] = user;
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
    final user = UserAccount(
      id: _id('u'),
      fullName: fullName.trim(),
      email: e,
      password: password,
      role: role,
      workshopName: role == UserRole.mechanic ? workshopName : null,
      createdAt: DateTime.now(),
    );
    _users.add(user);
    return user;
  }

  @override
  Future<void> updateUser(UserAccount user) async => _replaceUser(user);

  @override
  Future<void> deleteUser(String userId) async {
    _users.removeWhere((u) => u.id == userId);
    final motoIds = _motorcycles.where((m) => m.ownerId == userId).map((m) => m.id).toSet();
    _motorcycles.removeWhere((m) => motoIds.contains(m.id));
    _records.removeWhere((r) => motoIds.contains(r.motorcycleId));
  }

  @override
  Future<CatalogModel> saveCatalogModel(CatalogModel model) async {
    final dup = _catalog.any((c) =>
        c.id != model.id &&
        c.make.toLowerCase() == model.make.toLowerCase() &&
        c.model.toLowerCase() == model.model.toLowerCase() &&
        c.year == model.year);
    if (dup) throw BackendException('${model.name} (${model.year}) is already in the catalog.');
    if (model.id.isEmpty) {
      final saved = model.copyWith(id: _id('c'));
      _catalog.add(saved);
      return saved;
    }
    _catalog[_catalog.indexWhere((c) => c.id == model.id)] = model;
    return model;
  }

  @override
  Future<void> deleteCatalogModel(String id) async {
    final used = _motorcycles.where((m) => m.catalogId == id).length;
    if (used > 0) {
      throw BackendException('$used registered motorcycle${used == 1 ? ' uses' : 's use'} this model, '
          'so it cannot be deleted.');
    }
    _catalog.removeWhere((c) => c.id == id);
    _rules.removeWhere((r) => r.catalogId == id);
  }

  @override
  Future<MaintenanceRule> saveRule(MaintenanceRule rule) async {
    final dup = _rules.any((r) => r.id != rule.id && r.catalogId == rule.catalogId && r.componentKey == rule.componentKey);
    if (dup) throw BackendException('This model already has a ${rule.componentName} rule.');
    if (rule.id.isEmpty) {
      final saved = rule.copyWith(id: 'R-${1000 + _seq++}');
      _rules.add(saved);
      return saved;
    }
    _rules[_rules.indexWhere((r) => r.id == rule.id)] = rule;
    return rule;
  }

  @override
  Future<void> deleteRule(String id) async => _rules.removeWhere((r) => r.id == id);
}
