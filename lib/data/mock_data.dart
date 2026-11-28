import '../models/models.dart';

/// Demo data. The main motorcycle is a Honda Vario 160 (B 4521 KXR), registered on 2 Feb 2026 at
/// 0 km and at 8,450 km on 21 Nov 2026. Catalog, rules, workshops and staff code match supabase/seed.sql.
class MockData {
  MockData._();

  static const catalog = <MotorcycleCatalog>[
    MotorcycleCatalog(catalogId: 'vario', make: 'Honda', model: 'Vario 160', motorcycleType: MotorcycleType.matic, modelYear: 2023),
    MotorcycleCatalog(catalogId: 'pcx', make: 'Honda', model: 'PCX 160', motorcycleType: MotorcycleType.matic, modelYear: 2024),
    MotorcycleCatalog(catalogId: 'nmax', make: 'Yamaha', model: 'NMAX 155', motorcycleType: MotorcycleType.matic, modelYear: 2023),
    MotorcycleCatalog(catalogId: 'beat', make: 'Honda', model: 'BeAT', motorcycleType: MotorcycleType.matic, modelYear: 2023),
    MotorcycleCatalog(catalogId: 'address', make: 'Suzuki', model: 'Address', motorcycleType: MotorcycleType.matic, modelYear: 2022),
    MotorcycleCatalog(catalogId: 'supra', make: 'Honda', model: 'Supra X 125', motorcycleType: MotorcycleType.underbone, modelYear: 2022),
    MotorcycleCatalog(catalogId: 'r15', make: 'Yamaha', model: 'R15', motorcycleType: MotorcycleType.sport, modelYear: 2023),
  ];

  // key, name, km, months, typical price (only for the sample receipts)
  static const _templates = <MotorcycleType, List<(String, String, int, int, int)>>{
    MotorcycleType.matic: [
      ('gear', 'Gear Oil', 4000, 6, 25000),
      ('engine', 'Engine Oil', 2000, 3, 58000),
      ('air', 'Air Filter', 8000, 12, 72000),
      ('spark', 'Spark Plug', 8000, 12, 28000),
      ('brake', 'Brake Pads', 12000, 12, 65000),
      ('cvt', 'CVT Belt', 24000, 24, 180000),
    ],
    MotorcycleType.underbone: [
      ('engine', 'Engine Oil', 2000, 3, 50000),
      ('air', 'Air Filter', 8000, 12, 45000),
      ('spark', 'Spark Plug', 8000, 12, 25000),
      ('chain', 'Drive Chain', 4000, 6, 30000),
      ('brake', 'Brake Pads', 12000, 12, 55000),
    ],
    MotorcycleType.trail: [
      ('engine', 'Engine Oil', 1500, 2, 60000),
      ('air', 'Air Filter', 3000, 3, 50000),
      ('spark', 'Spark Plug', 6000, 12, 30000),
      ('chain', 'Drive Chain', 500, 1, 30000),
      ('brake', 'Brake Pads', 8000, 12, 70000),
    ],
    MotorcycleType.sport: [
      ('engine', 'Engine Oil', 3000, 4, 95000),
      ('air', 'Air Filter', 10000, 12, 85000),
      ('spark', 'Spark Plug', 10000, 12, 60000),
      ('chain', 'Drive Chain', 4000, 6, 35000),
      ('brake', 'Brake Pads', 10000, 12, 90000),
      ('coolant', 'Coolant', 20000, 24, 70000),
    ],
  };

  static List<MaintenanceRule> buildRules() {
    final rules = <MaintenanceRule>[];
    var id = 1001;
    for (final m in catalog) {
      for (final t in _templates[m.motorcycleType]!) {
        rules.add(MaintenanceRule(
          ruleId: '${id++}',
          catalogId: m.catalogId,
          componentKey: t.$1,
          componentName: t.$2,
          intervalKm: t.$3,
          intervalMonths: t.$4,
          sourceReference: "Owner's manual",
        ));
      }
    }
    return rules;
  }

  static final _rules = buildRules();

  static String ruleIdOf(String catalogId, String componentKey) =>
      _rules.firstWhere((r) => r.catalogId == catalogId && r.componentKey == componentKey).ruleId;

  /// Typical workshop price of a component, used to draw the sample receipts.
  static int samplePrice(MotorcycleType type, String componentKey) =>
      _templates[type]!.where((t) => t.$1 == componentKey).firstOrNull?.$5 ?? 0;

  static const workshops = [
    Workshop(
        workshopId: 'w1',
        name: 'Maju Jaya Motor',
        address: 'Jl. Raya Bekasi No. 45',
        city: 'Jakarta Timur',
        hours: 'Mon–Sat · 08:00–17:00',
        phone: '+62 21 4455 6677'),
    Workshop(
        workshopId: 'w2',
        name: 'AHASS Sudirman',
        address: 'Jl. Jend. Sudirman No. 12',
        city: 'Jakarta Pusat',
        hours: 'Mon–Sat · 08:00–16:00',
        phone: '+62 21 5700 1122'),
  ];

  /// Demo accounts for each role (passwords in [passwords]).
  static List<UserAccount> buildUsers() {
    final now = DateTime.now();
    UserAccount owner(String id, String name, String email, DateTime at, {bool active = true}) =>
        MotorcycleOwner(userId: id, fullName: name, email: email, createdAt: at, active: active);
    return [
      owner('u1', 'Rizky Yudha', 'rizky@mail.com', DateTime(2026, 2, 2)),
      Mechanic(
          userId: 'u2',
          fullName: 'Budi Santoso',
          email: 'budi@mail.com',
          phone: '+62 812-3456-7890',
          workshop: workshops[0],
          createdAt: DateTime(2025, 6, 1)),
      Admin(userId: 'u3', fullName: 'Dina Pratama', email: 'dina@mail.com', staffCode: 'ADM-2026', createdAt: DateTime(2025, 1, 10)),
      owner('u4', 'Andi Pratama', 'andi@mail.com', DateTime(2026, 3, 4)),
      owner('u5', 'Siti Rahma', 'siti.rahma@mail.com', DateTime(2026, 4, 12)),
      owner('u6', 'Maya Lestari', 'maya@mail.com', DateTime(2026, 5, 20)),
      owner('u7', 'Dodi Kurniawan', 'dodi@mail.com', DateTime(2026, 6, 2)),
      owner('u8', 'Hendra Gunawan', 'hendra@mail.com', DateTime(2026, 7, 9)),
      Mechanic(
          userId: 'u9',
          fullName: 'Dimas Prakoso',
          email: 'dimas@mail.com',
          workshop: workshops[1],
          createdAt: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2))),
      Admin(userId: 'u10', fullName: 'Muhammad Agung', email: 'agung@mail.com', createdAt: DateTime(2025, 3, 3)),
      owner('u11', 'Wahyu Siadari', 'wahyu@mail.com', DateTime(2026, 8, 30), active: false),
      Mechanic(
          userId: 'u12',
          fullName: 'Eko Saputra',
          email: 'eko@mail.com',
          workshop: workshops[1],
          createdAt: DateTime(2025, 12, 1)),
    ];
  }

  /// Password = first name + "123" (Supabase Auth keeps real passwords).
  static const passwords = {
    'rizky@mail.com': 'rizky123',
    'budi@mail.com': 'budi123',
    'dina@mail.com': 'dina123',
    'andi@mail.com': 'andi123',
    'siti.rahma@mail.com': 'siti123',
    'maya@mail.com': 'maya123',
    'dodi@mail.com': 'dodi123',
    'hendra@mail.com': 'hendra123',
    'dimas@mail.com': 'dimas123',
    'agung@mail.com': 'agung123',
    'wahyu@mail.com': 'wahyu123',
    'eko@mail.com': 'eko123',
  };

  /// Staff codes that let someone register an Admin account (same as seed.sql).
  static const staffCodes = {'ADM-2026'};

  static Motorcycle _m(String id, String owner, String cat, String plate, int odo, DateTime reg) => Motorcycle(
        motorcycleId: id,
        ownerId: owner,
        catalogId: cat,
        plateNumber: plate,
        currentOdometer: odo,
        odometerUpdatedAt: DateTime(2026, 11, 21, 7, 45),
        createdAt: reg,
      );

  static List<Motorcycle> buildMotorcycles() => [
        _m('m1', 'u1', 'vario', 'B 4521 KXR', 8450, DateTime(2026, 2, 2)),
        _m('m2', 'u5', 'nmax', 'B 3308 TZA', 11200, DateTime(2026, 1, 15)),
        _m('m3', 'u4', 'beat', 'D 6672 ABF', 6900, DateTime(2026, 3, 4)),
        _m('m4', 'u7', 'address', 'B 6120 UFD', 25200, DateTime(2025, 9, 1)),
        _m('m5', 'u6', 'pcx', 'B 2210 RDN', 7600, DateTime(2026, 5, 20)),
        _m('m6', 'u8', 'supra', 'B 5532 XYA', 15400, DateTime(2026, 2, 10)),
        _m('m7', 'u7', 'r15', 'B 3745 FRT', 9800, DateTime(2026, 6, 2)),
      ];

  /// First reading at registration (0 km), the latest one on 21 Nov 2026, and the history of B 4521 KXR.
  static List<OdometerReading> buildReadings() {
    var n = 1;
    OdometerReading r(String moto, int km, DateTime at, String by) =>
        OdometerReading(readingId: 'o${n++}', motorcycleId: moto, valueKm: km, recordedAt: at, recordedBy: by);
    final list = <OdometerReading>[
      r('m1', 0, DateTime(2026, 2, 2, 10), 'u1'),
      r('m1', 2700, DateTime(2026, 5, 20, 9, 10), 'u1'),
      r('m1', 4200, DateTime(2026, 6, 14, 8, 30), 'u1'),
      r('m1', 4700, DateTime(2026, 8, 5, 18), 'u1'),
      r('m1', 6700, DateTime(2026, 9, 28, 9), 'u1'),
      r('m1', 8450, DateTime(2026, 11, 21, 7, 45), 'u1'),
    ];
    for (final m in buildMotorcycles().skip(1)) {
      list.add(r(m.motorcycleId, 0, m.createdAt, m.ownerId));
      list.add(r(m.motorcycleId, m.currentOdometer, m.odometerUpdatedAt, m.ownerId));
    }
    return list;
  }

  static const _catalogOf = {
    'm1': 'vario',
    'm2': 'nmax',
    'm3': 'beat',
    'm4': 'address',
    'm5': 'pcx',
    'm6': 'supra',
    'm7': 'r15',
  };

  static List<ServiceRecordItem> _items(String recordId, String moto, Map<String, String> work) => [
        for (final (i, e) in work.entries.indexed)
          ServiceRecordItem(
            itemId: '$recordId-${i + 1}',
            recordId: recordId,
            ruleId: ruleIdOf(_catalogOf[moto]!, e.key),
            componentKey: e.key,
            workDescription: e.value,
          ),
      ];

  static ServiceReceipt _receipt(String recordId, String file, DateTime at) =>
      ServiceReceipt(receiptId: 'rc-$recordId', recordId: recordId, fileName: file, uploadedAt: at);

  static List<ServiceRecord> buildRecords() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    // Earlier services of the Vario by Eko Saputra (AHASS Sudirman).
    ServiceRecord eko(String id, DateTime date, int km, Map<String, String> work, String file) => ServiceRecord(
          recordId: id,
          motorcycleId: 'm1',
          mechanicId: 'u12',
          recordedByUserId: 'u12',
          recordedByName: 'Eko Saputra',
          serviceDate: date,
          odometerKm: km,
          workshopName: 'AHASS Sudirman',
          createdAt: date.add(const Duration(hours: 10)),
          items: _items(id, 'm1', work),
          receipt: _receipt(id, file, date.add(const Duration(hours: 10))),
        );

    // Services by Budi Santoso (mechanic demo account), relative to today.
    ServiceRecord budi(String id, String moto, int daysAgo, int km, Map<String, String> work, int hour, int min,
        {bool receipt = true}) {
      final at = day.subtract(Duration(days: daysAgo)).add(Duration(hours: hour, minutes: min));
      return ServiceRecord(
        recordId: id,
        motorcycleId: moto,
        mechanicId: 'u2',
        recordedByUserId: 'u2',
        recordedByName: 'Budi Santoso',
        serviceDate: day.subtract(Duration(days: daysAgo)),
        odometerKm: km,
        workshopName: 'Maju Jaya Motor',
        createdAt: at,
        items: _items(id, moto, work),
        receipt: receipt ? _receipt(id, 'receipt_$id.jpg', at) : null,
      );
    }

    return [
      eko('r1', DateTime(2026, 5, 20), 2700, {'engine': 'Replaced engine oil (0.8 L)'}, 'nota_ahass_200526.jpg'),
      eko(
          'r2',
          DateTime(2026, 6, 14),
          4200,
          {
            'gear': 'Replaced gear oil (120 ml)',
            'air': 'Replaced air filter element',
            'spark': 'Replaced spark plug (NGK)',
            'brake': 'Replaced front brake pads',
          },
          'nota_ahass_140626.jpg'),
      ServiceRecord(
        recordId: 'r3',
        motorcycleId: 'm1',
        recordedByUserId: 'u1',
        recordedByName: 'Rizky Yudha',
        serviceDate: DateTime(2026, 8, 5),
        odometerKm: 4700,
        createdAt: DateTime(2026, 8, 5, 18),
        items: _items('r3', 'm1', {'engine': 'Replaced engine oil (self-service)'}),
      ),
      eko('r4', DateTime(2026, 9, 28), 6700, {'engine': 'Replaced engine oil (0.8 L)'}, 'nota_ahass_280926.jpg'),
      budi('b1', 'm5', 0, 7600, {'engine': 'Engine oil change'}, 8, 20),
      budi('b2', 'm7', 0, 9800, {'brake': 'Brake pads replaced'}, 9, 45),
      budi('b3', 'm6', 0, 15400, {'air': 'Air filter replaced'}, 11, 10),
      budi('b4', 'm2', 2, 11100, {'engine': 'Engine oil change', 'gear': 'Gear oil change'}, 10, 5),
      budi('b5', 'm3', 3, 6800, {'spark': 'Replaced spark plug'}, 14, 30, receipt: false),
      budi('b6', 'm4', 5, 25000, {'engine': 'Engine oil change'}, 9, 0),
      budi('b7', 'm2', 12, 10400, {'brake': 'Front brake pads replaced'}, 13, 15),
      budi('b8', 'm6', 20, 14900, {'engine': 'Engine oil change', 'chain': 'Chain cleaned and lubricated'}, 15, 40),
      budi('b9', 'm7', 34, 9100, {'engine': 'Engine oil change'}, 10, 0),
      budi('b10', 'm3', 45, 5600, {'air': 'Air filter cleaned'}, 11, 20),
      budi('b11', 'm4', 62, 23500, {'spark': 'Replaced spark plug'}, 16, 0),
    ];
  }

  static List<ServiceJob> buildJobs() {
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 7, 30);
    ServiceJob j(String id, String moto, String note, JobStatus s) =>
        ServiceJob(jobId: id, motorcycleId: moto, mechanicId: 'u2', note: note, status: s, createdAt: at);
    return [
      j('j1', 'm1', 'Oil + plug', JobStatus.inProgress),
      j('j2', 'm2', 'Brake pads', JobStatus.inProgress),
      j('j3', 'm3', 'Routine check', JobStatus.waiting),
      j('j4', 'm4', 'CVT belt', JobStatus.waiting),
      j('j5', 'm5', 'Air filter', JobStatus.waiting),
    ];
  }

  static List<Review> buildReviews() {
    final now = DateTime.now();
    Review r(String id, String owner, String name, int rating, String comment, int daysAgo) => Review(
        reviewId: id,
        mechanicId: 'u2',
        ownerId: owner,
        ownerName: name,
        rating: rating,
        comment: comment,
        createdAt: now.subtract(Duration(days: daysAgo)));
    return [
      r('v1', 'u4', 'Andi Pratama', 5, 'Fast and neat work. Explained everything clearly.', 2),
      r('v2', 'u5', 'Siti Rahma', 5, 'Receipt was attached right away. Very transparent.', 7),
      r('v3', 'u7', 'Dodi Kurniawan', 4, 'Good service, a little wait during peak hours.', 14),
    ];
  }

  static List<ActivityLog> buildActivityLogs() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return [
      ActivityLog(
          logId: 'l1',
          actorId: 'u9',
          title: 'New mechanic registered',
          subtitle: 'AHASS Sudirman',
          icon: 'wrench',
          createdAt: day.subtract(const Duration(days: 2)).add(const Duration(hours: 9))),
      ActivityLog(
          logId: 'l2',
          actorId: 'u10',
          title: 'Model added',
          subtitle: 'Suzuki Address · 2022',
          icon: 'bike',
          createdAt: day.subtract(const Duration(days: 9)).add(const Duration(hours: 14))),
    ];
  }

  /// Line labels used on the sample receipts.
  static const receiptLabels = {
    'gear': 'Gear oil 120 ml',
    'engine': 'Engine oil 0.8 L',
    'air': 'Air filter element',
    'spark': 'Spark plug NGK',
    'brake': 'Front brake pads',
    'cvt': 'CVT belt',
    'chain': 'Drive chain service',
    'coolant': 'Coolant',
    'battery': 'Battery',
    'tire': 'Tire check',
    'shoes': 'Brake shoes',
  };

  static const labourFee = 40000;
}

/// Default work description for each component (pre-filled in Record Maintenance).
const defaultWorkDescription = {
  'gear': 'Replaced gear oil (120 ml)',
  'engine': 'Replaced engine oil (0.8 L)',
  'air': 'Replaced air filter element',
  'spark': 'Replaced spark plug (NGK)',
  'brake': 'Replaced front brake pads',
  'cvt': 'Replaced CVT belt',
  'chain': 'Cleaned and lubricated drive chain',
  'coolant': 'Replaced coolant',
};

/// Components the admin can add as a rule, with recommended intervals.
const componentPresets = <(String key, String name, int km, int months)>[
  ('engine', 'Engine Oil', 2000, 3),
  ('gear', 'Gear Oil', 4000, 6),
  ('air', 'Air Filter', 8000, 12),
  ('spark', 'Spark Plug', 8000, 12),
  ('brake', 'Brake Pads', 12000, 12),
  ('shoes', 'Brake Shoes', 10000, 12),
  ('cvt', 'CVT Belt', 24000, 24),
  ('chain', 'Drive Chain', 4000, 6),
  ('coolant', 'Coolant', 20000, 24),
  ('battery', 'Battery', 20000, 24),
  ('tire', 'Tire Check', 5000, 6),
];
