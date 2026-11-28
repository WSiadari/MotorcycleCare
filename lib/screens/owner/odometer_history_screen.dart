import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'component_status_screen.dart';
import 'update_odometer_screen.dart';

/// Odometer History (odometer_readings): every update and confirmation, newest first.
/// The oldest reading was saved when the motorcycle was registered.
class OdometerHistoryScreen extends StatelessWidget {
  const OdometerHistoryScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const OdometerHistoryScreen(),
        settings: const RouteSettings(name: '/odometer-history'),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected;
    if (moto == null) return const Scaffold(body: SizedBox.shrink());
    final readings = app.readingsFor(moto);
    final first = app.firstReadingOf(moto);
    final me = app.currentUser?.userId;
    // Names of mechanics are known from the service records they saved.
    final names = {
      for (final r in app.recordsFor(moto))
        if (r.recordedByUserId != null && r.recordedByName != null) r.recordedByUserId!: r.recordedByName!,
    };
    final days = today().difference(dateOnly(first.recordedAt)).inDays;
    final perMonth = days < 30 ? null : (moto.currentOdometer - first.valueKm) / days * 30.44;

    String who(OdometerReading r) =>
        r.recordedBy == null ? 'Unknown' : (r.recordedBy == me ? 'You' : (names[r.recordedBy] ?? 'Mechanic'));

    return AppPage(children: [
      const TopBar('Odometer History'),
      MotorcycleChip(motorcycleLine(app, moto)),
      CardBox(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text('Current odometer', style: ts(12, regular, AppColors.muted)),
              Text(fmtKm(moto.currentOdometer), style: ts(22, bold)),
              Text('${readings.length} reading${readings.length == 1 ? '' : 's'} since ${fmtDate(first.recordedAt)}',
                  style: ts(12, regular, AppColors.muted)),
            ]),
          ),
          if (perMonth != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, spacing: 2, children: [
              Text('Average', style: ts(12, regular, AppColors.muted)),
              Text('${fmtNum(perMonth)} km', style: ts(16, bold, AppColors.accentStrong)),
              Text('per month', style: ts(12, regular, AppColors.muted)),
            ]),
        ]),
      ),
      const SectionHeader('Readings'),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(children: [
          for (final (i, r) in readings.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(spacing: 12, children: [
                IconBox(i == readings.length - 1 ? 'bike' : 'gauge', size: 32, radius: 9, iconSize: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                    Text(fmtKm(r.valueKm), style: ts(14, semiBold)),
                    Text('${fmtDate(r.recordedAt)} · ${fmtTime(r.recordedAt)} · ${who(r)}',
                        style: ts(12, regular, AppColors.muted)),
                  ]),
                ),
                Text(
                  i == readings.length - 1
                      ? 'Registration'
                      : (r.valueKm == readings[i + 1].valueKm
                          ? 'Confirmed'
                          : '+${fmtKm(r.valueKm - readings[i + 1].valueKm)}'),
                  style: ts(12, semiBold, i == readings.length - 1 ? AppColors.muted : AppColors.accentStrong),
                ),
              ]),
            ),
        ]),
      ),
      const Note('The first reading is the odometer you entered when you registered the motorcycle. '
          'Component status is counted from it until a component gets its first service.'),
      AppButton('Update Odometer', onPressed: () => Navigator.of(context).push(UpdateOdometerScreen.route())),
    ]);
  }
}
