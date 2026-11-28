import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_status_screen.dart';
import 'sheets.dart';

/// Maintenance history with component filters.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.filter});

  final String? filter;

  static Route<void> route({String? filter}) => MaterialPageRoute(
        builder: (_) => HistoryScreen(filter: filter),
        settings: const RouteSettings(name: '/history'),
      );

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late String? _filter = widget.filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected;
    if (moto == null) return const Scaffold(body: SizedBox.shrink());
    final rules = app.rulesFor(moto);
    final names = {for (final r in rules) r.componentKey: r.componentName};
    final records = app.recordsFor(moto).where((r) => _filter == null || r.covers(_filter!)).toList();
    final n = records.length;

    return AppPage(children: [
      const TopBar('Maintenance History'),
      MotorcycleChip(motorcycleLine(app, moto)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Chip('All', on: _filter == null, onTap: () => setState(() => _filter = null)),
        for (final r in rules)
          _Chip(r.componentName, on: _filter == r.componentKey, onTap: () => setState(() => _filter = r.componentKey)),
      ]),
      Text(
        _filter == null
            ? '$n record${n == 1 ? '' : 's'} · newest first'
            : '$n record${n == 1 ? '' : 's'} for ${names[_filter]} · newest first',
        style: ts(12, medium, AppColors.muted),
      ),
      if (records.isEmpty)
        CardBox(
          child: Text(
            _filter == null
                ? 'No service recorded yet. Record a service from any component detail.'
                : 'No service recorded for ${names[_filter]} yet. Its status is counted from the first odometer '
                    'reading (${fmtKm(app.firstReadingOf(moto).valueKm)}, ${fmtDate(app.firstReadingOf(moto).recordedAt)}).',
            style: ts(13, regular, AppColors.muted, 1.4),
          ),
        ),
      for (final r in records)
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
            Row(children: [
              Expanded(child: Text(fmtDate(r.serviceDate), style: ts(14, semiBold))),
              Text(fmtKm(r.odometerKm), style: ts(13, medium, AppColors.muted)),
            ]),
            Row(spacing: 6, children: [
              AppIcon(r.byMechanic ? 'wrench' : 'user', color: AppColors.muted, size: 14),
              Expanded(
                child: Text('Logged by ${recordedByText(r, app.currentUser?.userId).replaceFirst('You', 'you')}',
                    style: ts(12, regular, AppColors.muted)),
              ),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in r.componentKeys)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text(names[k] ?? k, style: ts(12, medium, AppColors.accentStrong)),
                ),
            ]),
            if (app.canRate(r))
              Builder(builder: (_) {
                final mine = app.myReviewOf(r.mechanicId!);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: mine != null
                      ? null
                      : () async {
                          final ok = await showRateMechanic(context, r);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Thanks! Your review was sent to the mechanic.')));
                          }
                        },
                  child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                    AppIcon('star', color: mine != null ? AppColors.warn : AppColors.accent, size: 14),
                    Flexible(
                      child: Text(
                          mine != null ? 'You rated ${r.recordedByName ?? 'this mechanic'} ${mine.rating}/5' : 'Rate mechanic',
                          overflow: TextOverflow.ellipsis,
                          style: ts(12, semiBold, mine != null ? AppColors.warnText : AppColors.accentStrong)),
                    ),
                  ]),
                );
              }),
            if (r.receipt != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showReceipt(context, r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                    const AppIcon('receipt', color: AppColors.accent, size: 14),
                    Text('View receipt', style: ts(12, semiBold, AppColors.accentStrong)),
                  ]),
                ),
              )
            else
              Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                const AppIcon('receipt', color: AppColors.muted, size: 14),
                Text('No receipt attached', style: ts(12, regular, AppColors.muted)),
              ]),
          ]),
        ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? AppColors.accentStrong : AppColors.surface,
        shape: StadiumBorder(side: on ? BorderSide.none : const BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label, style: ts(13, semiBold, on ? Colors.white : AppColors.text)),
          ),
        ),
      );
}
