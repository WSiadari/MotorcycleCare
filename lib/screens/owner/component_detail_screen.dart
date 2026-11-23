import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_status_screen.dart';
import 'history_screen.dart';
import 'record_maintenance_screen.dart';
import 'sheets.dart';

/// 04a–04f · Component detail
class ComponentDetailScreen extends StatelessWidget {
  const ComponentDetailScreen({super.key, required this.componentKey});

  final String componentKey;

  static Route<void> route(String key) => MaterialPageRoute(
        builder: (_) => ComponentDetailScreen(componentKey: key),
        settings: RouteSettings(name: '/component/$key'),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected;
    if (moto == null) return const Scaffold(body: SizedBox.shrink());
    final cat = app.catalogOf(moto);
    final rule = app.ruleFor(moto, componentKey);
    final s = app.statusOf(moto, rule);
    final st = HealthStyle.of(s.health);
    final left = s.kmLeft(moto.odometer);
    final last = s.lastRecord;
    final history = app.recordsFor(moto).where((r) => r.items.containsKey(componentKey)).toList();
    final name = rule.componentName;
    final verb = componentKey == 'engine' || componentKey == 'gear' ? 'change' : 'service';

    String? reminder;
    if (s.health == Health.overdue) {
      reminder = left < 0
          ? 'Reminder sent ${fmtDate(moto.odometerUpdatedAt)} · $name has passed its ${fmtKm(rule.intervalKm)} interval. Service it soon.'
          : 'Reminder sent ${fmtDate(moto.odometerUpdatedAt)} · $name has passed its ${fmtMonths(rule.intervalMonths)} interval. Service it soon.';
    } else if (s.health == Health.dueSoon) {
      reminder = 'Due-soon reminder sent ${fmtDate(moto.odometerUpdatedAt)} · '
          '${left > 0 ? '${fmtKm(left)} left before the next ${name.toLowerCase()} $verb.' : 'the time limit for the next ${name.toLowerCase()} $verb is close.'}';
    }

    return AppPage(children: [
      TopBar(name),
      VehicleChip(vehicleLine(app, moto)),
      // Hero
      CardBox(
        radius: 20,
        padding: const EdgeInsets.all(18),
        borderColor: s.health == Health.overdue ? AppColors.danger : AppColors.border,
        borderWidth: s.health == Health.overdue ? 1.5 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBox(componentIconName(componentKey), size: 44, radius: 12, iconSize: 22, bg: st.iconBg, color: st.icon),
            const Spacer(),
            StatusBadge(s.health),
          ]),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, spacing: 6, children: [
            Text(fmtKm(s.usedKm), style: ts(28, bold)),
            Flexible(child: Text('of ${fmtKm(rule.intervalKm)} interval', style: ts(13, medium, AppColors.muted))),
          ]),
          ProgressTrack(percent: s.kmPercent, color: st.bar, height: 9),
          Row(children: [
            Expanded(child: Text('${s.kmPercent.round()}% used', style: ts(13, semiBold, st.percent))),
            Text(left < 0 ? 'Overdue by ${fmtKm(-left)}' : '${fmtKm(left)} remaining', style: ts(13, semiBold, st.percent)),
          ]),
          Text('Time since last service: ${s.timePercent.round()}% of ${fmtMonths(rule.intervalMonths)}',
              style: ts(12, regular, AppColors.muted)),
        ]),
      ),
      if (reminder != null) Note(reminder, icon: 'bell', bg: st.soft, iconColor: st.icon, textColor: st.text),
      SectionHeader('Next service'),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
          Expanded(child: _Tile(icon: 'gauge', label: 'At odometer', value: fmtKm(s.nextKm))),
          Expanded(child: _Tile(icon: 'cal', label: 'Or by date', value: fmtDate(s.nextDate))),
        ]),
      ),
      Text('Whichever comes first, based on the Admin rule.', style: ts(12, regular, AppColors.muted)),
      SectionHeader('Maintenance rule'),
      CardBox(
        child: Column(spacing: 10, children: [
          InfoRow('Interval', 'Every ${fmtKm(rule.intervalKm)} or ${fmtMonths(rule.intervalMonths)}'),
          InfoRow('Applies to', '${cat.name} · ${cat.year}'),
          InfoRow('Set by', 'Admin · ${rule.source.isEmpty ? "Owner's manual" : rule.source}'),
        ]),
      ),
      SectionHeader('Last service'),
      CardBox(
        child: last == null
            ? Text(
                'No service recorded yet. Status is counted from the odometer at registration '
                '(${fmtKm(moto.registrationOdometer)}, ${fmtDate(moto.registeredAt)}).',
                style: ts(13, regular, AppColors.muted, 1.4))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
                InfoRow('Date', fmtDate(last.date)),
                InfoRow('Odometer', fmtKm(last.odometer)),
                InfoRow('Logged by', last.byMechanic ? 'Mechanic · ${last.workshop}' : 'You'),
                InfoRow('Work done', last.items[componentKey] ?? ''),
                if (last.receipt != null)
                  Material(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showReceipt(context, last),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(spacing: 10, children: [
                          const AppIcon('receipt', color: AppColors.accent, size: 18),
                          Expanded(child: Text('View service receipt', style: ts(13, semiBold, AppColors.accentStrong))),
                          const AppIcon('chevR', color: AppColors.accent, size: 16),
                        ]),
                      ),
                    ),
                  ),
              ]),
      ),
      SectionHeader('Service history',
          link: 'See all',
          onLink: () => Navigator.of(context).push(HistoryScreen.route(filter: componentKey))),
      CardBox(
        child: history.isEmpty
            ? Text('Nothing here yet.', style: ts(13, regular, AppColors.muted))
            : Column(spacing: 12, children: [
                for (final r in history)
                  Row(spacing: 12, children: [
                    IconBox(r.byMechanic ? 'wrench' : 'user', size: 32, radius: 9, iconSize: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                        Text(r.items[componentKey] ?? '', style: ts(14, semiBold)),
                        Text('${fmtDate(r.date)} · ${fmtKm(r.odometer)} · ${r.loggedBy}',
                            style: ts(12, regular, AppColors.muted)),
                      ]),
                    ),
                    if (r.receipt != null)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => showReceipt(context, r),
                            child: const Center(child: AppIcon('receipt', color: AppColors.accent, size: 16)),
                          ),
                        ),
                      ),
                  ]),
              ]),
      ),
      AppButton('Record Maintenance',
          onPressed: () => Navigator.of(context).push(RecordMaintenanceScreen.route({componentKey}))),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});

  final String icon, label, value;

  @override
  Widget build(BuildContext context) => CardBox(
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
          AppIcon(icon, color: AppColors.accent, size: 18),
          Text(label, style: ts(12, regular, AppColors.muted)),
          Text(value, style: ts(17, bold)),
        ]),
      );
}
