import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/backend.dart';
import '../data/mock_backend.dart';
import '../models/models.dart';
import '../utils/format.dart';

/// Holds the app data and implements the user activity flow:
/// register/login → manage motorcycles → odometer → status → maintenance.
/// Data comes from a [Backend] (demo data or Supabase) and is cached here,
/// so status calculations stay instant.
class AppState extends ChangeNotifier {
  AppState(this.backend);

  /// Demo data, no setup needed.
  factory AppState.seeded() => AppState(MockBackend());

  final Backend backend;

  List<CatalogModel> _catalog = [];
  List<MaintenanceRule> _rules = [];
  List<Motorcycle> _motorcycles = [];
  List<MaintenanceRecord> _records = [];
  List<UserAccount> _users = []; // admin: all accounts · mechanic: owners
  List<ServiceJob> _jobs = [];
  List<Review> _reviews = [];
  Workshop? _workshop;
  final List<Activity> _activity = [];
  final List<String> _recentSearches = [];

  UserAccount? _currentUser;
  String? _selectedId;

  static const dueSoonThreshold = 80.0;
  static const maxOdometerJump = 20000;

  void _changed() => notifyListeners();

  static String friendlyError(Object e) {
    if (e is BackendException) return e.message;
    debugPrint('MotorcycleCare error: $e');
    return 'Something went wrong. Check your internet connection and try again.';
  }

  /// Loads what the signed-in role needs (owner, mechanic or admin activity diagram).
  Future<void> _loadData() async {
    final me = _currentUser!;
    final (catalog, rules) = await backend.loadCatalog();
    _catalog = catalog;
    _rules = rules;
    switch (me.role) {
      case UserRole.owner:
        _motorcycles = await backend.loadMotorcycles(me.id);
        _records = await backend.loadRecords(_motorcycles.map((m) => m.id).toList());
      case UserRole.mechanic:
        _motorcycles = await backend.loadAllMotorcycles();
        _records = await backend.loadRecords(_motorcycles.map((m) => m.id).toList());
        _users = await backend.loadOwners();
        _jobs = await backend.loadJobs(me.id);
        _reviews = await backend.loadReviews(me.id);
        _workshop = me.workshopName == null ? null : await backend.loadWorkshop(me.workshopName!);
      case UserRole.admin:
        _users = await backend.loadUsers();
        _motorcycles = [];
        _records = [];
    }
  }

  /// Reloads everything from the backend (pull to refresh).
  Future<String?> refresh() async {
    if (_currentUser == null) return null;
    try {
      await _loadData();
      notifyListeners();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ---------------------------------------------------------------- auth
  UserAccount? get currentUser => _currentUser;

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your email.';
    if (!_emailRe.hasMatch(s)) return 'Enter a valid email, e.g. name@email.com.';
    return null;
  }

  /// Opens the app straight to "My motorcycles" when the last session is still valid.
  Future<bool> restoreSession() async {
    try {
      final user = await backend.restoreSession();
      if (user == null) return false;
      _currentUser = user;
      await _loadData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Session restore failed: $e');
      _currentUser = null;
      return false;
    }
  }

  /// Returns an error message, or null when login succeeds.
  Future<String?> login(String email, String password) async {
    try {
      _currentUser = await backend.signIn(email, password);
      _selectedId = null;
      await _loadData();
      notifyListeners();
      return null;
    } catch (e) {
      _currentUser = null;
      return friendlyError(e);
    }
  }

  /// Returns (error, needsEmailConfirmation).
  Future<(String?, bool)> register({
    required String fullName,
    required String email,
    required String password,
    UserRole role = UserRole.owner,
    String? workshopName,
    String? staffCode,
  }) async {
    try {
      final needsConfirmation = await backend.signUp(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        workshopName: workshopName,
        staffCode: staffCode,
      );
      return (null, needsConfirmation);
    } catch (e) {
      return (friendlyError(e), false);
    }
  }

  Future<void> logout() async {
    try {
      await backend.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    _currentUser = null;
    _selectedId = null;
    _motorcycles = [];
    _records = [];
    _users = [];
    _jobs = [];
    _reviews = [];
    _workshop = null;
    _activity.clear();
    _recentSearches.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------- catalog
  List<CatalogModel> get catalog => List.unmodifiable(_catalog);

  CatalogModel catalogOf(Motorcycle m) => _catalog.firstWhere((c) => c.id == m.catalogId);

  List<MaintenanceRule> rulesForCatalog(String catalogId) =>
      _rules.where((r) => r.catalogId == catalogId).toList();

  List<MaintenanceRule> rulesFor(Motorcycle m) => rulesForCatalog(m.catalogId);

  MaintenanceRule ruleFor(Motorcycle m, String componentKey) =>
      rulesFor(m).firstWhere((r) => r.componentKey == componentKey);

  // ---------------------------------------------------------------- motorcycles
  List<Motorcycle> get myMotorcycles =>
      _currentUser == null ? const [] : _motorcycles.where((m) => m.ownerId == _currentUser!.id).toList();

  Motorcycle? get selected => _motorcycles.where((m) => m.id == _selectedId).firstOrNull;

  void selectMotorcycle(String id) {
    _selectedId = id;
    notifyListeners();
  }

  static final _plateRe = RegExp(r'^[A-Z]{1,2} ?\d{1,4} ?[A-Z]{0,3}$');

  static String normalizePlate(String raw) {
    final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final m = RegExp(r'^([A-Z]{1,2})(\d{1,4})([A-Z]{0,3})$').firstMatch(compact);
    if (m == null) return raw.trim().toUpperCase();
    return [m.group(1), m.group(2), m.group(3)].where((g) => g != null && g.isNotEmpty).join(' ');
  }

  static String? validatePlate(String? v) {
    final s = normalizePlate(v ?? '');
    if (s.isEmpty) return 'Enter the plate number.';
    if (!_plateRe.hasMatch(s)) return 'Use the format on your plate, e.g. B 4521 KXR.';
    return null;
  }

  /// Returns an error message, or null and selects the new motorcycle.
  /// A mechanic registers it for a customer ([ownerId]); an owner for themselves.
  Future<String?> addMotorcycle(
      {required String catalogId, required String plate, required int odometer, String? ownerId}) async {
    final p = normalizePlate(plate);
    if (_motorcycles.any((m) => m.plate == p)) return 'Plate $p is already registered in MotorcycleCare.';
    if (odometer < 0 || odometer > 500000) return 'Odometer must be between 0 and 500,000 km.';
    try {
      final moto = await backend.addMotorcycle(
        ownerId: ownerId ?? _currentUser!.id,
        catalogId: catalogId,
        plate: p,
        odometer: odometer,
      );
      _motorcycles.add(moto);
      _selectedId = moto.id;
      notifyListeners();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ---------------------------------------------------------------- odometer
  String? validateOdometer(Motorcycle m, int? value) {
    if (value == null) return 'Enter the number shown on your odometer.';
    if (value < m.odometer) return "Odometer can't be lower than the latest reading (${fmtKm(m.odometer)}).";
    if (value - m.odometer > maxOdometerJump) return 'That jump looks too big. Check the number.';
    return null;
  }

  Future<String?> updateOdometer(Motorcycle m, int value) async {
    final err = validateOdometer(m, value);
    if (err != null) return err;
    try {
      final now = today();
      await backend.updateOdometer(m.id, value, now);
      m.odometer = value;
      m.odometerUpdatedAt = now;
      notifyListeners();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// "Use latest odometer" branch: the reading is confirmed as still correct.
  Future<String?> confirmOdometer(Motorcycle m) async {
    try {
      final now = today();
      await backend.updateOdometer(m.id, m.odometer, now);
      m.odometerUpdatedAt = now;
      notifyListeners();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ---------------------------------------------------------------- status
  List<MaintenanceRecord> recordsFor(Motorcycle m) {
    final list = _records.where((r) => r.motorcycleId == m.id).toList()
      ..sort((a, b) {
        final byKm = b.odometer.compareTo(a.odometer);
        return byKm != 0 ? byKm : b.date.compareTo(a.date);
      });
    return list;
  }

  MaintenanceRecord? lastServiceOf(Motorcycle m, String componentKey) =>
      recordsFor(m).where((r) => r.items.containsKey(componentKey)).firstOrNull;

  ComponentStatus statusOf(Motorcycle m, MaintenanceRule rule) {
    final last = lastServiceOf(m, rule.componentKey);
    final baseKm = last?.odometer ?? m.registrationOdometer;
    final baseDate = last?.date ?? m.registeredAt;
    final used = math.max(0, m.odometer - baseKm);
    final kmPct = used / rule.intervalKm * 100;
    final timePct = math.max(0.0, monthsBetween(baseDate, today()) / rule.intervalMonths * 100);
    final worst = math.max(kmPct, timePct);
    final health = worst >= 100
        ? Health.overdue
        : worst >= dueSoonThreshold
            ? Health.dueSoon
            : Health.onTrack;
    return ComponentStatus(
      rule: rule,
      lastRecord: last,
      baseKm: baseKm,
      baseDate: baseDate,
      usedKm: used,
      kmPercent: kmPct,
      timePercent: timePct,
      health: health,
      nextKm: baseKm + rule.intervalKm,
      nextDate: addMonths(baseDate, rule.intervalMonths),
    );
  }

  List<ComponentStatus> statusesFor(Motorcycle m) => rulesFor(m).map((r) => statusOf(m, r)).toList();

  /// Most urgent status of a motorcycle (for list badges).
  Health worstHealth(Motorcycle m) {
    final all = statusesFor(m);
    if (all.any((s) => s.health == Health.overdue)) return Health.overdue;
    if (all.any((s) => s.health == Health.dueSoon)) return Health.dueSoon;
    return Health.onTrack;
  }

  /// Component keys serviced today (shown on the dashboard after a service).
  Set<String> servicedToday(Motorcycle m) => {
        for (final r in recordsFor(m))
          if (dateOnly(r.date) == today()) ...r.items.keys,
      };

  List<ComponentStatus> alertsFor(Motorcycle m) {
    final list = statusesFor(m).where((s) => s.health != Health.onTrack).toList()
      ..sort((a, b) => b.health.index.compareTo(a.health.index));
    return list;
  }

  // ---------------------------------------------------------------- records
  /// Lowest odometer allowed for a new record of the given components.
  int minServiceOdometer(Motorcycle m, Iterable<String> keys) {
    var min = m.registrationOdometer;
    for (final k in keys) {
      final last = lastServiceOf(m, k);
      if (last != null && last.odometer > min) min = last.odometer;
    }
    return min;
  }

  /// Saves a service record. Returns (record, error).
  Future<(MaintenanceRecord?, String?)> saveRecord({
    required Motorcycle motorcycle,
    required DateTime date,
    required int odometer,
    required Map<String, String> items,
    String? workshop,
    Receipt? receipt,
  }) async {
    try {
      final record = await backend.addRecord(
        userId: _currentUser!.id,
        motorcycleId: motorcycle.id,
        date: dateOnly(date),
        odometer: odometer,
        items: items,
        workshop: (workshop == null || workshop.trim().isEmpty) ? null : workshop.trim(),
        receipt: receipt,
        recordedByName: _currentUser!.fullName,
      );
      _records.add(record);
      if (odometer > motorcycle.odometer) {
        final now = today();
        await backend.updateOdometer(motorcycle.id, odometer, now);
        motorcycle.odometer = odometer;
        motorcycle.odometerUpdatedAt = now;
      }
      notifyListeners();
      return (record, null);
    } catch (e) {
      return (null, friendlyError(e));
    }
  }
}


// ====================================================================== mechanic
extension MechanicState on AppState {
  UserAccount? ownerOf(Motorcycle m) => _users.where((u) => u.id == m.ownerId).firstOrNull;

  List<UserAccount> get owners => _users.where((u) => u.role == UserRole.owner).toList()
    ..sort((a, b) => a.fullName.compareTo(b.fullName));

  Motorcycle? motorcycleById(String id) => _motorcycles.where((m) => m.id == id).firstOrNull;

  /// Search Motorcycle → Motorcycle found? Returns null when the plate is not registered.
  Motorcycle? findByPlate(String plate) {
    final p = AppState.normalizePlate(plate);
    final m = _motorcycles.where((m) => m.plate == p).firstOrNull;
    if (m != null) {
      _recentSearches
        ..remove(m.id)
        ..insert(0, m.id);
      _selectedId = m.id;
      _changed();
    }
    return m;
  }

  List<Motorcycle> get recentSearches {
    final ids = _recentSearches.isEmpty ? _jobs.map((j) => j.motorcycleId).toList() : _recentSearches;
    return ids.map(motorcycleById).whereType<Motorcycle>().toSet().take(3).toList();
  }

  List<Motorcycle> get allMotorcycles => List.unmodifiable(_motorcycles);

  /// Records saved by the signed-in mechanic, newest first.
  List<MaintenanceRecord> get myServices {
    final me = _currentUser?.id;
    return _records.where((r) => r.recordedBy == me).toList()
      ..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
  }

  List<MaintenanceRecord> servicesBetween(DateTime from, DateTime to) =>
      myServices.where((r) => !r.date.isBefore(from) && r.date.isBefore(to)).toList();

  List<MaintenanceRecord> get doneToday => servicesBetween(today(), today().add(const Duration(days: 1)));

  DateTime get weekStart => today().subtract(Duration(days: today().weekday - 1));

  List<MaintenanceRecord> get thisWeek => servicesBetween(weekStart, weekStart.add(const Duration(days: 7)));

  List<MaintenanceRecord> get thisMonth {
    final t = today();
    return servicesBetween(DateTime(t.year, t.month), DateTime(t.year, t.month + 1));
  }

  List<ServiceJob> get todaysJobs => _jobs.where((j) => j.status != JobStatus.done).toList()
    ..sort((a, b) => a.status == b.status ? a.createdAt.compareTo(b.createdAt) : b.status.index.compareTo(a.status.index));

  ServiceJob? openJobFor(Motorcycle m) =>
      _jobs.where((j) => j.motorcycleId == m.id && j.status != JobStatus.done).firstOrNull;

  /// "Inspect & Repair": the motorcycle becomes an in-progress job.
  Future<void> startJob(Motorcycle m, String note) async {
    try {
      final job = openJobFor(m);
      if (job == null) {
        _jobs.add(await backend.saveJob(ServiceJob(
          id: '',
          motorcycleId: m.id,
          mechanicId: _currentUser!.id,
          note: note,
          status: JobStatus.inProgress,
          createdAt: DateTime.now(),
        )));
      } else if (job.status == JobStatus.waiting) {
        job.status = JobStatus.inProgress;
        await backend.saveJob(job);
      }
      _changed();
    } catch (e) {
      debugPrint('Start job failed: $e');
    }
  }

  /// Components that passed their limit on motorcycles in the mechanic's queue or history.
  List<(Motorcycle, ComponentStatus)> get overdueFlags {
    final ids = {..._jobs.where((j) => j.status != JobStatus.done).map((j) => j.motorcycleId), ...myServices.map((r) => r.motorcycleId)};
    return [
      for (final id in ids)
        if (motorcycleById(id) case final m?)
          for (final s in statusesFor(m))
            if (s.health == Health.overdue) (m, s),
    ];
  }

  /// Saves the service record from the mechanic flow and closes the job.
  Future<(MaintenanceRecord?, String?)> saveService(ServiceDraft d) async {
    final rules = rulesFor(d.motorcycle);
    final desc = d.description.trim();
    final items = {
      for (final r in rules)
        if (d.components.contains(r.componentKey)) r.componentKey: desc.isEmpty ? 'Serviced' : desc,
    };
    final (record, err) = await saveRecord(
      motorcycle: d.motorcycle,
      date: d.date,
      odometer: d.odometer,
      items: items,
      workshop: _currentUser!.workshopName ?? 'Workshop',
      receipt: d.receipt,
    );
    if (record != null) {
      final job = openJobFor(d.motorcycle);
      if (job != null) {
        job.status = JobStatus.done;
        try {
          await backend.saveJob(job);
        } catch (e) {
          debugPrint('Close job failed: $e');
        }
      }
      _changed();
    }
    return (record, err);
  }

  List<Review> get reviews => List.unmodifiable(_reviews);

  double get rating => _reviews.isEmpty ? 0 : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  Workshop? get workshop => _workshop;

  Future<String?> updateMyProfile({required String fullName, String? phone, String? workshopName}) async {
    final me = _currentUser!;
    if (fullName.trim().isEmpty) return 'Enter your full name.';
    final updated = me.copyWith(fullName: fullName.trim(), phone: phone?.trim(), workshopName: workshopName?.trim());
    try {
      await backend.updateProfile(updated);
      _currentUser = updated;
      if (updated.workshopName != null && updated.workshopName != me.workshopName) {
        _workshop = await backend.loadWorkshop(updated.workshopName!);
      }
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }
}

// ====================================================================== admin
extension AdminState on AppState {
  List<UserAccount> get users => List.unmodifiable(_users);

  int countRole(UserRole r) => _users.where((u) => u.role == r).length;

  List<MaintenanceRule> get allRules => List.unmodifiable(_rules);

  List<Activity> get activity {
    final list = [..._activity];
    // Accounts created in the last 7 days also show up as changes.
    final week = DateTime.now().subtract(const Duration(days: 7));
    for (final u in _users) {
      if (u.role == UserRole.mechanic && u.createdAt != null && u.createdAt!.isAfter(week)) {
        list.add(Activity('New mechanic registered', u.workshopName ?? u.fullName, 'wrench', u.createdAt!));
      }
    }
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  void _log(String title, String subtitle, String icon) =>
      _activity.add(Activity(title, subtitle, icon, DateTime.now()));

  Future<String?> addUser(
      {required String fullName, required String email, required String password, required UserRole role}) async {
    try {
      final u = await backend.addUser(fullName: fullName, email: email, password: password, role: role);
      _users.add(u);
      _log('User added', '${u.fullName} · ${role.label}', 'user');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> saveUser(UserAccount u) async {
    try {
      await backend.updateUser(u);
      _users[_users.indexWhere((x) => x.id == u.id)] = u;
      if (u.id == _currentUser?.id) _currentUser = u;
      _log('User updated', '${u.fullName} · ${u.role.label}', 'user');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> deleteUser(UserAccount u) async {
    if (u.id == _currentUser?.id) return "You can't delete your own account.";
    try {
      await backend.deleteUser(u.id);
      _users.removeWhere((x) => x.id == u.id);
      _log('User deleted', u.fullName, 'trash');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<(CatalogModel?, String?)> saveModel(CatalogModel m) async {
    try {
      final saved = await backend.saveCatalogModel(m);
      final i = _catalog.indexWhere((c) => c.id == saved.id);
      if (i >= 0) {
        _catalog[i] = saved;
        _log('Model updated', '${saved.name} · ${saved.year}', 'bike');
      } else {
        _catalog.add(saved);
        _log('Model added', '${saved.name} · ${saved.year}', 'bike');
      }
      _changed();
      return (saved, null);
    } catch (e) {
      return (null, AppState.friendlyError(e));
    }
  }

  Future<String?> deleteModel(CatalogModel m) async {
    try {
      await backend.deleteCatalogModel(m.id);
      _catalog.removeWhere((c) => c.id == m.id);
      _rules.removeWhere((r) => r.catalogId == m.id);
      _log('Model deleted', '${m.name} · ${m.year}', 'trash');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> saveRule(MaintenanceRule r) async {
    try {
      final saved = await backend.saveRule(r);
      final i = _rules.indexWhere((x) => x.id == saved.id);
      final model = _catalog.firstWhere((c) => c.id == saved.catalogId).name;
      if (i >= 0) {
        _rules[i] = saved;
        _log('Rule updated', '${saved.componentName} · $model', 'sliders');
      } else {
        _rules.add(saved);
        _log('Rule added', '${saved.componentName} · $model', 'sliders');
      }
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> deleteRule(MaintenanceRule r) async {
    try {
      await backend.deleteRule(r.id);
      _rules.removeWhere((x) => x.id == r.id);
      final model = _catalog.where((c) => c.id == r.catalogId).firstOrNull?.name ?? '';
      _log('Rule deleted', '${r.componentName} · $model', 'trash');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }
}

/// Makes [AppState] available to every screen and rebuilds them on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
