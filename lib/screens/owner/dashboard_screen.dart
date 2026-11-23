import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_detail_screen.dart';
import 'component_status_screen.dart';
import 'history_screen.dart';
import 'sheets.dart';
import 'update_odometer_screen.dart';

/// "Was due at 8,200 km" / "Next at 8,700 km or 28 Dec 2026"
String scheduleLine(ComponentStatus s) =>
    s.health == Health.overdue ? 'Was due at ${fmtKm(s.nextKm)}' : 'Next at ${fmtKm(s.nextKm)} or ${fmtDate(s.nextDate)}';

/// C1 · Motorcycle Dashboard
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
        settings: const RouteSettings(name: '/dashboard'),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected;
    if (moto == null) return const Scaffold(body: SizedBox.shrink());
    final cat = app.catalogOf(moto);
    final statuses = app.statusesFor(moto);
    final ordered = [...statuses]..sort((a, b) => b.health.index.compareTo(a.health.index));
    final alerts = app.alertsFor(moto);
    final overdue = statuses.where((s) => s.health == Health.overdue).toList();
    final soon = statuses.where((s) => s.health == Health.dueSoon).toList();
    final today = app.servicedToday(moto);
    final records = app.recordsFor(moto).length;

    void push(Route r) => Navigator.of(context).push(r);

    return AppPage(children: [
      TopBar('My Motorcycle', back: false, actions: [
        SquareButton('logout', tooltip: 'Log out', onTap: () => showLogOut(context)),
        SquareButton('bell', tooltip: 'Reminders', badge: alerts.length, onTap: () => showReminders(context)),
      ]),
      // Motorcycle Card
      CardBox(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [
          Row(spacing: 12, children: [
            const IconBox('bike', size: 52, radius: 14, iconSize: 26),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text(cat.name, style: ts(17, bold)),
                Text('${moto.plate} · ${cat.year}', style: ts(13, regular, AppColors.muted)),
              ]),
            ),
            _PillButton('Switch', onTap: () => Navigator.of(context).maybePop()),
          ]),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text('Odometer · updated ${fmtDate(moto.odometerUpdatedAt)}', style: ts(12, regular, AppColors.muted)),
                Text(fmtKm(moto.odometer), style: ts(22, bold)),
              ]),
            ),
            _PillButton('Update', icon: 'pencil', radius: 12, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                fontSize: 13, onTap: () => push(UpdateOdometerScreen.route())),
          ]),
        ]),
      ),
      // Attention Banner
      _AttentionBanner(
        overdue: overdue,
        soon: soon,
        servicedToday: [
          for (final s in statuses)
            if (today.contains(s.rule.componentKey) && s.health == Health.onTrack) s.rule.componentName,
        ],
        onTap: () => push(ComponentStatusScreen.route()),
      ),
      // Menu
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
          Expanded(
            child: _MenuTile(
              icon: 'gauge',
              title: 'Component Status',
              subtitle: '${statuses.length} parts · '
                  '${overdue.isNotEmpty ? '${overdue.length} overdue' : soon.isNotEmpty ? '${soon.length} due soon' : 'all on track'}',
              onTap: () => push(ComponentStatusScreen.route()),
            ),
          ),
          Expanded(
            child: _MenuTile(
              icon: 'receipt',
              title: 'Maintenance History',
              subtitle: '$records record${records == 1 ? '' : 's'}',
              onTap: () => push(HistoryScreen.route()),
            ),
          ),
        ]),
      ),
      SectionHeader('Maintenance schedule', link: 'See all', onLink: () => push(ComponentStatusScreen.route())),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(children: [
          for (final s in ordered)
            InkWell(
              onTap: () => push(ComponentDetailScreen.route(s.rule.componentKey)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(spacing: 12, children: [
                  IconBox(componentIconName(s.rule.componentKey),
                      size: 32, radius: 9, iconSize: 16, bg: HealthStyle.of(s.health).iconBg, color: HealthStyle.of(s.health).icon),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                      Text(s.rule.componentName, style: ts(14, semiBold)),
                      Text(scheduleLine(s), style: ts(12, regular, AppColors.muted)),
                    ]),
                  ),
                  StatusBadge(s.health),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton(this.label,
      {required this.onTap,
      this.icon,
      this.radius = 10,
      this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      this.fontSize = 12});

  final String label;
  final String? icon;
  final VoidCallback onTap;
  final double radius, fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
              if (icon != null) AppIcon(icon!, color: AppColors.accent, size: 14),
              Text(label, style: ts(fontSize, semiBold, AppColors.accentStrong)),
            ]),
          ),
        ),
      );
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.overdue, required this.soon, required this.servicedToday, required this.onTap});

  final List<ComponentStatus> overdue, soon;
  final List<String> servicedToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = overdue.length + soon.length;
    final (bg, fg, iconColor, icon) = overdue.isNotEmpty
        ? (AppColors.dangerSoft, AppColors.danger, AppColors.dangerIcon, 'alert')
        : soon.isNotEmpty
            ? (AppColors.warnSoft, AppColors.warnText, AppColors.warnText, 'alert')
            : (AppColors.successSoft, AppColors.successText, AppColors.successIcon, 'check');
    final parts = [
      for (final s in overdue) '${s.rule.componentName} is overdue',
      for (final s in soon) '${s.rule.componentName} is due soon',
      for (final name in servicedToday) '$name serviced today',
    ];
    final title = n == 0 ? 'All components are on track' : '$n component${n == 1 ? ' needs' : 's need'} attention';
    final subtitle = parts.isEmpty ? 'Keep your odometer up to date to stay ahead.' : parts.join(' · ');
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(spacing: 10, children: [
            AppIcon(icon, color: iconColor, size: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text(title, style: ts(14, semiBold, fg)),
                Text(subtitle, style: ts(12, medium, fg)),
              ]),
            ),
            AppIcon('chevR', color: iconColor, size: 16),
          ]),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final String icon, title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CardBox(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
          IconBox(icon),
          Text(title, style: ts(14, semiBold)),
          Text(subtitle, style: ts(12, regular, AppColors.muted)),
        ]),
      );
}
