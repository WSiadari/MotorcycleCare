import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_detail_screen.dart';
import 'history_screen.dart';
import 'sheets.dart';
import 'update_odometer_screen.dart';

String motorcycleLine(AppState app, Motorcycle m) => '${app.catalogOf(m).name} · ${m.plateNumber} · ${fmtKm(m.currentOdometer)}';

/// Maintenance schedule and status of every component.
class ComponentStatusScreen extends StatelessWidget {
  const ComponentStatusScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const ComponentStatusScreen(),
        settings: const RouteSettings(name: '/status'),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected;
    if (moto == null) return const Scaffold(body: SizedBox.shrink());
    final statuses = app.statusesFor(moto);

    final rows = <Widget>[];
    for (var i = 0; i < statuses.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
          Expanded(child: _ComponentCard(statuses[i])),
          Expanded(child: i + 1 < statuses.length ? _ComponentCard(statuses[i + 1]) : const SizedBox.shrink()),
        ]),
      ));
    }

    return AppPage(children: [
      TopBar('Component Status', actions: [
        SquareButton('bell', tooltip: 'Reminders', badge: app.unreadReminders(moto), onTap: () => showReminders(context)),
      ]),
      MotorcycleChip(motorcycleLine(app, moto),
          onTap: () => Navigator.of(context).push(UpdateOdometerScreen.route())),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: rows),
      const Note('Based on Admin rules and the last service record, whether logged by you or a mechanic.'),
      AppButton('View Maintenance History',
          kind: ButtonKind.ghost, onPressed: () => Navigator.of(context).push(HistoryScreen.route())),
    ]);
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard(this.s);

  final ComponentStatus s;

  @override
  Widget build(BuildContext context) {
    final st = StatusStyle.of(s.status);
    final overdue = s.status == MaintenanceStatus.overdue;
    return CardBox(
      borderColor: overdue ? AppColors.danger : AppColors.border,
      borderWidth: overdue ? 1.5 : 1,
      onTap: () => Navigator.of(context).push(ComponentDetailScreen.route(s.rule.componentKey)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 7, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBox(componentIconName(s.rule.componentKey), bg: st.iconBg, color: st.icon),
          const Spacer(),
          StatusBadge(s.status),
        ]),
        const SizedBox(height: 2),
        Text(s.rule.componentName, style: ts(15, semiBold)),
        Text('${fmtNum(s.usedKm)} / ${fmtKm(s.rule.intervalKm)}', style: ts(12, regular, AppColors.muted)),
        ProgressTrack(percent: s.kmPercent, color: st.bar),
        Text('${s.kmPercent.round()}% of interval used', style: ts(12, medium, st.percent)),
      ]),
    );
  }
}
