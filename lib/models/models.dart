enum MotoType { matic, underbone, sport, trail }

extension MotoTypeLabel on MotoType {
  String get label => switch (this) {
        MotoType.matic => 'Matic',
        MotoType.underbone => 'Underbone',
        MotoType.sport => 'Sport',
        MotoType.trail => 'Trail',
      };
}

/// A motorcycle model managed by the Admin in the catalog.
class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.make,
    required this.model,
    required this.type,
    required this.year,
  });

  final String id;
  final String make;
  final String model;
  final MotoType type;
  final int year;

  String get name => '$make $model';

  CatalogModel copyWith({String? id}) => CatalogModel(id: id ?? this.id, make: make, model: model, type: type, year: year);
}

/// A service interval set by the Admin for one catalog model.
class MaintenanceRule {
  const MaintenanceRule({
    required this.id,
    required this.catalogId,
    required this.componentKey,
    required this.componentName,
    required this.intervalKm,
    required this.intervalMonths,
    required this.source,
    this.price = 0,
  });

  final String id;
  final String catalogId;
  final String componentKey;
  final String componentName;
  final int intervalKm;
  final int intervalMonths;
  final String source;

  /// Typical workshop price, only used to draw sample receipts.
  final int price;

  MaintenanceRule copyWith({String? id}) => MaintenanceRule(
        id: id ?? this.id,
        catalogId: catalogId,
        componentKey: componentKey,
        componentName: componentName,
        intervalKm: intervalKm,
        intervalMonths: intervalMonths,
        source: source,
        price: price,
      );
}

/// A line in the admin "Recent changes" list.
class Activity {
  const Activity(this.title, this.subtitle, this.icon, this.at);

  final String title, subtitle, icon;
  final DateTime at;
}

/// The three actors of the use case diagram. One app, a different home screen per role.
enum UserRole { owner, mechanic, admin }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.owner => 'Motorcycle Owner',
        UserRole.mechanic => 'Mechanic',
        UserRole.admin => 'Admin',
      };

  String get plural => switch (this) {
        UserRole.owner => 'Owners',
        UserRole.mechanic => 'Mechanics',
        UserRole.admin => 'Admins',
      };
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.fullName,
    required this.email,
    this.password = '',
    this.role = UserRole.owner,
    this.workshopName,
    this.active = true,
    this.createdAt,
    this.phone,
  });

  final String id;
  final String fullName;
  final String email;
  final String password; // demo data only; Supabase Auth keeps real passwords
  final UserRole role;
  final String? workshopName; // mechanics only
  final bool active;
  final DateTime? createdAt;
  final String? phone;

  String get firstName => fullName.split(' ').first;

  UserAccount copyWith({String? fullName, UserRole? role, String? workshopName, bool? active, String? phone}) =>
      UserAccount(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email,
        password: password,
        role: role ?? this.role,
        workshopName: (role ?? this.role) == UserRole.mechanic ? (workshopName ?? this.workshopName) : null,
        active: active ?? this.active,
        createdAt: createdAt,
        phone: phone ?? this.phone,
      );
}

class Motorcycle {
  Motorcycle({
    required this.id,
    required this.ownerId,
    required this.catalogId,
    required this.plate,
    required this.odometer,
    required this.odometerUpdatedAt,
    required this.registrationOdometer,
    required this.registeredAt,
  });

  final String id;
  final String ownerId;
  final String catalogId;
  final String plate;
  int odometer;
  DateTime odometerUpdatedAt;
  final int registrationOdometer;
  final DateTime registeredAt;
}

class Receipt {
  const Receipt({required this.name, this.path, this.storagePath, this.sizeBytes = 0, this.isSample = false});

  final String name;
  final String? path; // picked image on this device
  final String? storagePath; // file in the Supabase "receipts" bucket
  final int sizeBytes;
  final bool isSample; // demo data without a real file

  Receipt withStoragePath(String p) =>
      Receipt(name: name, path: path, storagePath: p, sizeBytes: sizeBytes, isSample: isSample);
}

class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.motorcycleId,
    required this.date,
    required this.odometer,
    required this.items,
    this.workshop,
    this.receipt,
    this.recordedBy,
    this.recordedByName,
    this.createdAt,
  });

  final String id;
  final String motorcycleId;
  final DateTime date;
  final int odometer;

  /// componentKey -> work description
  final Map<String, String> items;

  /// null = done by the owner
  final String? workshop;
  final Receipt? receipt;

  /// User id of whoever saved the record (owner or mechanic).
  final String? recordedBy;
  final String? recordedByName;

  /// When the record was saved (used for "Completed at 08:20").
  final DateTime? createdAt;

  /// Work descriptions without duplicates (a mechanic writes one note for all parts).
  String get description => items.values.where((v) => v.trim().isNotEmpty).toSet().join(' ');

  bool get byMechanic => workshop != null && workshop!.isNotEmpty;
  String get loggedBy => byMechanic ? workshop! : 'You';
}

enum Health { onTrack, dueSoon, overdue }

class ComponentStatus {
  const ComponentStatus({
    required this.rule,
    required this.lastRecord,
    required this.baseKm,
    required this.baseDate,
    required this.usedKm,
    required this.kmPercent,
    required this.timePercent,
    required this.health,
    required this.nextKm,
    required this.nextDate,
  });

  final MaintenanceRule rule;
  final MaintenanceRecord? lastRecord;
  final int baseKm;
  final DateTime baseDate;
  final int usedKm;
  final double kmPercent;
  final double timePercent;
  final Health health;
  final int nextKm;
  final DateTime nextDate;

  int kmLeft(int odometer) => nextKm - odometer;
}

// ------------------------------------------------------------------ mechanic
enum JobStatus { waiting, inProgress, done }

/// A motorcycle in the mechanic's queue ("Today's Jobs").
class ServiceJob {
  ServiceJob({
    required this.id,
    required this.motorcycleId,
    required this.mechanicId,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String motorcycleId;
  final String mechanicId;
  final String note;
  JobStatus status;
  final DateTime createdAt;
}

/// An owner's review of a mechanic.
class Review {
  const Review({required this.ownerName, required this.rating, required this.comment, required this.createdAt});

  final String ownerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
}

class Workshop {
  const Workshop({required this.name, this.address, this.city, this.hours, this.phone, this.closesAt});

  final String name;
  final String? address, city, hours, phone, closesAt;
}

/// Everything filled in during the mechanic's "Record Service Details" step.
class ServiceDraft {
  ServiceDraft({required this.motorcycle, required this.components, required this.date, required this.odometer});

  final Motorcycle motorcycle;
  Set<String> components;
  DateTime date;
  int odometer;
  String description = '';
  Receipt? receipt;
  bool notifyOwner = true;
}
