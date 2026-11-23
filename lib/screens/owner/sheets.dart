import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_detail_screen.dart';
import '../auth/welcome_screen.dart';

String reminderSubtitle(ComponentStatus s, Motorcycle m) {
  final left = s.kmLeft(m.odometer);
  if (s.health == Health.overdue) {
    return left < 0
        ? 'Overdue by ${fmtKm(-left)} · was due at ${fmtKm(s.nextKm)}'
        : 'Time limit passed · was due ${fmtDate(s.nextDate)}';
  }
  return '${fmtKm(left < 0 ? 0 : left)} remaining · due by ${fmtDate(s.nextDate)}';
}

/// 05 · Reminders (overlay) — Receive Maintenance Reminder
Future<void> showReminders(BuildContext context) {
  final app = AppScope.read(context);
  final moto = app.selected!;
  return showAppSheet(context, title: 'Reminders', children: (sheet) {
    final alerts = app.alertsFor(moto);
    return [
      if (alerts.isEmpty)
        const SuccessBanner('All components are on track.')
      else
        for (final s in alerts)
          Builder(builder: (_) {
            final st = HealthStyle.of(s.health);
            return Material(
              color: st.soft,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(sheet).pop();
                  Navigator.of(context).push(ComponentDetailScreen.route(s.rule.componentKey));
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(spacing: 10, children: [
                    AppIcon('bell', color: st.icon, size: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                        Text('${s.rule.componentName} · ${st.label}', style: ts(14, semiBold, st.text)),
                        Text(reminderSubtitle(s, moto), style: ts(12, medium, st.text)),
                      ]),
                    ),
                    AppIcon('chevR', color: st.icon, size: 16),
                  ]),
                ),
              ),
            );
          }),
      Text('Reminders are sent when a component reaches 80% of its interval (km or months) or passes it.',
          style: ts(12, regular, AppColors.muted, 1.4)),
    ];
  });
}

/// 06 · Service Receipt (overlay)
Future<void> showReceipt(BuildContext context, MaintenanceRecord record) {
  final app = AppScope.read(context);
  final moto = app.selected!;
  final receipt = record.receipt!;
  return showAppSheet(context, title: 'Service receipt', children: (_) {
    return [
      Text(receipt.isSample ? '${receipt.name} · sample receipt' : receipt.name,
          style: ts(12, regular, AppColors.muted)),
      if (receipt.path != null && File(receipt.path!).existsSync())
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(receipt.path!), fit: BoxFit.contain),
        )
      else if (receipt.storagePath != null)
        _OnlineReceipt(receipt: receipt, app: app)
      else
        _SampleReceipt(moto: moto, record: record, app: app),
    ];
  });
}

class _SampleReceipt extends StatelessWidget {
  const _SampleReceipt({required this.moto, required this.record, required this.app});

  final Motorcycle moto;
  final MaintenanceRecord record;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final lines = <(String, int)>[
      for (final k in record.items.keys)
        (MockData.receiptLabels[k] ?? k, app.rulesFor(moto).where((r) => r.componentKey == k).firstOrNull?.price ?? 0),
      if (record.byMechanic) ('Labour', MockData.labourFee),
    ];
    final total = lines.fold<int>(0, (a, l) => a + l.$2);
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        Text(record.workshop ?? 'Self service', style: ts(15, bold)),
        Text('${fmtDate(record.date)} · ${moto.plate} · ${fmtKm(record.odometer)}',
            style: ts(12, regular, AppColors.muted)),
        for (final l in lines) InfoRow(l.$1, fmtRupiah(l.$2)),
        InfoRow('Total', fmtRupiah(total), valueColor: AppColors.accentStrong),
      ]),
    );
  }
}

/// Receipt stored in Supabase Storage, shown through a temporary signed link.
class _OnlineReceipt extends StatefulWidget {
  const _OnlineReceipt({required this.receipt, required this.app});

  final Receipt receipt;
  final AppState app;

  @override
  State<_OnlineReceipt> createState() => _OnlineReceiptState();
}

class _OnlineReceiptState extends State<_OnlineReceipt> {
  late final Future<String?> _url = widget.app.backend.receiptUrl(widget.receipt);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBox();
        final url = snap.data;
        if (snap.hasError || url == null) {
          return const ErrorBanner('The receipt could not be loaded. Check your internet connection.');
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null ? child : const LoadingBox(),
            errorBuilder: (_, __, ___) => const ErrorBanner('The receipt image could not be opened.'),
          ),
        );
      },
    );
  }
}

/// C2 · Log Out (overlay)
Future<void> showLogOut(BuildContext context) {
  return showAppSheet(context, title: 'Log out?', gap: 14, children: (sheet) {
    return [
      Text('You will need to log in again to see your motorcycles and reminders.',
          style: ts(13, regular, AppColors.muted, 1.45)),
      AppButton('Log Out', onPressed: () async {
        final app = AppScope.read(context);
        final nav = Navigator.of(context);
        Navigator.of(sheet).pop();
        await app.logout();
        nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
      }),
      AppButton('Stay logged in', kind: ButtonKind.secondary, onPressed: () => Navigator.of(sheet).pop()),
    ];
  });
}

/// 02b / 02c · Confirm odometer (overlay). Returns true when confirmed.
Future<bool> confirmOdometerSheet(BuildContext context, {required int km, required String message}) async {
  final ok = await showAppSheet<bool>(context, title: 'Confirm odometer', gap: 14, children: (sheet) {
    return [
      Row(spacing: 12, children: [
        const IconBox('gauge', size: 44, radius: 12, iconSize: 22),
        Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
          Text('Current odometer', style: ts(12, regular, AppColors.muted)),
          Text(fmtKm(km), style: ts(24, bold)),
        ]),
      ]),
      Text(message, style: ts(13, regular, AppColors.muted, 1.45)),
      AppButton('Confirm', onPressed: () => Navigator.of(sheet).pop(true)),
      AppButton('Cancel', kind: ButtonKind.secondary, onPressed: () => Navigator.of(sheet).pop(false)),
    ];
  });
  return ok ?? false;
}
