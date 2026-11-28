import 'package:flutter_test/flutter_test.dart';
import 'package:motorcyclecare/models/models.dart';

const rule = MaintenanceRule(
  ruleId: '1',
  catalogId: 'c',
  componentKey: 'engine',
  componentName: 'Engine Oil',
  intervalKm: 2000,
  intervalMonths: 3,
  sourceReference: "Owner's manual",
);

ComponentStatus calc(int currentKm, DateTime today) => ComponentStatus.calculate(
    rule: rule, currentKm: currentKm, baseKm: 1000, baseDate: DateTime(2026, 1, 1), today: today);

Motorcycle moto({int km = 8450}) => Motorcycle(
      motorcycleId: 'm',
      ownerId: 'o',
      catalogId: 'c',
      plateNumber: 'B 1 A',
      currentOdometer: km,
      odometerUpdatedAt: DateTime(2026, 11, 21),
      createdAt: DateTime(2026, 2, 2),
    );

void main() {
  group('status calculation', () {
    final feb = DateTime(2026, 2, 1); // 1 month after the base date = 33 % of the time

    test('dueSoon from 80 %, overdue from 100 % of the km interval', () {
      expect(calc(2599, feb).status, MaintenanceStatus.onTrack); // 79.95 %
      expect(calc(2600, feb).status, MaintenanceStatus.dueSoon); // 80 %
      expect(calc(2999, feb).status, MaintenanceStatus.dueSoon);
      expect(calc(3000, feb).status, MaintenanceStatus.overdue); // 100 %
      expect(calc(3000, feb).kmPercent, 100);
    });

    test('the time limit counts too, whichever comes first', () {
      expect(calc(1100, DateTime(2026, 3, 1)).status, MaintenanceStatus.onTrack); // 2 months = 63 %
      expect(calc(1100, DateTime(2026, 3, 15)).status, MaintenanceStatus.onTrack); // 73 days = 79.9 %
      expect(calc(1100, DateTime(2026, 3, 16)).status, MaintenanceStatus.dueSoon); // 74 days = 81 %
      expect(calc(1100, DateTime(2026, 4, 3)).status, MaintenanceStatus.overdue); // > 3 months
      expect(calc(1100, DateTime(2026, 4, 3)).kmPercent, closeTo(5, 0.01));
    });

    test('next service is base + interval (km and months)', () {
      final s = calc(2500, feb);
      expect(s.usedKm, 1500);
      expect(s.nextKm, 3000);
      expect(s.nextDate, DateTime(2026, 4, 1));
      expect(s.kmLeft(2500), 500);
      expect(calc(900, feb).usedKm, 0); // never negative
    });

    test('MaintenanceStatus.fromPercent', () {
      expect(MaintenanceStatus.fromPercent(79.9), MaintenanceStatus.onTrack);
      expect(MaintenanceStatus.fromPercent(80), MaintenanceStatus.dueSoon);
      expect(MaintenanceStatus.fromPercent(99.9), MaintenanceStatus.dueSoon);
      expect(MaintenanceStatus.fromPercent(100), MaintenanceStatus.overdue);
    });
  });

  group('odometer validation', () {
    test('rejects empty, lower and too-big readings', () {
      final m = moto();
      expect(OdometerReading.validate(m, null), isNotNull);
      expect(OdometerReading.validate(m, 8449), contains("can't be lower"));
      expect(OdometerReading.validate(m, 8450), isNull); // same value = confirm
      expect(OdometerReading.validate(m, 8450 + OdometerReading.maxJumpKm), isNull);
      expect(OdometerReading.validate(m, 8451 + OdometerReading.maxJumpKm), contains('too big'));
    });

    test('a reading only moves the odometer forward', () {
      final m = moto();
      m.applyReading(OdometerReading(readingId: '1', motorcycleId: 'm', valueKm: 8000, recordedAt: DateTime(2026, 11, 25)));
      expect(m.currentOdometer, 8450);
      m.applyReading(OdometerReading(readingId: '2', motorcycleId: 'm', valueKm: 8600, recordedAt: DateTime(2026, 11, 26)));
      expect(m.currentOdometer, 8600);
      expect(m.odometerUpdatedAt, DateTime(2026, 11, 26));
    });
  });

  group('receipt validation (ServiceReceipt.validateFile)', () {
    test('accepts JPG, PNG, WEBP and HEIC up to 5 MB', () {
      for (final name in ['nota.jpg', 'nota.JPEG', 'nota.png', 'nota.webp', 'IMG_1.heic']) {
        expect(ServiceReceipt.validateFile(fileName: name, sizeBytes: 1000), isNull, reason: name);
      }
      expect(ServiceReceipt.validateFile(fileName: 'a.jpg', sizeBytes: ServiceReceipt.maxBytes), isNull);
    });

    test('rejects other types, empty and large files', () {
      expect(ServiceReceipt.validateFile(fileName: 'nota.pdf', sizeBytes: 1000), contains('JPG, PNG, WEBP or HEIC'));
      expect(ServiceReceipt.validateFile(fileName: 'nota', sizeBytes: 1000), isNotNull);
      expect(ServiceReceipt.validateFile(fileName: 'a.jpg', sizeBytes: 0), isNotNull);
      expect(ServiceReceipt.validateFile(fileName: 'a.jpg', sizeBytes: ServiceReceipt.maxBytes + 1), contains('5 MB'));
    });

    test('mime type and extension for the upload', () {
      expect(const ServiceReceipt(fileName: 'x.JPEG').extension, 'jpg');
      expect(const ServiceReceipt(fileName: 'x.png').mimeType, 'image/png');
      expect(const ServiceReceipt(fileName: 'x.heic').mimeType, 'image/heic');
      expect(const ServiceReceipt(fileName: 'x.jpg').isSample, isTrue);
      expect(const ServiceReceipt(fileName: 'x.jpg', localPath: '/x.jpg').isSample, isFalse);
    });
  });

  group('reminder from status', () {
    test('only dueSoon and overdue components get a reminder', () {
      final m = moto(km: 2700);
      final now = DateTime(2026, 2, 1);
      expect(Reminder.fromStatus(m, calc(2000, now), now: now), isNull);
      final soon = Reminder.fromStatus(m, calc(2700, now), now: now)!;
      expect(soon.dueStatus, MaintenanceStatus.dueSoon);
      expect(soon.ruleId, '1');
      expect(soon.dueDate, DateTime(2026, 4, 1));
      expect(soon.message, contains('Engine Oil is due soon'));
      final late = Reminder.fromStatus(moto(km: 3200), calc(3200, now), now: now)!;
      expect(late.dueStatus, MaintenanceStatus.overdue);
      expect(late.message, contains('overdue by 200 km'));
      expect(soon.sameKey(late), isFalse); // a new status is a new reminder
      expect(soon.sameKey(soon.copyWith(reminderId: '9')), isTrue);
    });
  });

  test('UserAccount subclasses follow the role', () {
    final owner = UserAccount.create(role: UserRole.owner, userId: '1', email: 'a@b.c', fullName: 'Ana Putri');
    expect(owner, isA<MotorcycleOwner>());
    expect(owner.roleId, 1);
    expect((owner as MotorcycleOwner).notificationEnabled, isTrue);
    final mech = owner.copyWith(role: UserRole.mechanic, workshop: const Workshop(workshopId: 'w', name: 'Maju Jaya'));
    expect(mech, isA<Mechanic>());
    expect((mech as Mechanic).workshopName, 'Maju Jaya');
    expect(mech.roleId, 2);
    final admin = mech.copyWith(role: UserRole.admin, staffCode: 'ADM-2026');
    expect((admin as Admin).staffCode, 'ADM-2026');
    expect(Role.of(UserRole.admin).roleId, 3);
    expect(const Workshop(workshopId: 'w', name: 'x', hours: 'Mon–Sat · 08:00–17:00').closesAt, '17:00');
  });

  test('system report counts and CSV', () {
    final users = [
      UserAccount.create(role: UserRole.owner, userId: '1', email: 'a', fullName: 'A'),
      UserAccount.create(role: UserRole.owner, userId: '2', email: 'b', fullName: 'B', active: false),
      UserAccount.create(role: UserRole.admin, userId: '3', email: 'c', fullName: 'C'),
    ];
    const catalog = [
      MotorcycleCatalog(catalogId: 'c', make: 'Honda', model: 'Vario 160', motorcycleType: MotorcycleType.matic, modelYear: 2023),
      MotorcycleCatalog(catalogId: 'd', make: 'Yamaha', model: 'R15, Special', motorcycleType: MotorcycleType.sport, modelYear: 2023),
    ];
    final r = SystemReport.build(users: users, catalog: catalog, rules: const [rule], now: DateTime(2026, 11, 28, 9));
    expect(r.usersByRole[UserRole.owner], (1, 1));
    expect(r.usersByRole[UserRole.mechanic], (0, 0));
    expect(r.totalUsers, 3);
    expect(r.modelsByType[MotorcycleType.matic], 1);
    expect(r.modelsByType[MotorcycleType.trail], 0);
    expect(r.modelsWithoutRules.single.catalogId, 'd');
    final csv = r.toCsv();
    expect(csv, contains('users per role,Motorcycle Owner,1,1'));
    expect(csv, contains('rules per model,Honda Vario 160 2023,1,'));
    expect(csv, contains('"Yamaha R15, Special 2023"')); // commas are quoted
  });
}
