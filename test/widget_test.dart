import 'package:flutter_test/flutter_test.dart';
import 'package:motorcyclecare/models/models.dart';
import 'package:motorcyclecare/state/app_state.dart';
import 'package:motorcyclecare/utils/format.dart';

void main() {
  test('number formatting', () {
    expect(fmtNum(8450), '8,450');
    expect(fmtKm(24000), '24,000 km');
    expect(fmtDate(DateTime(2026, 12, 28)), '28 Dec 2026');
  });

  test('demo data and status calculation', () async {
    final app = AppState.seeded();
    expect(await app.login('rizky@mail.com', 'wrong'), isNotNull);
    expect(await app.login('rizky@mail.com', 'rizky123'), isNull);

    final moto = app.myMotorcycles.single;
    app.selectMotorcycle(moto.motorcycleId);
    expect(moto.currentOdometer, 8450);

    final gear = app.statusOf(moto, app.ruleFor(moto, 'gear'));
    expect(gear.usedKm, 4250);
    expect(gear.nextKm, 8200);
    expect(gear.status, MaintenanceStatus.overdue);

    final engine = app.statusOf(moto, app.ruleFor(moto, 'engine'));
    expect(engine.usedKm, 1750);
    expect(engine.nextKm, 8700);
    expect(engine.nextDate, DateTime(2026, 12, 28));

    final cvt = app.statusOf(moto, app.ruleFor(moto, 'cvt'));
    expect(cvt.nextDate, DateTime(2028, 2, 2)); // from the first odometer reading (registration)

    expect(app.validateOdometer(moto, 8100), isNotNull);
    expect(app.validateOdometer(moto, 8600), isNull);
  });

  test('rejects duplicate plates and bad plate formats', () async {
    final app = AppState.seeded();
    await app.login('rizky@mail.com', 'rizky123');
    expect(AppState.validatePlate('B 45 21'), isNotNull);
    expect(AppState.validatePlate('b4521kxr'), isNull);
    expect(await app.addMotorcycle(catalogId: 'pcx', plateNumber: 'b4521kxr', odometerKm: 0), isNotNull);
    expect(await app.addMotorcycle(catalogId: 'pcx', plateNumber: 'B 1234 XY', odometerKm: 0), isNull);
  });

  test('mechanic finds motorcycles by plate and saves a service', () async {
    final app = AppState.seeded();
    expect(await app.login('budi@mail.com', 'budi123'), isNull);
    expect(app.currentUser!.role, UserRole.mechanic);
    expect(app.findByPlate('b 9999 zzz'), isNull);
    final m = app.findByPlate('b4521kxr')!;
    expect(app.ownerOf(m)!.fullName, 'Rizky Yudha');
    final d = ServiceDraft(motorcycle: m, components: {'engine'}, serviceDate: today(), odometerKm: 8500)
      ..description = 'Changed engine oil';
    final (record, err) = await app.saveService(d);
    expect(err, isNull);
    expect(record!.recordedByName, 'Budi Santoso');
    expect(record.mechanicId, 'u2');
    expect(record.recordedByUserId, 'u2');
    expect(m.currentOdometer, 8500);
    expect(app.openJobFor(m), isNull);
  });

  test('admin manages users, catalog and rules', () async {
    final app = AppState.seeded();
    expect(await app.login('dina@mail.com', 'dina123'), isNull);
    expect(app.currentUser!.role, UserRole.admin);
    expect(await app.login('wahyu@mail.com', 'wahyu123'), isNotNull); // inactive account
    await app.login('dina@mail.com', 'dina123');
    final (model, err) = await app.saveModel(const MotorcycleCatalog(
        catalogId: '', make: 'Yamaha', model: 'Aerox 155', motorcycleType: MotorcycleType.matic, modelYear: 2024));
    expect(err, isNull);
    expect(
        await app.saveRule(MaintenanceRule(
            ruleId: '',
            catalogId: model!.catalogId,
            componentKey: 'engine',
            componentName: 'Engine Oil',
            intervalKm: 2000,
            intervalMonths: 2,
            sourceReference: 'Manual')),
        isNull);
    expect(app.rulesForCatalog(model.catalogId).length, 1);
    expect(await app.deleteModel(app.catalog.firstWhere((c) => c.catalogId == 'vario')), isNotNull); // still in use
  });
}
