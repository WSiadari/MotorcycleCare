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

/// Reminders sheet.
/// Lists the reminders stored for this motorcycle (reminders table, newest first). Opening one marks it read.
Future<void> showReminders(BuildContext context) {
  final app = AppScope.read(context);
  final moto = app.selected!;
  return showAppSheet(context, title: 'Reminders', children: (sheet) => [
        ListenableBuilder(
          listenable: app,
          builder: (_, __) {
            final list = app.remindersFor(moto);
            final unread = list.where((r) => !r.isRead).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
              if (list.isEmpty)
                const SuccessBanner('No reminders. All components are on track.')
              else
                for (final r in list)
                  Builder(builder: (_) {
                    final rule = app.ruleById(r.ruleId);
                    final st = StatusStyle.of(r.dueStatus);
                    return Material(
                      color: r.isRead ? AppColors.surface : st.soft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: r.isRead ? AppColors.border : Colors.transparent)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          app.markReminderRead(r);
                          Navigator.of(sheet).pop();
                          if (rule != null) Navigator.of(context).push(ComponentDetailScreen.route(rule.componentKey));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
                            AppIcon('bell', color: st.icon, size: 18),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                                Text('${rule?.componentName ?? 'Component'} · ${st.label}', style: ts(14, semiBold, st.text)),
                                Text(r.message, style: ts(12, medium, r.isRead ? AppColors.muted : st.text, 1.35)),
                                Text(r.isRead ? 'Sent ${fmtDate(r.createdAt)} · read' : 'Sent ${fmtDate(r.createdAt)} · new',
                                    style: ts(11, regular, AppColors.muted)),
                              ]),
                            ),
                            if (!r.isRead)
                              Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(color: st.dot, shape: BoxShape.circle)),
                          ]),
                        ),
                      ),
                    );
                  }),
              if (unread > 0)
                AppButton('Mark all as read', kind: ButtonKind.secondary, onPressed: () => app.markAllRemindersRead(moto)),
              Text(
                  'A reminder is saved when a component reaches 80% of its interval (km or months) or passes it. '
                  'Notifications follow the Maintenance reminders switch in Profile & Settings.',
                  style: ts(12, regular, AppColors.muted, 1.4)),
            ]);
          },
        ),
      ]);
}

/// Rate the mechanic who recorded [record] (reviews table). Returns true when a review was saved.
Future<bool> showRateMechanic(BuildContext context, ServiceRecord record) async {
  final saved = await showAppSheet<bool>(context, title: 'Rate mechanic', gap: 14, children: (sheet) => [
        _RateSheet(record: record, app: AppScope.read(context), onDone: () => Navigator.of(sheet).pop(true)),
      ]);
  return saved ?? false;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.record, required this.app, required this.onDone});

  final ServiceRecord record;
  final AppState app;
  final VoidCallback onDone;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.app.rateMechanic(record: widget.record, rating: _rating, comment: _comment.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [
      Text('${r.recordedByName ?? 'Mechanic'}${r.atWorkshop ? ' · ${r.workshopName}' : ''} · ${fmtDate(r.serviceDate)}',
          style: ts(13, regular, AppColors.muted)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i star${i == 1 ? '' : 's'}',
            onPressed: () => setState(() => _rating = i),
            icon: Icon(Icons.star_rounded, size: 36, color: i <= _rating ? AppColors.warn : AppColors.border),
          ),
      ]),
      AppInput(
        controller: _comment,
        hint: 'What went well? (optional)',
        minLines: 2,
        maxLines: 4,
        fontWeight: medium,
        textCapitalization: TextCapitalization.sentences,
      ),
      if (_error != null) ErrorBanner(_error!),
      AppButton('Send Review', busy: _busy, onPressed: _send),
    ]);
  }
}

/// Service receipt sheet.
Future<void> showReceipt(BuildContext context, ServiceRecord record) {
  final app = AppScope.read(context);
  final moto = app.selected!;
  final receipt = record.receipt!;
  return showAppSheet(context, title: 'Service receipt', children: (_) {
    return [
      Text(receipt.isSample ? '${receipt.fileName} · sample receipt' : receipt.fileName,
          style: ts(12, regular, AppColors.muted)),
      if (receipt.localPath != null && File(receipt.localPath!).existsSync())
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(receipt.localPath!), fit: BoxFit.contain),
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
  final ServiceRecord record;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final lines = <(String, int)>[
      for (final k in record.componentKeys)
        (MockData.receiptLabels[k] ?? k, MockData.samplePrice(app.catalogOf(moto).motorcycleType, k)),
      if (record.byMechanic) ('Labour', MockData.labourFee),
    ];
    final total = lines.fold<int>(0, (a, l) => a + l.$2);
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        Text(record.workshopName ?? 'Self service', style: ts(15, bold)),
        Text('${fmtDate(record.serviceDate)} · ${moto.plateNumber} · ${fmtKm(record.odometerKm)}',
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

  final ServiceReceipt receipt;
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

/// Log out confirmation.
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

/// Odometer confirmation sheet. Returns true when confirmed.
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
