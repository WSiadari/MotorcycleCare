import '../models/models.dart';

/// Demo data, identical to the "MotorcycleCare – User App Prototype" Figma file:
/// Honda Vario 160 · B 4521 KXR, registered 2 Feb 2026 at 0 km, 8,450 km on 21 Nov 2026.
class MockData {
  MockData._();

  static const catalog = <CatalogModel>[
    CatalogModel(id: 'vario', make: 'Honda', model: 'Vario 160', type: MotoType.matic, year: 2023),
    CatalogModel(id: 'pcx', make: 'Honda', model: 'PCX 160', type: MotoType.matic, year: 2024),
    CatalogModel(id: 'nmax', make: 'Yamaha', model: 'NMAX 155', type: MotoType.matic, year: 2023),
    CatalogModel(id: 'beat', make: 'Honda', model: 'BeAT', type: MotoType.matic, year: 2023),
    CatalogModel(id: 'address', make: 'Suzuki', model: 'Address', type: MotoType.matic, year: 2022),
    CatalogModel(id: 'supra', make: 'Honda', model: 'Supra X 125', type: MotoType.underbone, year: 2022),
    CatalogModel(id: 'r15', make: 'Yamaha', model: 'R15', type: MotoType.sport, year: 2023),
  ];

  // key, name, km, months, typical price (for sample receipts)
  static const _templates = <MotoType, List<(String, String, int, int, int)>>{
    MotoType.matic: [
      ('gear', 'Gear Oil', 4000, 6, 25000),
      ('engine', 'Engine Oil', 2000, 3, 58000),
      ('air', 'Air Filter', 8000, 12, 72000),
      ('spark', 'Spark Plug', 8000, 12, 28000),
      ('brake', 'Brake Pads', 12000, 12, 65000),
      ('cvt', 'CVT Belt', 24000, 24, 180000),
    ],
    MotoType.underbone: [
      ('engine', 'Engine Oil', 2000, 3, 50000),
      ('air', 'Air Filter', 8000, 12, 45000),
      ('spark', 'Spark Plug', 8000, 12, 25000),
      ('chain', 'Drive Chain', 4000, 6, 30000),
      ('brake', 'Brake Pads', 12000, 12, 55000),
    ],
    MotoType.trail: [
      ('engine', 'Engine Oil', 1500, 2, 60000),
      ('air', 'Air Filter', 3000, 3, 50000),
      ('spark', 'Spark Plug', 6000, 12, 30000),
      ('chain', 'Drive Chain', 500, 1, 30000),
      ('brake', 'Brake Pads', 8000, 12, 70000),
    ],
    MotoType.sport: [
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
      for (final t in _templates[m.type]!) {
        rules.add(MaintenanceRule(
          id: 'R-${id++}',
          catalogId: m.id,
          componentKey: t.$1,
          componentName: t.$2,
          intervalKm: t.$3,
          intervalMonths: t.$4,
          price: t.$5,
          source: "Owner's manual",
        ));
      }
    }
    return rules;
  }

  /// Demo accounts — one per actor of the use case diagram.
  static final users = <UserAccount>[
    UserAccount(id: 'u1', fullName: 'Rizky Yudha', email: 'rizky@mail.com', password: 'rizky123',
        createdAt: DateTime(2026, 2, 2)),
    UserAccount(id: 'u2', fullName: 'Budi Santoso', email: 'budi@mail.com', password: 'budi123',
        role: UserRole.mechanic, workshopName: 'Maju Jaya Motor', phone: '+62 812-3456-7890',
        createdAt: DateTime(2025, 6, 1)),
    UserAccount(id: 'u3', fullName: 'Dina Pratama', email: 'dina@mail.com', password: 'dina123',
        role: UserRole.admin, createdAt: DateTime(2025, 1, 10)),
    UserAccount(id: 'u4', fullName: 'Andi Pratama', email: 'andi@mail.com', password: 'andi123',
        createdAt: DateTime(2026, 3, 4)),
    UserAccount(id: 'u5', fullName: 'Siti Rahma', email: 'siti.rahma@mail.com', password: 'siti123',
        createdAt: DateTime(2026, 4, 12)),
    UserAccount(id: 'u6', fullName: 'Maya Lestari', email: 'maya@mail.com', password: 'maya123',
        createdAt: DateTime(2026, 5, 20)),
    UserAccount(id: 'u7', fullName: 'Dodi Kurniawan', email: 'dodi@mail.com', password: 'dodi123',
        createdAt: DateTime(2026, 6, 2)),
    UserAccount(id: 'u8', fullName: 'Hendra Gunawan', email: 'hendra@mail.com', password: 'hendra123',
        createdAt: DateTime(2026, 7, 9)),
    UserAccount(id: 'u9', fullName: 'Dimas Prakoso', email: 'dimas@mail.com', password: 'dimas123',
        role: UserRole.mechanic, workshopName: 'AHASS Sudirman', createdAt: DateTime(2026, 11, 20)),
    UserAccount(id: 'u10', fullName: 'Muhammad Agung', email: 'agung@mail.com', password: 'agung123',
        role: UserRole.admin, createdAt: DateTime(2025, 3, 3)),
    UserAccount(id: 'u11', fullName: 'Wahyu Siadari', email: 'wahyu@mail.com', password: 'wahyu123',
        active: false, createdAt: DateTime(2026, 8, 30)),
  ];

  /// Staff codes that let someone register an Admin account (demo).
  static const staffCodes = {'ADM-2026'};

  static Motorcycle _m(String id, String owner, String cat, String plate, int odo, DateTime reg) => Motorcycle(
        id: id,
        ownerId: owner,
        catalogId: cat,
        plate: plate,
        odometer: odo,
        odometerUpdatedAt: DateTime(2026, 11, 21),
        registrationOdometer: 0,
        registeredAt: reg,
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

  static List<MaintenanceRecord> buildRecords() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    MaintenanceRecord budi(String id, String moto, int daysAgo, int km, Map<String, String> items, int hour, int min,
            {bool receipt = true}) =>
        MaintenanceRecord(
          id: id,
          motorcycleId: moto,
          date: day.subtract(Duration(days: daysAgo)),
          odometer: km,
          items: items,
          workshop: 'Maju Jaya Motor',
          recordedBy: 'u2',
          recordedByName: 'Budi Santoso',
          createdAt: day.subtract(Duration(days: daysAgo)).add(Duration(hours: hour, minutes: min)),
          receipt: receipt ? Receipt(name: 'receipt_$id.jpg', isSample: true) : null,
        );
    return [
      MaintenanceRecord(
        id: 'r1',
        motorcycleId: 'm1',
        date: DateTime(2026, 5, 20),
        odometer: 2700,
        workshop: 'AHASS Sudirman',
        recordedByName: 'AHASS Sudirman',
        items: const {'engine': 'Replaced engine oil (0.8 L)'},
        receipt: const Receipt(name: 'nota_ahass_200526.jpg', isSample: true),
      ),
      MaintenanceRecord(
        id: 'r2',
        motorcycleId: 'm1',
        date: DateTime(2026, 6, 14),
        odometer: 4200,
        workshop: 'AHASS Sudirman',
        recordedByName: 'AHASS Sudirman',
        items: const {
          'gear': 'Replaced gear oil (120 ml)',
          'air': 'Replaced air filter element',
          'spark': 'Replaced spark plug (NGK)',
          'brake': 'Replaced front brake pads',
        },
        receipt: const Receipt(name: 'nota_ahass_140626.jpg', isSample: true),
      ),
      MaintenanceRecord(
        id: 'r3',
        motorcycleId: 'm1',
        date: DateTime(2026, 8, 5),
        odometer: 4700,
        recordedBy: 'u1',
        recordedByName: 'Rizky Yudha',
        items: const {'engine': 'Replaced engine oil (self-service)'},
      ),
      MaintenanceRecord(
        id: 'r4',
        motorcycleId: 'm1',
        date: DateTime(2026, 9, 28),
        odometer: 6700,
        workshop: 'AHASS Sudirman',
        recordedByName: 'AHASS Sudirman',
        items: const {'engine': 'Replaced engine oil (0.8 L)'},
        receipt: const Receipt(name: 'nota_ahass_280926.jpg', isSample: true),
      ),
      // Services by Budi Santoso (mechanic demo account), relative to today.
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
        ServiceJob(id: id, motorcycleId: moto, mechanicId: 'u2', note: note, status: s, createdAt: at);
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
    return [
      Review(ownerName: 'Andi Pratama', rating: 5, comment: 'Fast and neat work. Explained everything clearly.',
          createdAt: now.subtract(const Duration(days: 2))),
      Review(ownerName: 'Siti Rahma', rating: 5, comment: 'Receipt was attached right away. Very transparent.',
          createdAt: now.subtract(const Duration(days: 7))),
      Review(ownerName: 'Dodi Kurniawan', rating: 4, comment: 'Good service, a little wait during peak hours.',
          createdAt: now.subtract(const Duration(days: 14))),
    ];
  }

  static const workshops = [
    Workshop(
        name: 'Maju Jaya Motor',
        address: 'Jl. Raya Bekasi No. 45',
        city: 'Jakarta Timur',
        hours: 'Mon–Sat · 08:00–17:00',
        phone: '+62 21 4455 6677',
        closesAt: '17:00'),
    Workshop(
        name: 'AHASS Sudirman',
        address: 'Jl. Jend. Sudirman No. 12',
        city: 'Jakarta Pusat',
        hours: 'Mon–Sat · 08:00–16:00',
        phone: '+62 21 5700 1122',
        closesAt: '16:00'),
  ];

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

/// Components the admin can add as a rule, with recommended intervals
/// ("Recommended intervals fill in automatically and can be edited later").
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
