import 'package:flutter_test/flutter_test.dart';
import 'package:motorcyclecare/data/backend.dart';
import 'package:motorcyclecare/data/mock_backend.dart';
import 'package:motorcyclecare/models/models.dart';
import 'package:motorcyclecare/services/reminder_notifier.dart';
import 'package:motorcyclecare/state/app_state.dart';
import 'package:motorcyclecare/utils/format.dart';

/// Records the notifications instead of showing them.
class FakeNotifier implements ReminderNotifier {
  final shown = <Reminder>[];

  @override
  Future<void> show(Reminder reminder, {required String title}) async => shown.add(reminder);
}

Future<(AppState, FakeNotifier)> signIn(String email, String password) async {
  final n = FakeNotifier();
  final app = AppState.seeded(notifier: n);
  expect(await app.login(email, password), isNull);
  return (app, n);
}

void main() {
  group('odometer readings', () {
    test('update and confirm save a reading and move the current odometer', () async {
      final (app, _) = await signIn('rizky@mail.com', 'rizky123');
      final m = app.myMotorcycles.single;
      final before = app.readingsFor(m).length;
      expect(app.firstReadingOf(m).valueKm, 0);
      expect(app.firstReadingOf(m).recordedAt.month, 2); // registered 2 Feb 2026

      expect(await app.updateOdometer(m, 8000), contains("can't be lower")); // nothing saved
      expect(app.readingsFor(m).length, before);

      expect(await app.updateOdometer(m, 8600), isNull);
      expect(m.currentOdometer, 8600);
      expect(app.readingsFor(m).length, before + 1);
      expect(app.readingsFor(m).first.valueKm, 8600); // newest first
      expect(app.readingsFor(m).first.recordedBy, 'u1');

      expect(await app.confirmOdometer(m), isNull); // "Use latest odometer"
      expect(app.readingsFor(m).length, before + 2);
      expect(app.readingsFor(m).first.valueKm, 8600);
      expect(dateOnly(m.odometerUpdatedAt), today());
    });

    test('registering a motorcycle stores its first reading (status baseline)', () async {
      final (app, _) = await signIn('rizky@mail.com', 'rizky123');
      expect(await app.addMotorcycle(catalogId: 'pcx', plateNumber: 'B 1234 XY', odometerKm: 3100), isNull);
      final m = app.selected!;
      expect(app.readingsFor(m).single.valueKm, 3100);
      final engine = app.statusOf(m, app.ruleFor(m, 'engine'));
      expect(engine.baseKm, 3100);
      expect(engine.usedKm, 0);
      expect(engine.status, MaintenanceStatus.onTrack);
    });

    test('the backend refuses a lower reading too (trigger rule)', () async {
      final backend = MockBackend();
      expect(() => backend.addOdometerReading(motorcycleId: 'm1', valueKm: 10, recordedBy: 'u1'),
          throwsA(isA<BackendException>()));
    });
  });

  group('reminders', () {
    test('created after calculating the status, never twice, and shown as notifications', () async {
      final (app, n) = await signIn('rizky@mail.com', 'rizky123');
      final m = app.myMotorcycles.single;
      final alerts = app.alertsFor(m);
      expect(alerts.map((s) => s.rule.componentKey), contains('gear')); // overdue in the demo data
      // logging in ("open the app") created one reminder per due component and notified the owner
      expect(app.remindersFor(m).length, alerts.length);
      expect(n.shown.length, alerts.length);
      expect(app.unreadReminders(m), alerts.length);
      final gear = app.remindersFor(m).firstWhere((r) => r.ruleId == app.ruleFor(m, 'gear').ruleId);
      expect(gear.dueStatus, MaintenanceStatus.overdue);
      expect(gear.reminderId, isNotEmpty);

      expect(await app.syncReminders(m), isEmpty); // same motorcycle, rule and status: skipped
      expect(app.remindersFor(m).length, alerts.length);
      expect(n.shown.length, alerts.length);

      await app.markReminderRead(gear);
      expect(app.unreadReminders(m), alerts.length - 1);
      expect(app.remindersFor(m).firstWhere((r) => r.reminderId == gear.reminderId).isRead, isTrue);
    });

    test('servicing a component closes its reminder; notificationEnabled = false stores but does not notify',
        () async {
      final (app, n) = await signIn('rizky@mail.com', 'rizky123');
      final m = app.myMotorcycles.single;
      final gearRule = app.ruleFor(m, 'gear');
      final engineRule = app.ruleFor(m, 'engine');
      final shownAtLogin = n.shown.length;

      expect(await app.updateMyProfile(fullName: 'Rizky Yudha', notificationEnabled: false), isNull);
      expect((app.currentUser! as MotorcycleOwner).notificationEnabled, isFalse);

      final (record, err) = await app.saveRecord(
          motorcycle: m, serviceDate: today(), odometerKm: 8450, items: {'gear': 'Replaced gear oil'});
      expect(err, isNull);
      expect(record!.mechanicId, isNull); // logged by the owner
      expect(app.remindersFor(m).where((r) => r.ruleId == gearRule.ruleId), isEmpty);

      // engine oil was due soon at 8,450 km; at 8,800 km it is overdue → a new reminder, but no notification
      expect(await app.updateOdometer(m, 8800), isNull);
      final engine = app.remindersFor(m).where((r) => r.ruleId == engineRule.ruleId).toList();
      expect(engine.map((r) => r.dueStatus), containsAll([MaintenanceStatus.dueSoon, MaintenanceStatus.overdue]));
      expect(n.shown.length, shownAtLogin);

      // switched on again: the next new reminder is shown
      await app.updateMyProfile(fullName: 'Rizky Yudha', notificationEnabled: true);
      expect(await app.updateOdometer(m, 12500), isNull); // gear oil due again (dueSoon/overdue)
      expect(n.shown.length, greaterThan(shownAtLogin));
    });

    test('a mechanic saving a service updates the owner\'s reminders but sends no notification on the mechanic\'s phone',
        () async {
      final (app, n) = await signIn('budi@mail.com', 'budi123');
      final m = app.findByPlate('B 4521 KXR')!;
      final d = ServiceDraft(motorcycle: m, components: {'engine'}, serviceDate: today(), odometerKm: 8500)
        ..description = 'Changed engine oil';
      expect((await app.saveService(d)).$2, isNull); // "Notify owner" is on by default
      expect(n.shown, isEmpty);
      final stored = await app.backend.loadReminders([m.motorcycleId]);
      expect(stored.map((r) => r.ruleId), contains(app.ruleFor(m, 'gear').ruleId)); // still overdue
      expect(stored.map((r) => r.ruleId), isNot(contains(app.ruleFor(m, 'engine').ruleId))); // just serviced
      // the owner opens the app on the same data: the reminders are there, unread
      final owner = AppState(app.backend, notifier: FakeNotifier());
      expect(await owner.login('rizky@mail.com', 'rizky123'), isNull);
      expect(owner.unreadReminders(owner.myMotorcycles.single), stored.length);
    });
  });

  group('service receipts', () {
    test('invalid files are rejected before anything is saved', () async {
      final (app, _) = await signIn('rizky@mail.com', 'rizky123');
      final m = app.myMotorcycles.single;
      final count = app.recordsFor(m).length;
      final (record, err) = await app.saveRecord(
        motorcycle: m,
        serviceDate: today(),
        odometerKm: 8450,
        items: {'air': 'Air filter'},
        receipt: const ServiceReceipt(fileName: 'nota.gif', localPath: '/tmp/nota.gif', sizeBytes: 2000),
      );
      expect(record, isNull);
      expect(err, contains('JPG, PNG, WEBP or HEIC'));
      expect(app.recordsFor(m).length, count);
    });

    test('a receipt is saved as its own entity with uploaded_at', () async {
      final (app, _) = await signIn('budi@mail.com', 'budi123');
      final m = app.findByPlate('B 3308 TZA')!;
      final d = ServiceDraft(motorcycle: m, components: {'air'}, serviceDate: today(), odometerKm: 11300)
        ..description = 'Replaced air filter'
        ..receipt = const ServiceReceipt(fileName: 'nota.jpg', localPath: '/tmp/nota.jpg', sizeBytes: 300000);
      final (record, err) = await app.saveService(d);
      expect(err, isNull);
      expect(record!.receipt!.recordId, record.recordId);
      expect(record.receipt!.receiptId, isNotEmpty);
      expect(record.receipt!.uploadedAt, isNotNull);
      expect(record.items.single.ruleId, app.ruleFor(m, 'air').ruleId);
      expect(record.mechanicId, 'u2');
      expect(record.workshopName, 'Maju Jaya Motor');
    });
  });

  group('registration with role and staff code', () {
    test('admin needs a matching staff code', () async {
      final app = AppState.seeded();
      final (err, _) = await app.register(
          fullName: 'Rina Admin', email: 'rina@mail.com', password: 'rina12345', role: UserRole.admin, staffCode: 'WRONG');
      expect(err, contains('Staff code is not valid'));
      expect(await app.login('rina@mail.com', 'rina12345'), isNotNull); // no account was created

      final (ok, _) = await app.register(
          fullName: 'Rina Admin', email: 'rina@mail.com', password: 'rina12345', role: UserRole.admin, staffCode: 'adm-2026');
      expect(ok, isNull);
      expect(await app.login('rina@mail.com', 'rina12345'), isNull);
      final me = app.currentUser!;
      expect(me, isA<Admin>());
      expect((me as Admin).staffCode, 'ADM-2026');
      expect(app.activity.first.title, 'New admin registered');
    });

    test('mechanic needs a workshop; owner is the default role', () async {
      final app = AppState.seeded();
      final (noWorkshop, _) = await app.register(
          fullName: 'Joko Mekanik', email: 'joko@mail.com', password: 'joko12345', role: UserRole.mechanic);
      expect(noWorkshop, isNotNull);
      final (ok, _) = await app.register(
          fullName: 'Joko Mekanik',
          email: 'joko@mail.com',
          password: 'joko12345',
          role: UserRole.mechanic,
          workshopName: 'AHASS Sudirman');
      expect(ok, isNull);
      expect(await app.login('joko@mail.com', 'joko12345'), isNull);
      expect((app.currentUser! as Mechanic).workshop!.workshopId, 'w2'); // existing workshop reused

      final (owner, _) = await app.register(fullName: 'Ana Putri', email: 'ana@mail.com', password: 'ana123456');
      expect(owner, isNull);
      expect(await app.login('ana@mail.com', 'ana123456'), isNull);
      expect(app.currentUser, isA<MotorcycleOwner>());
      expect((app.currentUser! as MotorcycleOwner).notificationEnabled, isTrue);
    });
  });

  group('admin', () {
    test('system report and recent changes', () async {
      final (app, _) = await signIn('dina@mail.com', 'dina123');
      expect(app.activity, isNotEmpty); // activity_logs
      final (model, _) = await app.saveModel(const MotorcycleCatalog(
          catalogId: '', make: 'Yamaha', model: 'Aerox 155', motorcycleType: MotorcycleType.matic, modelYear: 2024));
      expect(app.activity.first.title, 'Model added');
      final (report, err) = await app.loadSystemReport();
      expect(err, isNull);
      expect(report!.usersByRole[UserRole.owner], (6, 1));
      expect(report.usersByRole[UserRole.mechanic], (3, 0));
      expect(report.usersByRole[UserRole.admin], (2, 0));
      expect(report.modelsByType[MotorcycleType.matic], 6);
      expect(report.modelsWithoutRules.map((m) => m.catalogId), [model!.catalogId]);
      expect(report.toCsv(), contains('models without rules,Yamaha Aerox 155 2024,0,'));
    });

    test('guards: owner with motorcycles keeps the role, rules used in history stay', () async {
      final (app, _) = await signIn('dina@mail.com', 'dina123');
      final rizky = app.users.firstWhere((u) => u.email == 'rizky@mail.com');
      expect(
          await app.saveUser(
              rizky.copyWith(role: UserRole.mechanic, workshop: const Workshop(workshopId: '', name: 'Baru'))),
          contains('still has registered motorcycles'));
      final dimas = app.users.firstWhere((u) => u.email == 'dimas@mail.com');
      expect(await app.saveUser(dimas.copyWith(role: UserRole.owner)), isNull);
      expect(app.users.firstWhere((u) => u.userId == dimas.userId), isA<MotorcycleOwner>());
      final engine = app.allRules.firstWhere((r) => r.catalogId == 'vario' && r.componentKey == 'engine');
      expect(await app.deleteRule(engine), contains('service records use this rule'));
      expect(await app.saveUser(app.currentUser!.copyWith(role: UserRole.owner)), isNotNull); // not yourself
    });
  });

  test('owners rate the mechanic who serviced their motorcycle', () async {
    final (app, _) = await signIn('rizky@mail.com', 'rizky123');
    final m = app.myMotorcycles.single;
    final byEko = app.recordsFor(m).firstWhere((r) => r.mechanicId == 'u12');
    final self = app.recordsFor(m).firstWhere((r) => r.mechanicId == null);
    expect(app.canRate(byEko), isTrue);
    expect(app.canRate(self), isFalse);
    expect(await app.rateMechanic(record: self, rating: 5, comment: ''), isNotNull);
    expect(await app.rateMechanic(record: byEko, rating: 4, comment: 'Quick and tidy'), isNull);
    expect(app.myReviewOf('u12')!.rating, 4);

    final mech = AppState(app.backend); // Eko logs in on the same data
    expect(await mech.login('eko@mail.com', 'eko123'), isNull);
    expect(mech.reviews.single.rating, 4);
    expect(mech.reviews.single.ownerName, 'Rizky Yudha');
  });

  test('history shows who recorded a service', () async {
    final (app, _) = await signIn('rizky@mail.com', 'rizky123');
    final records = app.recordsFor(app.myMotorcycles.single);
    final byEko = records.firstWhere((r) => r.mechanicId == 'u12');
    expect(byEko.recordedByUserId, 'u12');
    expect(byEko.recordedByName, 'Eko Saputra');
    expect(byEko.workshopName, 'AHASS Sudirman');
  });
}
