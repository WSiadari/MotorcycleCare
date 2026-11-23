import 'package:flutter_test/flutter_test.dart';
import 'package:motorcyclecare/models/models.dart';
import 'package:motorcyclecare/state/app_state.dart';
import 'package:motorcyclecare/utils/format.dart';

void main() {
  test('formats numbers like the design', () {
    expect(fmtNum(8450), '8,450');
    expect(fmtKm(24000), '24,000 km');
    expect(fmtDate(DateTime(2026, 12, 28)), '28 Dec 2026');
  });

  test('demo data matches the Figma prototype', () async {
    final app = AppState.seeded();
    expect(await app.login('rizky@mail.com', 'wrong'), isNotNull);
    expect(await app.login('rizky@mail.com', 'rizky123'), isNull);

    final moto = app.myMotorcycles.single;
    app.selectMotorcycle(moto.id);
    expect(moto.odometer, 8450);

    final gear = app.statusOf(moto, app.ruleFor(moto, 'gear'));
    expect(gear.usedKm, 4250);
    expect(gear.nextKm, 8200);
    expect(gear.health, Health.overdue);

    final engine = app.statusOf(moto, app.ruleFor(moto, 'engine'));
    expect(engine.usedKm, 1750);
    expect(engine.nextKm, 8700);
    expect(engine.nextDate, DateTime(2026, 12, 28));

    final cvt = app.statusOf(moto, app.ruleFor(moto, 'cvt'));
    expect(cvt.nextDate, DateTime(2028, 2, 2));

    expect(app.validateOdometer(moto, 8100), isNotNull);
    expect(app.validateOdometer(moto, 8600), isNull);
  });

  test('rejects duplicate plates and bad plate formats', () async {
    final app = AppState.seeded();
    await app.login('rizky@mail.com', 'rizky123');
    expect(AppState.validatePlate('B 45 21'), isNotNull);
    expect(await app.addMotorcycle(catalogId: 'pcx', plate: 'b4521kxr', odometer: 0), isNotNull);
    expect(await app.addMotorcycle(catalogId: 'pcx', plate: 'B 1234 XY', odometer: 0), isNull);
  });

  test('mechanic finds motorcycles by plate and saves a service', () async {
    final app = AppState.seeded();
    expect(await app.login('budi@mail.com', 'budi123'), isNull);
    expect(app.currentUser!.role, UserRole.mechanic);
    expect(app.findByPlate('b 9999 zzz'), isNull);
    final m = app.findByPlate('b4521kxr')!;
    expect(app.ownerOf(m)!.fullName, 'Rizky Yudha');
    final d = ServiceDraft(motorcycle: m, components: {'engine'}, date: today(), odometer: 8500)
      ..description = 'Changed engine oil';
    final (record, err) = await app.saveService(d);
    expect(err, isNull);
    expect(record!.recordedByName, 'Budi Santoso');
    expect(m.odometer, 8500);
    expect(app.openJobFor(m), isNull);
  });

  test('admin manages users, catalog and rules', () async {
    final app = AppState.seeded();
    expect(await app.login('dina@mail.com', 'dina123'), isNull);
    expect(app.currentUser!.role, UserRole.admin);
    expect(await app.login('wahyu@mail.com', 'wahyu123'), isNotNull); // inactive account
    await app.login('dina@mail.com', 'dina123');
    final (model, err) = await app.saveModel(
        const CatalogModel(id: '', make: 'Yamaha', model: 'Aerox 155', type: MotoType.matic, year: 2024));
    expect(err, isNull);
    expect(await app.saveRule(MaintenanceRule(
        id: '', catalogId: model!.id, componentKey: 'engine', componentName: 'Engine Oil',
        intervalKm: 2000, intervalMonths: 2, source: 'Manual')), isNull);
    expect(app.rulesForCatalog(model.id).length, 1);
    expect(await app.deleteModel(app.catalog.firstWhere((c) => c.id == 'vario')), isNotNull); // still in use
  });
}
