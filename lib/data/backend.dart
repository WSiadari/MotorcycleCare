import '../models/models.dart';

/// An error with a message that can be shown to the user as-is.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Data access for the app.
/// [MockBackend] keeps everything in memory; [SupabaseBackend] talks to the Supabase project.
abstract class Backend {
  bool get isDemo;

  // ---------------------------------------------------------------- accounts
  /// Returns the signed-in user when a previous session is still valid.
  Future<UserAccount?> restoreSession();

  Future<UserAccount> signIn(String email, String password);

  /// Returns true when the user must confirm their email before logging in.
  /// Mechanics give their [workshopName]; Admin accounts need a valid [staffCode].
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    UserRole role = UserRole.owner,
    String? workshopName,
    String? staffCode,
  });

  Future<void> signOut();

  /// Personal information, the mechanic's workshop and the owner's notification setting.
  Future<UserAccount> updateProfile({
    required UserAccount user,
    required String fullName,
    String? phone,
    String? workshopName,
    bool? notificationEnabled,
  });

  // ---------------------------------------------------------------- catalog
  Future<(List<MotorcycleCatalog>, List<MaintenanceRule>)> loadCatalog();

  // ---------------------------------------------------------------- motorcycles
  Future<List<Motorcycle>> loadMotorcycles(String ownerId);

  /// Every registered motorcycle (mechanics search them by plate).
  Future<List<Motorcycle>> loadAllMotorcycles();

  /// Saves the motorcycle and its first odometer reading.
  Future<(Motorcycle, OdometerReading)> addMotorcycle({
    required String ownerId,
    required String catalogId,
    required String plateNumber,
    required int odometerKm,
  });

  // ---------------------------------------------------------------- odometer
  Future<List<OdometerReading>> loadOdometerReadings(List<String> motorcycleIds);

  /// Saves a reading; the motorcycle's current odometer follows it.
  Future<OdometerReading> addOdometerReading({
    required String motorcycleId,
    required int valueKm,
    required String recordedBy,
  });

  // ---------------------------------------------------------------- service records
  Future<List<ServiceRecord>> loadServiceRecords(List<String> motorcycleIds);

  /// Saves [record] with its items and, when [ServiceRecord.receipt] has a local file, the receipt.
  /// Servicing a component also closes its reminders.
  Future<ServiceRecord> addServiceRecord(ServiceRecord record);

  /// A temporary link to view a receipt stored online, or null.
  Future<String?> receiptUrl(ServiceReceipt receipt);

  // ---------------------------------------------------------------- reminders
  Future<List<Reminder>> loadReminders(List<String> motorcycleIds);

  /// Saves the reminders that do not exist yet (same motorcycle, rule and status) and returns them.
  Future<List<Reminder>> addReminders(List<Reminder> reminders);

  Future<void> markReminderRead(String reminderId, DateTime readAt);

  // ---------------------------------------------------------------- jobs + reviews
  /// Motorcycle owners (for mechanics adding a motorcycle and for names on records).
  Future<List<MotorcycleOwner>> loadOwners();

  Future<List<ServiceJob>> loadJobs(String mechanicId);

  /// Inserts when [job] has an empty id, otherwise updates its status.
  Future<ServiceJob> saveJob(ServiceJob job);

  Future<List<Review>> loadReviews({String? mechanicId, String? ownerId});

  Future<Review> addReview(Review review);

  // ---------------------------------------------------------------- admin
  Future<List<UserAccount>> loadUsers();

  Future<UserAccount> addUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? workshopName,
  });

  /// Saves name, phone, role, active and workshop. Returns the saved account.
  Future<UserAccount> updateUser(UserAccount user);

  Future<void> deleteUser(String userId);

  /// Inserts when [model] has an empty id, otherwise updates. Returns the saved model.
  Future<MotorcycleCatalog> saveCatalogModel(MotorcycleCatalog model);

  Future<void> deleteCatalogModel(String catalogId);

  /// Inserts when [rule] has an empty id, otherwise updates. Returns the saved rule.
  Future<MaintenanceRule> saveRule(MaintenanceRule rule);

  Future<void> deleteRule(String ruleId);

  /// Newest first.
  Future<List<ActivityLog>> loadActivityLogs();

  Future<ActivityLog> addActivityLog(ActivityLog log);

  /// Users per role, models per type and rules per model.
  Future<SystemReport> loadSystemReport();
}
