import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_detail_screen.dart';
import 'component_status_screen.dart';
import 'dashboard_screen.dart';

/// Confirmation after a maintenance record is saved.
class MaintenanceSavedScreen extends StatelessWidget {
  const MaintenanceSavedScreen({super.key, required this.record});

  final ServiceRecord record;

  static Route<void> route(ServiceRecord record) => MaterialPageRoute(
        builder: (_) => MaintenanceSavedScreen(record: record),
        settings: const RouteSettings(name: '/saved'),
      );

  /// Goes back to Component Status if it is in the history, otherwise opens it above the dashboard.
  static void backToStatus(BuildContext context) {
    final nav = Navigator.of(context);
    var found = false;
    nav.popUntil((r) {
      if (r.settings.name == '/status') found = true;
      return found || r.settings.name == '/dashboard' || r.isFirst;
    });
    if (!found) nav.push(ComponentStatusScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected!;
    final n = record.items.length;
    final rules = app.rulesFor(moto).where((r) => record.covers(r.componentKey)).toList();
    final first = rules.first;

    return AppPage(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const AppIcon('check', color: AppColors.successIcon, size: 36),
          ),
        ),
        Text('Maintenance saved', textAlign: TextAlign.center, style: ts(22, bold)),
        Text(
          '$n component${n == 1 ? '' : 's'} updated · ${fmtDate(record.serviceDate)} · ${fmtKm(record.odometerKm)} · '
          '${record.receipt != null ? 'receipt attached' : 'no receipt'}',
          textAlign: TextAlign.center,
          style: ts(14, regular, AppColors.muted, 1.43),
        ),
        const SectionHeader('Updated schedule'),
        CardBox(
          child: Column(spacing: 12, children: [
            for (final r in rules)
              Builder(builder: (_) {
                final s = app.statusOf(moto, r);
                final st = StatusStyle.of(s.status);
                return Row(spacing: 12, children: [
                  IconBox(componentIconName(r.componentKey), size: 32, radius: 9, iconSize: 16, bg: st.iconBg, color: st.icon),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                      Text(r.componentName, style: ts(14, semiBold)),
                      Text(scheduleLine(s), style: ts(12, regular, AppColors.muted)),
                    ]),
                  ),
                  StatusBadge(s.status),
                ]);
              }),
          ]),
        ),
        AppButton('View ${first.componentName}',
            onPressed: () => Navigator.of(context).pushReplacement(ComponentDetailScreen.route(first.componentKey))),
        AppButton('Back to Component Status', kind: ButtonKind.secondary, onPressed: () => backToStatus(context)),
      ],
    );
  }
}
