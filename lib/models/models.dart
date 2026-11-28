// Domain model. Field names are the columns of supabase/schema.sql in camelCase; ids are
// Strings (uuid or bigint in the database). "Derived" fields are joined from another table.
import '../utils/format.dart';

// ====================================================================== enums
/// Account role (roles.role_name).
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

/// motorcycle_catalog.motorcycle_type
enum MotorcycleType { matic, underbone, sport, trail }

extension MotorcycleTypeLabel on MotorcycleType {
  String get label => switch (this) {
        MotorcycleType.matic => 'Matic',
        MotorcycleType.underbone => 'Underbone',
        MotorcycleType.sport => 'Sport',
        MotorcycleType.trail => 'Trail',
      };
}

/// Maintenance status of a component. reminders.due_status stores dueSoon and overdue.
enum MaintenanceStatus {
  onTrack,
  dueSoon,
  overdue;

  /// dueSoon from 80 % of the interval, overdue from 100 % (km or months, whichever is higher).
  static const dueSoonPercent = 80.0;

  static MaintenanceStatus fromPercent(double usedPercent) => usedPercent >= 100
      ? MaintenanceStatus.overdue
      : usedPercent >= dueSoonPercent
          ? MaintenanceStatus.dueSoon
          : MaintenanceStatus.onTrack;
}

/// service_jobs.status
enum JobStatus { waiting, inProgress, done }

// ====================================================================== accounts
/// roles: fixed reference rows (owner, mechanic, admin). Not edited in the app.
class Role {
  const Role({required this.roleId, required this.roleName, required this.description});

  final int roleId;
  final UserRole roleName;
  final String description;

  static const all = [
    Role(roleId: 1, roleName: UserRole.owner, description: 'Manages own motorcycles, odometer and maintenance records'),
    Role(roleId: 2, roleName: UserRole.mechanic, description: 'Searches motorcycles by plate and records services'),
    Role(roleId: 3, roleName: UserRole.admin, description: 'Manages users, the motorcycle catalog and maintenance rules'),
  ];

  static Role of(UserRole roleName) => all.firstWhere((r) => r.roleName == roleName);
}

/// user_accounts. Passwords are kept by Supabase Auth, not in this class.
/// Each role is a subclass with the columns of its own table.
sealed class UserAccount {
  const UserAccount({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phone,
    this.active = true,
    this.createdAt,
  });

  /// Builds the subclass that belongs to [role].
  factory UserAccount.create({
    required UserRole role,
    required String userId,
    required String email,
    required String fullName,
    String? phone,
    bool active = true,
    DateTime? createdAt,
    bool notificationEnabled = true,
    Workshop? workshop,
    String? staffCode,
  }) =>
      switch (role) {
        UserRole.owner => MotorcycleOwner(
            userId: userId,
            email: email,
            fullName: fullName,
            phone: phone,
            active: active,
            createdAt: createdAt,
            notificationEnabled: notificationEnabled),
        UserRole.mechanic => Mechanic(
            userId: userId,
            email: email,
            fullName: fullName,
            phone: phone,
            active: active,
            createdAt: createdAt,
            workshop: workshop),
        UserRole.admin => Admin(
            userId: userId,
            email: email,
            fullName: fullName,
            phone: phone,
            active: active,
            createdAt: createdAt,
            staffCode: staffCode),
      };

  final String userId;
  final String email;
  final String fullName;
  final String? phone;
  final bool active;
  final DateTime? createdAt;

  UserRole get role;

  /// user_accounts.role_id
  int get roleId => Role.of(role).roleId;

  String get firstName => fullName.trim().split(' ').first;

  /// The same account with other values. A different [role] returns the matching subclass.
  UserAccount copyWith({
    String? fullName,
    String? phone,
    bool? active,
    UserRole? role,
    bool? notificationEnabled,
    Workshop? workshop,
    String? staffCode,
  }) {
    final me = this;
    return UserAccount.create(
      role: role ?? this.role,
      userId: userId,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      active: active ?? this.active,
      createdAt: createdAt,
      notificationEnabled: notificationEnabled ?? (me is MotorcycleOwner ? me.notificationEnabled : true),
      workshop: workshop ?? (me is Mechanic ? me.workshop : null),
      staffCode: staffCode ?? (me is Admin ? me.staffCode : null),
    );
  }
}

/// motorcycle_owners
class MotorcycleOwner extends UserAccount {
  const MotorcycleOwner({
    required super.userId,
    required super.email,
    required super.fullName,
    super.phone,
    super.active,
    super.createdAt,
    this.notificationEnabled = true,
  });

  /// Whether reminders are shown as local notifications.
  final bool notificationEnabled;

  @override
  UserRole get role => UserRole.owner;
}

/// mechanics
class Mechanic extends UserAccount {
  const Mechanic({
    required super.userId,
    required super.email,
    required super.fullName,
    super.phone,
    super.active,
    super.createdAt,
    this.workshop,
  });

  /// mechanics.workshop_id, with the workshop row joined.
  final Workshop? workshop;

  String? get workshopId => workshop?.workshopId;

  String? get workshopName => workshop?.name;

  @override
  UserRole get role => UserRole.mechanic;
}

/// admins
class Admin extends UserAccount {
  const Admin({
    required super.userId,
    required super.email,
    required super.fullName,
    super.phone,
    super.active,
    super.createdAt,
    this.staffCode,
  });

  /// The staff code used to register (null when another admin created the account).
  final String? staffCode;

  @override
  UserRole get role => UserRole.admin;
}

/// workshops
class Workshop {
  const Workshop({
    required this.workshopId,
    required this.name,
    this.address,
    this.city,
    this.hours,
    this.phone,
  });

  final String workshopId;
  final String name;
  final String? address, city, hours, phone;

  /// Closing time from [hours] ("Mon–Sat · 08:00–17:00" → "17:00").
  String? get closesAt => RegExp(r'(\d{1,2}:\d{2})\s*$').firstMatch(hours ?? '')?.group(1);
}

// ====================================================================== catalog
/// motorcycle_catalog: a motorcycle model managed by the Admin.
class MotorcycleCatalog {
  const MotorcycleCatalog({
    required this.catalogId,
    required this.motorcycleType,
    required this.make,
    required this.model,
    required this.modelYear,
  });

  final String catalogId;
  final MotorcycleType motorcycleType;
  final String make;
  final String model;
  final int modelYear;

  String get name => '$make $model';

  MotorcycleCatalog copyWith({String? catalogId}) => MotorcycleCatalog(
      catalogId: catalogId ?? this.catalogId,
      motorcycleType: motorcycleType,
      make: make,
      model: model,
      modelYear: modelYear);
}

/// maintenance_rules: a service interval set by the Admin for one catalog model.
class MaintenanceRule {
  const MaintenanceRule({
    required this.ruleId,
    required this.catalogId,
    required this.componentKey,
    required this.componentName,
    required this.intervalKm,
    required this.intervalMonths,
    required this.sourceReference,
  });

  final String ruleId;
  final String catalogId;
  final String componentKey;
  final String componentName;
  final int intervalKm;
  final int intervalMonths;
  final String sourceReference;

  MaintenanceRule copyWith({String? ruleId}) => MaintenanceRule(
        ruleId: ruleId ?? this.ruleId,
        catalogId: catalogId,
        componentKey: componentKey,
        componentName: componentName,
        intervalKm: intervalKm,
        intervalMonths: intervalMonths,
        sourceReference: sourceReference,
      );
}

// ====================================================================== motorcycles
/// motorcycles
class Motorcycle {
  Motorcycle({
    required this.motorcycleId,
    required this.ownerId,
    required this.catalogId,
    required this.plateNumber,
    required this.currentOdometer,
    required this.odometerUpdatedAt,
    required this.createdAt,
  });

  final String motorcycleId;
  final String ownerId;
  final String catalogId;
  final String plateNumber;
  int currentOdometer;
  DateTime odometerUpdatedAt;
  final DateTime createdAt;

  /// Same rule as the on_odometer_reading trigger: a reading moves the odometer forward.
  void applyReading(OdometerReading r) {
    if (r.motorcycleId != motorcycleId || r.valueKm < currentOdometer) return;
    currentOdometer = r.valueKm;
    odometerUpdatedAt = r.recordedAt;
  }
}

/// odometer_readings: every update or confirmation. The first one is written at registration.
class OdometerReading {
  const OdometerReading({
    required this.readingId,
    required this.motorcycleId,
    required this.valueKm,
    required this.recordedAt,
    this.recordedBy,
  });

  final String readingId;
  final String motorcycleId;
  final int valueKm;
  final DateTime recordedAt;
  final String? recordedBy;

  /// Bigger jumps than this are treated as a typing mistake.
  static const maxJumpKm = 20000;

  /// Returns an error message, or null when [valueKm] is valid.
  static String? validate(Motorcycle m, int? valueKm) {
    if (valueKm == null) return 'Enter the number shown on your odometer.';
    if (valueKm < m.currentOdometer) {
      return "Odometer can't be lower than the latest reading (${fmtKm(m.currentOdometer)}).";
    }
    if (valueKm - m.currentOdometer > maxJumpKm) return 'That jump looks too big. Check the number.';
    return null;
  }
}

// ====================================================================== service records
/// service_records
class ServiceRecord {
  const ServiceRecord({
    required this.recordId,
    required this.motorcycleId,
    this.mechanicId,
    this.recordedByUserId,
    required this.serviceDate,
    required this.odometerKm,
    this.workshopName,
    this.createdAt,
    this.items = const [],
    this.receipt,
    this.recordedByName,
  });

  final String recordId;
  final String motorcycleId;

  /// null = logged by the owner.
  final String? mechanicId;
  final String? recordedByUserId;
  final DateTime serviceDate;
  final int odometerKm;

  /// null = self-service.
  final String? workshopName;
  final DateTime? createdAt;

  /// service_record_items (1..*).
  final List<ServiceRecordItem> items;

  /// service_receipts (0..1).
  final ServiceReceipt? receipt;

  /// Derived: user_accounts.full_name of [recordedByUserId].
  final String? recordedByName;

  bool get byMechanic => mechanicId != null;

  bool get atWorkshop => workshopName != null && workshopName!.trim().isNotEmpty;

  Set<String> get componentKeys => {for (final i in items) i.componentKey};

  bool covers(String componentKey) => items.any((i) => i.componentKey == componentKey);

  String? workFor(String componentKey) => items.where((i) => i.componentKey == componentKey).firstOrNull?.workDescription;

  /// Work descriptions without duplicates (a mechanic writes one note for all parts).
  String get description =>
      items.map((i) => i.workDescription.trim()).where((v) => v.isNotEmpty).toSet().join(' ');

  ServiceRecord copyWith({
    String? recordId,
    DateTime? createdAt,
    List<ServiceRecordItem>? items,
    ServiceReceipt? receipt,
    String? recordedByName,
  }) =>
      ServiceRecord(
        recordId: recordId ?? this.recordId,
        motorcycleId: motorcycleId,
        mechanicId: mechanicId,
        recordedByUserId: recordedByUserId,
        serviceDate: serviceDate,
        odometerKm: odometerKm,
        workshopName: workshopName,
        createdAt: createdAt ?? this.createdAt,
        items: items ?? this.items,
        receipt: receipt ?? this.receipt,
        recordedByName: recordedByName ?? this.recordedByName,
      );
}

/// service_record_items: one serviced component of a record.
class ServiceRecordItem {
  const ServiceRecordItem({
    this.itemId = '',
    this.recordId = '',
    required this.ruleId,
    required this.componentKey,
    required this.workDescription,
  });

  final String itemId;
  final String recordId;
  final String ruleId;

  /// Derived: maintenance_rules.component_key of [ruleId].
  final String componentKey;
  final String workDescription;

  ServiceRecordItem copyWith({String? itemId, String? recordId}) => ServiceRecordItem(
        itemId: itemId ?? this.itemId,
        recordId: recordId ?? this.recordId,
        ruleId: ruleId,
        componentKey: componentKey,
        workDescription: workDescription,
      );
}

/// service_receipts: the optional photo of the workshop receipt (0..1 per record).
class ServiceReceipt {
  const ServiceReceipt({
    this.receiptId = '',
    this.recordId = '',
    required this.fileName,
    this.storagePath,
    this.uploadedAt,
    this.localPath,
    this.sizeBytes = 0,
  });

  final String receiptId;
  final String recordId;
  final String fileName;

  /// Path in the Supabase "receipts" bucket.
  final String? storagePath;
  final DateTime? uploadedAt;

  /// Not stored: the picked file on this device and its size, before upload.
  final String? localPath;
  final int sizeBytes;

  static const maxBytes = 5 * 1024 * 1024;
  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

  /// Demo receipts have no file: the app draws a sample receipt instead.
  bool get isSample => localPath == null && storagePath == null;

  String get extension {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return ext == 'jpeg' ? 'jpg' : ext;
  }

  String get mimeType => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  /// Checks a receipt file: JPG, PNG, WEBP or HEIC, at most 5 MB.
  /// Returns an error message, or null when the file can be attached.
  static String? validateFile({required String fileName, required int sizeBytes}) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (!allowedExtensions.contains(ext)) return 'Use a JPG, PNG, WEBP or HEIC photo.';
    if (sizeBytes <= 0) return 'The file is empty. Choose another photo.';
    if (sizeBytes > maxBytes) return 'File is larger than 5 MB. Choose a smaller photo.';
    return null;
  }

  ServiceReceipt copyWith({String? receiptId, String? recordId, String? storagePath, DateTime? uploadedAt}) =>
      ServiceReceipt(
        receiptId: receiptId ?? this.receiptId,
        recordId: recordId ?? this.recordId,
        fileName: fileName,
        storagePath: storagePath ?? this.storagePath,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        localPath: localPath,
        sizeBytes: sizeBytes,
      );
}

// ====================================================================== status + reminders
/// Calculated status of one component (not stored).
class ComponentStatus {
  const ComponentStatus({
    required this.rule,
    required this.lastRecord,
    required this.baseKm,
    required this.baseDate,
    required this.usedKm,
    required this.kmPercent,
    required this.timePercent,
    required this.status,
    required this.nextKm,
    required this.nextDate,
  });

  final MaintenanceRule rule;
  final ServiceRecord? lastRecord;
  final int baseKm;
  final DateTime baseDate;
  final int usedKm;
  final double kmPercent;
  final double timePercent;
  final MaintenanceStatus status;
  final int nextKm;
  final DateTime nextDate;

  int kmLeft(int odometer) => nextKm - odometer;

  /// Counts from the last service of the component ([baseKm]/[baseDate]), or from the first
  /// odometer reading when it was never serviced. Status uses km or months, whichever is further.
  static ComponentStatus calculate({
    required MaintenanceRule rule,
    required int currentKm,
    required int baseKm,
    required DateTime baseDate,
    ServiceRecord? lastRecord,
    required DateTime today,
  }) {
    final used = currentKm - baseKm < 0 ? 0 : currentKm - baseKm;
    final kmPct = used / rule.intervalKm * 100;
    final months = monthsBetween(dateOnly(baseDate), dateOnly(today));
    final timePct = months < 0 ? 0.0 : months / rule.intervalMonths * 100;
    return ComponentStatus(
      rule: rule,
      lastRecord: lastRecord,
      baseKm: baseKm,
      baseDate: dateOnly(baseDate),
      usedKm: used,
      kmPercent: kmPct,
      timePercent: timePct,
      status: MaintenanceStatus.fromPercent(kmPct > timePct ? kmPct : timePct),
      nextKm: baseKm + rule.intervalKm,
      nextDate: addMonths(dateOnly(baseDate), rule.intervalMonths),
    );
  }
}

/// reminders: one per motorcycle, rule and status in the current service cycle.
class Reminder {
  const Reminder({
    this.reminderId = '',
    required this.motorcycleId,
    required this.ruleId,
    required this.message,
    required this.dueStatus,
    required this.dueDate,
    required this.createdAt,
    this.readAt,
  });

  final String reminderId;
  final String motorcycleId;
  final String ruleId;
  final String message;

  /// Only dueSoon or overdue are stored.
  final MaintenanceStatus dueStatus;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// Reminder for a due-soon or overdue component; null when it is on track.
  static Reminder? fromStatus(Motorcycle m, ComponentStatus s, {required DateTime now}) {
    if (s.status == MaintenanceStatus.onTrack) return null;
    final name = s.rule.componentName;
    final left = s.kmLeft(m.currentOdometer);
    final message = s.status == MaintenanceStatus.overdue
        ? (left < 0
            ? '$name is overdue by ${fmtKm(-left)}. It was due at ${fmtKm(s.nextKm)}.'
            : '$name passed its ${fmtMonths(s.rule.intervalMonths)} interval on ${fmtDate(s.nextDate)}.')
        : '$name is due soon: ${fmtKm(left < 0 ? 0 : left)} left or by ${fmtDate(s.nextDate)}.';
    return Reminder(
      motorcycleId: m.motorcycleId,
      ruleId: s.rule.ruleId,
      message: message,
      dueStatus: s.status,
      dueDate: s.nextDate,
      createdAt: now,
    );
  }

  /// The unique key of the reminders table: motorcycle, rule and status.
  bool sameKey(Reminder other) =>
      motorcycleId == other.motorcycleId && ruleId == other.ruleId && dueStatus == other.dueStatus;

  Reminder copyWith({String? reminderId, DateTime? readAt}) => Reminder(
        reminderId: reminderId ?? this.reminderId,
        motorcycleId: motorcycleId,
        ruleId: ruleId,
        message: message,
        dueStatus: dueStatus,
        dueDate: dueDate,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
      );
}

// ====================================================================== mechanic
/// service_jobs: a motorcycle in the mechanic's queue ("Today's Jobs").
class ServiceJob {
  ServiceJob({
    required this.jobId,
    required this.motorcycleId,
    required this.mechanicId,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String jobId;
  final String motorcycleId;
  final String mechanicId;
  final String note;
  JobStatus status;
  final DateTime createdAt;
}

/// reviews: an owner's rating of a mechanic who serviced one of their motorcycles.
class Review {
  const Review({
    this.reviewId = '',
    required this.mechanicId,
    required this.ownerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.ownerName = '',
  });

  final String reviewId;
  final String mechanicId;
  final String ownerId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  /// Derived: user_accounts.full_name of [ownerId].
  final String ownerName;
}

// ====================================================================== admin
/// activity_logs: "Recent changes" on the Admin dashboard.
class ActivityLog {
  const ActivityLog({
    this.logId = '',
    this.actorId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.createdAt,
  });

  final String logId;
  final String? actorId;
  final String title;
  final String subtitle;
  final String icon;
  final DateTime createdAt;
}

/// Summary of accounts, catalog and rules for the admin report (not stored).
class SystemReport {
  const SystemReport({
    required this.generatedAt,
    required this.usersByRole,
    required this.modelsByType,
    required this.rulesByModel,
  });

  final DateTime generatedAt;

  /// role → (active accounts, inactive accounts)
  final Map<UserRole, (int, int)> usersByRole;
  final Map<MotorcycleType, int> modelsByType;

  /// Every catalog model with its number of maintenance rules, by name.
  final List<(MotorcycleCatalog, int)> rulesByModel;

  List<MotorcycleCatalog> get modelsWithoutRules => [for (final (m, n) in rulesByModel) if (n == 0) m];

  int get totalUsers => usersByRole.values.fold(0, (a, v) => a + v.$1 + v.$2);

  static SystemReport build({
    required List<UserAccount> users,
    required List<MotorcycleCatalog> catalog,
    required List<MaintenanceRule> rules,
    required DateTime now,
  }) =>
      SystemReport(
        generatedAt: now,
        usersByRole: {
          for (final r in UserRole.values)
            r: (
              users.where((u) => u.role == r && u.active).length,
              users.where((u) => u.role == r && !u.active).length,
            ),
        },
        modelsByType: {
          for (final t in MotorcycleType.values) t: catalog.where((c) => c.motorcycleType == t).length,
        },
        rulesByModel: [
          for (final c in [...catalog]..sort((a, b) => a.name.compareTo(b.name)))
            (c, rules.where((r) => r.catalogId == c.catalogId).length),
        ],
      );

  /// The report as CSV (section,item,value,…) for sharing or opening in a spreadsheet.
  String toCsv() {
    String cell(Object v) {
      final s = '$v';
      return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final rows = <List<Object>>[
      ['MotorcycleCare system report', fmtDate(generatedAt), fmtTime(generatedAt), ''],
      ['section', 'item', 'active', 'inactive'],
      for (final r in UserRole.values) ['users per role', r.label, usersByRole[r]!.$1, usersByRole[r]!.$2],
      ['section', 'item', 'count', ''],
      for (final t in MotorcycleType.values) ['models per type', t.label, modelsByType[t]!, ''],
      for (final (m, n) in rulesByModel) ['rules per model', '${m.name} ${m.modelYear}', n, ''],
      for (final m in modelsWithoutRules) ['models without rules', '${m.name} ${m.modelYear}', 0, ''],
    ];
    return '${rows.map((r) => r.map(cell).join(',')).join('\n')}\n';
  }
}

// ====================================================================== form state (not stored)
/// Form data of a service recorded by a mechanic.
class ServiceDraft {
  ServiceDraft({
    required this.motorcycle,
    required this.components,
    required this.serviceDate,
    required this.odometerKm,
  });

  final Motorcycle motorcycle;

  /// Component keys.
  Set<String> components;
  DateTime serviceDate;
  int odometerKm;
  String description = '';
  ServiceReceipt? receipt;
  bool notifyOwner = true;
}
