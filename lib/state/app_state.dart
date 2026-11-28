import 'package:flutter/widgets.dart';

import '../data/backend.dart';
import '../data/mock_backend.dart';
import '../models/models.dart';
import '../services/reminder_notifier.dart';
import '../utils/format.dart';

/// App state shared by all screens. Data comes from a [Backend] (demo or Supabase) and is cached
/// here. Mechanic and admin methods are in the [MechanicState] and [AdminState] extensions.
class AppState extends ChangeNotifier {
  AppState(this.backend, {ReminderNotifier? notifier}) : notifier = notifier ?? const SilentReminderNotifier();

  /// Demo data, no setup needed.
  factory AppState.seeded({ReminderNotifier? notifier}) => AppState(MockBackend(), notifier: notifier);

  final Backend backend;
  final ReminderNotifier notifier;

  List<MotorcycleCatalog> _catalog = [];
  List<MaintenanceRule> _rules = [];
  List<Motorcycle> _motorcycles = [];
  List<OdometerReading> _readings = [];
  List<ServiceRecord> _records = [];
  List<Reminder> _reminders = [];
  List<UserAccount> _users = []; // admin: all accounts · mechanic: owners
  List<ServiceJob> _jobs = [];
  List<Review> _reviews = []; // mechanic: reviews of me · owner: reviews I wrote
  List<ActivityLog> _activity = [];
  final List<String> _recentSearches = [];

  UserAccount? _currentUser;
  String? _selectedId;

  static const maxOdometerJump = OdometerReading.maxJumpKm;

  void _changed() => notifyListeners();

  static String friendlyError(Object e) {
    if (e is BackendException) return e.message;
    debugPrint('MotorcycleCare error: $e');
    return 'Something went wrong. Check your internet connection and try again.';
  }

  /// Loads the data the signed-in role needs.
  Future<void> _loadData() async {
    final me = _currentUser!;
    final (catalog, rules) = await backend.loadCatalog();
    _catalog = catalog;
    _rules = rules;
    switch (me) {
      case MotorcycleOwner():
        _motorcycles = await backend.loadMotorcycles(me.userId);
        final ids = _motorcycles.map((m) => m.motorcycleId).toList();
        _readings = await backend.loadOdometerReadings(ids);
        _records = await backend.loadServiceRecords(ids);
        _reminders = await backend.loadReminders(ids);
        _reviews = await backend.loadReviews(ownerId: me.userId);
        // Store reminders for components that became due.
        for (final m in _motorcycles) {
          await syncReminders(m);
        }
      case Mechanic():
        _motorcycles = await backend.loadAllMotorcycles();
        final ids = _motorcycles.map((m) => m.motorcycleId).toList();
        _readings = await backend.loadOdometerReadings(ids);
        _records = await backend.loadServiceRecords(ids);
        _users = await backend.loadOwners();
        _jobs = await backend.loadJobs(me.userId);
        _reviews = await backend.loadReviews(mechanicId: me.userId);
      case Admin():
        _users = await backend.loadUsers();
        _activity = await backend.loadActivityLogs();
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

  /// Opens the app straight to the dashboard when the last session is still valid.
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

  /// Creates an account. Returns (error, needsEmailConfirmation).
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
    _readings = [];
    _records = [];
    _reminders = [];
    _users = [];
    _jobs = [];
    _reviews = [];
    _activity = [];
    _recentSearches.clear();
    notifyListeners();
  }

  /// Saves name and phone, the mechanic's workshop and the owner's notification setting.
  Future<String?> updateMyProfile({
    required String fullName,
    String? phone,
    String? workshopName,
    bool? notificationEnabled,
  }) async {
    final me = _currentUser!;
    if (fullName.trim().isEmpty) return 'Enter your full name.';
    if (me is Mechanic && workshopName != null && workshopName.trim().isEmpty) return 'Enter the workshop name.';
    try {
      _currentUser = await backend.updateProfile(
        user: me,
        fullName: fullName,
        phone: phone,
        workshopName: me is Mechanic ? workshopName : null,
        notificationEnabled: me is MotorcycleOwner ? notificationEnabled : null,
      );
      _changed();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ---------------------------------------------------------------- catalog
  List<MotorcycleCatalog> get catalog => List.unmodifiable(_catalog);

  MotorcycleCatalog catalogOf(Motorcycle m) => _catalog.firstWhere((c) => c.catalogId == m.catalogId);

  List<MaintenanceRule> rulesForCatalog(String catalogId) => _rules.where((r) => r.catalogId == catalogId).toList();

  List<MaintenanceRule> rulesFor(Motorcycle m) => rulesForCatalog(m.catalogId);

  MaintenanceRule ruleFor(Motorcycle m, String componentKey) =>
      rulesFor(m).firstWhere((r) => r.componentKey == componentKey);

  MaintenanceRule? ruleById(String ruleId) => _rules.where((r) => r.ruleId == ruleId).firstOrNull;

  // ---------------------------------------------------------------- motorcycles
  List<Motorcycle> get myMotorcycles =>
      _currentUser == null ? const [] : _motorcycles.where((m) => m.ownerId == _currentUser!.userId).toList();

  Motorcycle? get selected => _motorcycles.where((m) => m.motorcycleId == _selectedId).firstOrNull;

  void selectMotorcycle(String motorcycleId) {
    _selectedId = motorcycleId;
    notifyListeners();
  }

  static final _plateRe = RegExp(r'^[A-Z]{1,2} ?\d{1,4} ?[A-Z]{0,3}$');

  static String normalizePlate(String raw) {
    final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final m = RegExp(r'^([A-Z]{1,2})(\d{1,4})([A-Z]{0,3})$').firstMatch(compact);
    if (m == null) return raw.trim().toUpperCase();
    return [m.group(1), m.group(2), m.group(3)].where((g) => g != null && g.isNotEmpty).join(' ');
  }

  /// Plate as written on the motorcycle: letters, digits, letters — spaces only between the groups.
  static String? validatePlate(String? v) {
    final raw = (v ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return 'Enter the plate number.';
    if (!_plateRe.hasMatch(raw) || !_plateRe.hasMatch(normalizePlate(raw))) {
      return 'Use the format on your plate, e.g. B 4521 KXR.';
    }
    return null;
  }

  /// Returns an error message, or null and selects the new motorcycle.
  /// A mechanic registers it for a customer ([ownerId]); an owner for themselves.
  Future<String?> addMotorcycle({
    required String catalogId,
    required String plateNumber,
    required int odometerKm,
    String? ownerId,
  }) async {
    final p = normalizePlate(plateNumber);
    if (_motorcycles.any((m) => m.plateNumber == p)) return 'Plate $p is already registered in MotorcycleCare.';
    if (odometerKm < 0 || odometerKm > 500000) return 'Odometer must be between 0 and 500,000 km.';
    try {
      final (moto, first) = await backend.addMotorcycle(
        ownerId: ownerId ?? _currentUser!.userId,
        catalogId: catalogId,
        plateNumber: p,
        odometerKm: odometerKm,
      );
      _motorcycles.add(moto);
      _readings.add(first);
      _selectedId = moto.motorcycleId;
      notifyListeners();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ---------------------------------------------------------------- odometer
  String? validateOdometer(Motorcycle m, int? valueKm) => OdometerReading.validate(m, valueKm);

  /// Newest first.
  List<OdometerReading> readingsFor(Motorcycle m) =>
      _readings.where((r) => r.motorcycleId == m.motorcycleId).toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  /// The reading saved when the motorcycle was registered: the status baseline of components
  /// that were never serviced.
  OdometerReading firstReadingOf(Motorcycle m) {
    final list = _readings.where((r) => r.motorcycleId == m.motorcycleId).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return list.firstOrNull ??
        OdometerReading(
            readingId: '', motorcycleId: m.motorcycleId, valueKm: m.currentOdometer, recordedAt: m.createdAt);
  }

  Future<String?> _saveReading(Motorcycle m, int valueKm) async {
    try {
      final reading =
          await backend.addOdometerReading(motorcycleId: m.motorcycleId, valueKm: valueKm, recordedBy: _currentUser!.userId);
      if (!_readings.any((r) => r.readingId == reading.readingId)) _readings.add(reading);
      m.applyReading(reading);
      await syncReminders(m);
      notifyListeners();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Validates and saves a new reading. Returns an error message, or null.
  Future<String?> updateOdometer(Motorcycle m, int valueKm) async {
    final err = validateOdometer(m, valueKm);
    if (err != null) return err;
    return _saveReading(m, valueKm);
  }

  /// Saves the current value again as a confirmed reading.
  Future<String?> confirmOdometer(Motorcycle m) => _saveReading(m, m.currentOdometer);

  // ---------------------------------------------------------------- status
  /// Newest first (by odometer, then date).
  List<ServiceRecord> recordsFor(Motorcycle m) {
    final list = _records.where((r) => r.motorcycleId == m.motorcycleId).toList()
      ..sort((a, b) {
        final byKm = b.odometerKm.compareTo(a.odometerKm);
        return byKm != 0 ? byKm : b.serviceDate.compareTo(a.serviceDate);
      });
    return list;
  }

  ServiceRecord? lastServiceOf(Motorcycle m, String componentKey) =>
      recordsFor(m).where((r) => r.covers(componentKey)).firstOrNull;

  /// Status of one component.
  ComponentStatus statusOf(Motorcycle m, MaintenanceRule rule) {
    final last = lastServiceOf(m, rule.componentKey);
    final first = firstReadingOf(m);
    return ComponentStatus.calculate(
      rule: rule,
      currentKm: m.currentOdometer,
      baseKm: last?.odometerKm ?? first.valueKm,
      baseDate: last?.serviceDate ?? first.recordedAt,
      lastRecord: last,
      today: today(),
    );
  }

  List<ComponentStatus> statusesFor(Motorcycle m) => rulesFor(m).map((r) => statusOf(m, r)).toList();

  /// Most urgent status of a motorcycle (for list badges).
  MaintenanceStatus worstStatus(Motorcycle m) {
    final all = statusesFor(m);
    if (all.any((s) => s.status == MaintenanceStatus.overdue)) return MaintenanceStatus.overdue;
    if (all.any((s) => s.status == MaintenanceStatus.dueSoon)) return MaintenanceStatus.dueSoon;
    return MaintenanceStatus.onTrack;
  }

  /// Component keys serviced today (shown on the dashboard after a service).
  Set<String> servicedToday(Motorcycle m) => {
        for (final r in recordsFor(m))
          if (dateOnly(r.serviceDate) == today()) ...r.componentKeys,
      };

  /// Components that are due soon or overdue, most urgent first.
  List<ComponentStatus> alertsFor(Motorcycle m) {
    final list = statusesFor(m).where((s) => s.status != MaintenanceStatus.onTrack).toList()
      ..sort((a, b) => b.status.index.compareTo(a.status.index));
    return list;
  }

  // ---------------------------------------------------------------- reminders
  /// Stored reminders of [m], newest first.
  List<Reminder> remindersFor(Motorcycle m) => _reminders.where((r) => r.motorcycleId == m.motorcycleId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadReminders(Motorcycle m) => remindersFor(m).where((r) => !r.isRead).length;

  /// The stored reminder behind a component status, if any.
  Reminder? reminderFor(Motorcycle m, ComponentStatus s) => remindersFor(m)
      .where((r) => r.ruleId == s.rule.ruleId && r.dueStatus == s.status)
      .firstOrNull;

  /// Stores the missing reminders for due-soon and overdue components and, for the owner's own
  /// motorcycle with notifications on, shows a local notification. Returns the new reminders.
  Future<List<Reminder>> syncReminders(Motorcycle m) async {
    final now = DateTime.now();
    final candidates = <Reminder>[
      for (final s in statusesFor(m))
        if (Reminder.fromStatus(m, s, now: now) case final r? when !_reminders.any(r.sameKey)) r,
    ];
    if (candidates.isEmpty) return const [];
    try {
      final created = await backend.addReminders(candidates);
      _reminders.addAll(created.where((c) => !_reminders.any(c.sameKey)));
      final me = _currentUser;
      if (me is MotorcycleOwner && me.notificationEnabled && m.ownerId == me.userId) {
        final title = '${catalogOf(m).name} · ${m.plateNumber}';
        for (final r in created) {
          await notifier.show(r, title: title);
        }
      }
      return created;
    } catch (e) {
      debugPrint('Reminder sync failed: $e');
      return const [];
    }
  }

  Future<void> markReminderRead(Reminder r) async {
    if (r.isRead) return;
    final readAt = DateTime.now();
    try {
      await backend.markReminderRead(r.reminderId, readAt);
      final i = _reminders.indexWhere((x) => x.reminderId == r.reminderId);
      if (i >= 0) _reminders[i] = r.copyWith(readAt: readAt);
      _changed();
    } catch (e) {
      debugPrint('Mark reminder read failed: $e');
    }
  }

  Future<void> markAllRemindersRead(Motorcycle m) async {
    for (final r in remindersFor(m).where((r) => !r.isRead)) {
      await markReminderRead(r);
    }
  }

  // ---------------------------------------------------------------- service records
  /// Lowest odometer allowed for a new record of the given components.
  int minServiceOdometer(Motorcycle m, Iterable<String> componentKeys) {
    var min = firstReadingOf(m).valueKm;
    for (final k in componentKeys) {
      final last = lastServiceOf(m, k);
      if (last != null && last.odometerKm > min) min = last.odometerKm;
    }
    return min;
  }

  /// Saves a service record. [items] maps component key to work description. A higher odometer
  /// is saved as a new reading and the reminders are updated. Returns (record, error).
  Future<(ServiceRecord?, String?)> saveRecord({
    required Motorcycle motorcycle,
    required DateTime serviceDate,
    required int odometerKm,
    required Map<String, String> items,
    String? workshopName,
    ServiceReceipt? receipt,
    bool syncReminders = true,
  }) async {
    final me = _currentUser!;
    if (receipt != null && receipt.localPath != null) {
      final err = ServiceReceipt.validateFile(fileName: receipt.fileName, sizeBytes: receipt.sizeBytes);
      if (err != null) return (null, err);
    }
    final rules = rulesFor(motorcycle);
    final draft = ServiceRecord(
      recordId: '',
      motorcycleId: motorcycle.motorcycleId,
      mechanicId: me is Mechanic ? me.userId : null,
      recordedByUserId: me.userId,
      serviceDate: dateOnly(serviceDate),
      odometerKm: odometerKm,
      workshopName: (workshopName == null || workshopName.trim().isEmpty) ? null : workshopName.trim(),
      items: [
        for (final r in rules)
          if (items.containsKey(r.componentKey))
            ServiceRecordItem(ruleId: r.ruleId, componentKey: r.componentKey, workDescription: items[r.componentKey]!),
      ],
      receipt: receipt,
    );
    try {
      final record = await backend.addServiceRecord(draft);
      _records.add(record.recordedByName == null ? record.copyWith(recordedByName: me.fullName) : record);
      // Same as the on_service_item_created trigger: close reminders of serviced components.
      final serviced = {for (final i in record.items) i.ruleId};
      _reminders.removeWhere((r) => r.motorcycleId == motorcycle.motorcycleId && serviced.contains(r.ruleId));
      if (odometerKm > motorcycle.currentOdometer) {
        final reading = await backend.addOdometerReading(
            motorcycleId: motorcycle.motorcycleId, valueKm: odometerKm, recordedBy: me.userId);
        _readings.add(reading);
        motorcycle.applyReading(reading);
      }
      if (syncReminders) await this.syncReminders(motorcycle);
      notifyListeners();
      return (_records.last, null);
    } catch (e) {
      return (null, friendlyError(e));
    }
  }

  // ---------------------------------------------------------------- reviews by the owner
  /// The owner may rate the mechanic who recorded [r] on their motorcycle.
  bool canRate(ServiceRecord r) => _currentUser is MotorcycleOwner && r.mechanicId != null;

  Review? myReviewOf(String mechanicId) =>
      _reviews.where((v) => v.mechanicId == mechanicId && v.ownerId == _currentUser?.userId).firstOrNull;

  Future<String?> rateMechanic({required ServiceRecord record, required int rating, required String comment}) async {
    if (!canRate(record)) return 'Only services recorded by a mechanic can be rated.';
    if (rating < 1 || rating > 5) return 'Choose 1 to 5 stars.';
    try {
      final saved = await backend.addReview(Review(
        mechanicId: record.mechanicId!,
        ownerId: _currentUser!.userId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      ));
      _reviews.add(saved);
      _changed();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }
}

// ====================================================================== mechanic
extension MechanicState on AppState {
  Mechanic? get currentMechanic => switch (_currentUser) { final Mechanic m => m, _ => null };

  UserAccount? ownerOf(Motorcycle m) => _users.where((u) => u.userId == m.ownerId).firstOrNull;

  List<UserAccount> get owners => _users.whereType<MotorcycleOwner>().toList()
    ..sort((a, b) => a.fullName.compareTo(b.fullName));

  Motorcycle? motorcycleById(String motorcycleId) =>
      _motorcycles.where((m) => m.motorcycleId == motorcycleId).firstOrNull;

  /// Finds a motorcycle by plate. Returns null when the plate is not registered.
  Motorcycle? findByPlate(String plateNumber) {
    final p = AppState.normalizePlate(plateNumber);
    final m = _motorcycles.where((m) => m.plateNumber == p).firstOrNull;
    if (m != null) {
      _recentSearches
        ..remove(m.motorcycleId)
        ..insert(0, m.motorcycleId);
      _selectedId = m.motorcycleId;
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
  List<ServiceRecord> get myServices {
    final me = _currentUser?.userId;
    return _records.where((r) => r.recordedByUserId == me).toList()
      ..sort((a, b) => (b.createdAt ?? b.serviceDate).compareTo(a.createdAt ?? a.serviceDate));
  }

  List<ServiceRecord> servicesBetween(DateTime from, DateTime to) =>
      myServices.where((r) => !r.serviceDate.isBefore(from) && r.serviceDate.isBefore(to)).toList();

  List<ServiceRecord> get doneToday => servicesBetween(today(), today().add(const Duration(days: 1)));

  DateTime get weekStart => today().subtract(Duration(days: today().weekday - 1));

  List<ServiceRecord> get thisWeek => servicesBetween(weekStart, weekStart.add(const Duration(days: 7)));

  List<ServiceRecord> get thisMonth {
    final t = today();
    return servicesBetween(DateTime(t.year, t.month), DateTime(t.year, t.month + 1));
  }

  List<ServiceJob> get todaysJobs => _jobs.where((j) => j.status != JobStatus.done).toList()
    ..sort((a, b) =>
        a.status == b.status ? a.createdAt.compareTo(b.createdAt) : b.status.index.compareTo(a.status.index));

  ServiceJob? openJobFor(Motorcycle m) =>
      _jobs.where((j) => j.motorcycleId == m.motorcycleId && j.status != JobStatus.done).firstOrNull;

  /// Puts the motorcycle in the mechanic's queue as an in-progress job.
  Future<void> startJob(Motorcycle m, String note) async {
    try {
      final job = openJobFor(m);
      if (job == null) {
        _jobs.add(await backend.saveJob(ServiceJob(
          jobId: '',
          motorcycleId: m.motorcycleId,
          mechanicId: _currentUser!.userId,
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
    final ids = {
      ..._jobs.where((j) => j.status != JobStatus.done).map((j) => j.motorcycleId),
      ...myServices.map((r) => r.motorcycleId),
    };
    return [
      for (final id in ids)
        if (motorcycleById(id) case final m?)
          for (final s in statusesFor(m))
            if (s.status == MaintenanceStatus.overdue) (m, s),
    ];
  }

  /// Saves the mechanic's service record and closes the job. With [ServiceDraft.notifyOwner] on,
  /// the owner's reminders are updated right away.
  Future<(ServiceRecord?, String?)> saveService(ServiceDraft d) async {
    final desc = d.description.trim();
    final (record, err) = await saveRecord(
      motorcycle: d.motorcycle,
      serviceDate: d.serviceDate,
      odometerKm: d.odometerKm,
      items: {for (final k in d.components) k: desc.isEmpty ? 'Serviced' : desc},
      workshopName: currentMechanic?.workshopName ?? 'Workshop',
      receipt: d.receipt,
      syncReminders: d.notifyOwner,
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

  double get rating =>
      _reviews.isEmpty ? 0 : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  Workshop? get workshop => currentMechanic?.workshop;
}

// ====================================================================== admin
extension AdminState on AppState {
  List<UserAccount> get users => List.unmodifiable(_users);

  int countRole(UserRole r) => _users.where((u) => u.role == r).length;

  List<MaintenanceRule> get allRules => List.unmodifiable(_rules);

  /// Activity logs, newest first.
  List<ActivityLog> get activity => [..._activity]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _log(String title, String subtitle, String icon) async {
    try {
      _activity.add(await backend.addActivityLog(ActivityLog(
          actorId: _currentUser?.userId, title: title, subtitle: subtitle, icon: icon, createdAt: DateTime.now())));
    } catch (e) {
      debugPrint('Activity log failed: $e');
    }
  }

  Future<String?> addUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? workshopName,
  }) async {
    try {
      final u = await backend.addUser(
          fullName: fullName, email: email, password: password, role: role, workshopName: workshopName);
      _users.add(u);
      await _log('User added', '${u.fullName} · ${role.label}', 'user');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> saveUser(UserAccount u) async {
    if (u.userId == _currentUser?.userId && (u.role != UserRole.admin || !u.active)) {
      return "You can't change your own role or deactivate your own account.";
    }
    try {
      final saved = await backend.updateUser(u);
      _users[_users.indexWhere((x) => x.userId == saved.userId)] = saved;
      if (saved.userId == _currentUser?.userId) _currentUser = saved;
      await _log('User updated', '${saved.fullName} · ${saved.role.label}', 'user');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> deleteUser(UserAccount u) async {
    if (u.userId == _currentUser?.userId) return "You can't delete your own account.";
    try {
      await backend.deleteUser(u.userId);
      _users.removeWhere((x) => x.userId == u.userId);
      await _log('User deleted', u.fullName, 'trash');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<(MotorcycleCatalog?, String?)> saveModel(MotorcycleCatalog m) async {
    try {
      final saved = await backend.saveCatalogModel(m);
      final i = _catalog.indexWhere((c) => c.catalogId == saved.catalogId);
      if (i >= 0) {
        _catalog[i] = saved;
        await _log('Model updated', '${saved.name} · ${saved.modelYear}', 'bike');
      } else {
        _catalog.add(saved);
        await _log('Model added', '${saved.name} · ${saved.modelYear}', 'bike');
      }
      _changed();
      return (saved, null);
    } catch (e) {
      return (null, AppState.friendlyError(e));
    }
  }

  Future<String?> deleteModel(MotorcycleCatalog m) async {
    try {
      await backend.deleteCatalogModel(m.catalogId);
      _catalog.removeWhere((c) => c.catalogId == m.catalogId);
      _rules.removeWhere((r) => r.catalogId == m.catalogId);
      await _log('Model deleted', '${m.name} · ${m.modelYear}', 'trash');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> saveRule(MaintenanceRule r) async {
    try {
      final saved = await backend.saveRule(r);
      final i = _rules.indexWhere((x) => x.ruleId == saved.ruleId);
      final model = _catalog.firstWhere((c) => c.catalogId == saved.catalogId).name;
      if (i >= 0) {
        _rules[i] = saved;
        await _log('Rule updated', '${saved.componentName} · $model', 'sliders');
      } else {
        _rules.add(saved);
        await _log('Rule added', '${saved.componentName} · $model', 'sliders');
      }
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  Future<String?> deleteRule(MaintenanceRule r) async {
    try {
      await backend.deleteRule(r.ruleId);
      _rules.removeWhere((x) => x.ruleId == r.ruleId);
      final model = _catalog.where((c) => c.catalogId == r.catalogId).firstOrNull?.name ?? '';
      await _log('Rule deleted', '${r.componentName} · $model', 'trash');
      _changed();
      return null;
    } catch (e) {
      return AppState.friendlyError(e);
    }
  }

  /// Loads the system report. Returns (report, error).
  Future<(SystemReport?, String?)> loadSystemReport() async {
    try {
      return (await backend.loadSystemReport(), null);
    } catch (e) {
      return (null, AppState.friendlyError(e));
    }
  }
}

/// Makes [AppState] available to every screen and rebuilds them on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
