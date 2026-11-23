import '../models/models.dart';

/// An error with a message that can be shown to the user as-is.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the app reads and writes its data. [MockBackend] keeps everything in
/// memory; [SupabaseBackend] talks to the Supabase project.
abstract class Backend {
  bool get isDemo;

  /// Returns the signed-in user when a previous session is still valid.
  Future<UserAccount?> restoreSession();

  Future<UserAccount> signIn(String email, String password);

  /// Returns true when the user must confirm their email before logging in.
  /// Admin accounts need a valid [staffCode]; mechanics give their [workshopName].
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    UserRole role = UserRole.owner,
    String? workshopName,
    String? staffCode,
  });

  Future<void> signOut();

  Future<(List<CatalogModel>, List<MaintenanceRule>)> loadCatalog();

  Future<List<Motorcycle>> loadMotorcycles(String userId);

  Future<List<MaintenanceRecord>> loadRecords(List<String> motorcycleIds);

  Future<Motorcycle> addMotorcycle({
    required String ownerId,
    required String catalogId,
    required String plate,
    required int odometer,
  });

  Future<void> updateOdometer(String motorcycleId, int odometer, DateTime date);

  Future<MaintenanceRecord> addRecord({
    required String userId,
    required String motorcycleId,
    required DateTime date,
    required int odometer,
    required Map<String, String> items,
    String? workshop,
    Receipt? receipt,
    String? recordedByName,
  });

  /// A temporary link to view a receipt stored online, or null.
  Future<String?> receiptUrl(Receipt receipt);

  // ------------------------------------------------------------ mechanic
  /// Every registered motorcycle (mechanics search them by plate).
  Future<List<Motorcycle>> loadAllMotorcycles();

  /// Motorcycle owners (names on records, "Select Owner" when adding a motorcycle).
  Future<List<UserAccount>> loadOwners();

  Future<List<ServiceJob>> loadJobs(String mechanicId);

  /// Inserts when [job] has an empty id, otherwise updates its status.
  Future<ServiceJob> saveJob(ServiceJob job);

  Future<List<Review>> loadReviews(String mechanicId);

  Future<Workshop?> loadWorkshop(String name);

  /// Personal Information: name, phone and workshop of the signed-in user.
  Future<void> updateProfile(UserAccount user);

  // ------------------------------------------------------------ admin
  Future<List<UserAccount>> loadUsers();

  Future<UserAccount> addUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? workshopName,
  });

  Future<void> updateUser(UserAccount user);

  Future<void> deleteUser(String userId);

  /// Inserts when [model] has an empty id, otherwise updates. Returns the saved model.
  Future<CatalogModel> saveCatalogModel(CatalogModel model);

  Future<void> deleteCatalogModel(String id);

  /// Inserts when [rule] has an empty id, otherwise updates. Returns the saved rule.
  Future<MaintenanceRule> saveRule(MaintenanceRule rule);

  Future<void> deleteRule(String id);
}
