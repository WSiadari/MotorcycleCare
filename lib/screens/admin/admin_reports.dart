import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// System report: users per role (active / inactive), models per type, rules per model and
/// models without rules. Can be shared as a CSV file.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  SystemReport? _report;
  String? _error;
  bool _loading = true, _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (report, err) = await AppScope.read(context).loadSystemReport();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _report = report ?? _report;
      _error = err;
    });
  }

  Future<void> _share(SystemReport r) async {
    setState(() => _sharing = true);
    final stamp = '${r.generatedAt.year}${r.generatedAt.month.toString().padLeft(2, '0')}'
        '${r.generatedAt.day.toString().padLeft(2, '0')}';
    try {
      await SharePlus.instance.share(ShareParams(
        subject: 'MotorcycleCare system report · ${fmtDate(r.generatedAt)}',
        files: [XFile.fromData(utf8.encode(r.toCsv()), mimeType: 'text/csv', name: 'motorcyclecare-report-$stamp.csv')],
        fileNameOverrides: ['motorcyclecare-report-$stamp.csv'],
      ));
    } catch (e) {
      if (mounted) adminSnack(context, 'The report could not be shared on this device.');
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return AppPage(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      onRefresh: _load,
      children: [
        Row(spacing: 14, children: [
          SquareButton('chevL', iconSize: 20, tooltip: 'Back', onTap: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 1, children: [
              Text('System report', style: ts(22, bold)),
              Text(r == null ? 'Loading…' : 'Generated ${fmtDate(r.generatedAt)} · ${fmtTime(r.generatedAt)}',
                  style: ts(12, medium, AppColors.muted)),
            ]),
          ),
        ]),
        if (_error != null) ErrorBanner(_error!),
        if (r == null && _loading) const LoadingBox(),
        if (r != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.accentStrong, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text('Accounts', style: ts(13, medium, Colors.white)),
                  Text(fmtNum(r.totalUsers), style: ts(36, FontWeight.w800, Colors.white)),
                  Text('${r.rulesByModel.length} models · ${r.rulesByModel.fold<int>(0, (a, m) => a + m.$2)} rules',
                      style: ts(12, medium, Colors.white)),
                ]),
              ),
              const AppIcon('chart', color: Colors.white, size: 36),
            ]),
          ),
          const _Title('Users per role', 'active · inactive'),
          CardBox(
            radius: 18,
            child: Column(spacing: 12, children: [
              for (final role in UserRole.values)
                Row(spacing: 10, children: [
                  Expanded(child: Text(role.plural, style: ts(14, semiBold))),
                  Badge2.active(true),
                  SizedBox(
                      width: 34,
                      child: Text(fmtNum(r.usersByRole[role]!.$1), textAlign: TextAlign.right, style: ts(14, bold))),
                  Badge2.active(false),
                  SizedBox(
                      width: 34,
                      child: Text(fmtNum(r.usersByRole[role]!.$2),
                          textAlign: TextAlign.right, style: ts(14, bold, AppColors.muted))),
                ]),
            ]),
          ),
          _Title('Models per type', '${r.rulesByModel.length} models'),
          CardBox(
            radius: 18,
            child: Column(spacing: 12, children: [
              for (final t in MotorcycleType.values)
                Row(spacing: 10, children: [
                  SizedBox(width: 82, child: Text(t.label, style: ts(14, semiBold))),
                  Expanded(
                    child: ProgressTrack(
                      percent: r.modelsByType[t]! / math.max(1, r.modelsByType.values.fold<int>(0, math.max)) * 100,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(
                      width: 28,
                      child: Text('${r.modelsByType[t]}', textAlign: TextAlign.right, style: ts(14, bold))),
                ]),
            ]),
          ),
          const _Title('Rules per model', 'maintenance rules'),
          CardBox(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (final (m, n) in r.rulesByModel)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(spacing: 10, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 1, children: [
                        Text(m.name, style: ts(14, semiBold)),
                        Text('${m.motorcycleType.label} · ${m.modelYear}', style: ts(12, regular, AppColors.muted)),
                      ]),
                    ),
                    n == 0
                        ? const Badge2('No rules', bg: AppColors.dangerSoft, fg: AppColors.danger)
                        : Text('$n rule${n == 1 ? '' : 's'}', style: ts(13, bold, AppColors.accentStrong)),
                  ]),
                ),
            ]),
          ),
          _Title('Models without rules', '${r.modelsWithoutRules.length}'),
          if (r.modelsWithoutRules.isEmpty)
            const SuccessBanner('Every catalog model has maintenance rules.')
          else
            for (final m in r.modelsWithoutRules)
              AdminRow(
                icon: 'alert',
                title: m.name,
                subtitle: '${m.modelYear} · owners of this model get no reminders yet',
                onTap: () => AdminShell.goTab(context, 3, ruleModelId: m.catalogId),
              ),
          AppButton('Share report (CSV)', busy: _sharing, onPressed: () => _share(r)),
          const Note('The CSV opens in any spreadsheet app. Pull down to refresh the numbers.'),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.meta);

  final String title, meta;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Expanded(child: Text(title, style: ts(16, bold))),
          Text(meta, style: ts(12, medium, AppColors.muted)),
        ]),
      );
}
