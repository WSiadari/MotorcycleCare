// Smoke tests: screens render on a phone-sized screen with the demo data and their main buttons
// work (no layout overflow, no exceptions).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcyclecare/models/models.dart';
import 'package:motorcyclecare/screens/admin/admin_reports.dart';
import 'package:motorcyclecare/screens/home_router.dart';
import 'package:motorcyclecare/screens/owner/history_screen.dart';
import 'package:motorcyclecare/state/app_state.dart';

/// Loads Roboto from the Flutter SDK so overflow checks use real text widths.
Future<void> loadRealFonts() async {
  Directory? dir;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (dir == null || !dir.existsSync()) {
    var d = File(Platform.resolvedExecutable).parent; // <flutter>/bin/cache/artifacts/engine/<platform>
    while (d.path != d.parent.path && !Directory('${d.path}/material_fonts').existsSync()) {
      d = d.parent;
    }
    dir = Directory('${d.path}/material_fonts');
  }
  if (!dir.existsSync()) return;
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    final file = File('${dir.path}/$f');
    if (file.existsSync()) roboto.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await roboto.load();
}

final _theme = ThemeData(fontFamily: 'Roboto');

Future<AppState> pumpHome(WidgetTester tester, String email, String password) async {
  tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 logical px
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = AppState.seeded();
  await tester.runAsync(() => app.login(email, password));
  // plain theme: the app theme downloads Google Fonts, which tests can't do
  await tester.pumpWidget(AppScope(state: app, child: MaterialApp(theme: _theme, home: homeFor(app.currentUser!))));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('owner: dashboard → odometer history, reminders, profile & settings', (tester) async {
    final app = await pumpHome(tester, 'rizky@mail.com', 'rizky123');
    await tester.tap(find.text('Honda Vario 160'));
    await tester.pumpAndSettle();
    expect(find.text('My Motorcycle'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Odometer History'), findsOneWidget);
    expect(find.text('Registration'), findsOneWidget);
    expect(find.text('8,450 km'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Gear Oil · Overdue'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(app.unreadReminders(app.selected!), 0);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile & settings'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance reminders'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((app.currentUser! as MotorcycleOwner).notificationEnabled, isFalse);
    expect(find.text('Log Out'), findsOneWidget);
  });

  testWidgets('owner: history shows the mechanic and lets the owner rate', (tester) async {
    final app = await pumpHome(tester, 'rizky@mail.com', 'rizky123');
    app.selectMotorcycle(app.myMotorcycles.single.motorcycleId);
    await tester.pumpWidget(AppScope(state: app, child: MaterialApp(theme: _theme, home: const HistoryScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Eko Saputra'), findsWidgets);
    expect(find.textContaining('self-service'), findsOneWidget);
    await tester.tap(find.text('Rate mechanic').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Review'));
    await tester.pumpAndSettle();
    expect(app.myReviewOf('u12')!.rating, 5);
    expect(find.textContaining('You rated Eko Saputra 5/5'), findsWidgets);
  });

  testWidgets('mechanic: dashboard and the not-found branch', (tester) async {
    await pumpHome(tester, 'budi@mail.com', 'budi123');
    expect(find.text("Today's Jobs"), findsOneWidget);
    expect(find.text('Maju Jaya Motor'), findsOneWidget);
    await tester.tap(find.text('Search').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try a plate that is not registered'));
    await tester.pumpAndSettle();
    expect(find.text('Motorcycle Not Found'), findsOneWidget);
    expect(find.text('Add Motorcycle for Customer'), findsOneWidget);
    expect(find.text('Search Again'), findsOneWidget);
  });

  testWidgets('admin: reports module', (tester) async {
    final app = await pumpHome(tester, 'dina@mail.com', 'dina123');
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('New mechanic registered'), findsOneWidget); // activity_logs
    await tester.pumpWidget(AppScope(state: app, child: MaterialApp(theme: _theme, home: const ReportsScreen())));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Users per role'), findsOneWidget);
    expect(find.text('Models per type'), findsOneWidget);
    expect(find.text('Every catalog model has maintenance rules.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Share report (CSV)'), 300);
    expect(find.text('Share report (CSV)'), findsOneWidget);
  });
}
