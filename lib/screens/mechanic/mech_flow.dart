import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart' show recordedByText;
import 'mech_ui.dart';
import 'mechanic_shell.dart';

Route<void> _r(Widget w) => MaterialPageRoute(builder: (_) => w);

void backToDashboard(BuildContext context) => MechanicShell.goTab(context, 0);

// ====================================================================== Motorcycle Not Found
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) => MechPage(
        header: const MechHeader('Search Result'),
        bottom: [
          MechButton('Add Motorcycle for Customer',
              onTap: () => Navigator.of(context).pushReplacement(_r(AddMotorcycleScreen(plate: plate)))),
          MechButton('Search Again', icon: 'search', kind: MechButtonKind.soft, onTap: () => MechanicShell.goTab(context, 1)),
          MechButton('Back to Dashboard', kind: MechButtonKind.soft, onTap: () => backToDashboard(context)),
        ],
        children: [
          const SizedBox(height: 40),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                      color: MC.soft, shape: BoxShape.circle, border: Border.all(color: MC.softBorder, width: 1.5)),
                  alignment: Alignment.center,
                  child: const AppIcon('bike', color: MC.accentText, size: 56),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: MC.danger, shape: BoxShape.circle, border: Border.all(color: MC.bg, width: 3)),
                    child: const AppIcon('x', color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
          Text('Motorcycle Not Found', textAlign: TextAlign.center, style: mt(22, mXBold)),
          Text("We couldn't find a motorcycle with plate $plate. Please check the plate number and try again.",
              textAlign: TextAlign.center, style: mt(13, mMedium, MC.muted, 1.45)),
          const InfoBanner('Check the plate, or register the motorcycle for the customer with Add Motorcycle.'),
        ],
      );
}

// ====================================================================== Motorcycle Information
class MotorcycleInfoScreen extends StatelessWidget {
  const MotorcycleInfoScreen({super.key, required this.motorcycleId});

  final String motorcycleId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.motorcycleById(motorcycleId);
    if (m == null) return const MechPage(header: MechHeader('Motorcycle Information'), children: []);
    final cat = app.catalogOf(m);
    final last = app.recordsFor(m).firstOrNull;
    final statuses = app.statusesFor(m);
    return MechPage(
      header: const MechHeader('Motorcycle Information'),
      bottom: [
        MechButton('Start Inspection', icon: 'wrench', onTap: () async {
          await app.startJob(m, _jobNote(app, m));
          if (context.mounted) Navigator.of(context).push(_r(InspectScreen(motorcycleId: m.motorcycleId)));
        }),
        MechButton('View Maintenance History',
            icon: 'clock',
            kind: MechButtonKind.soft,
            onTap: () => Navigator.of(context).push(_r(MechHistoryScreen(motorcycleId: m.motorcycleId)))),
      ],
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: MC.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: MC.accent, width: 2)),
          child: Column(spacing: 10, children: [
            Row(spacing: 12, children: [
              const IconSquare('bike', size: 48, radius: 16, iconSize: 24),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text(m.plateNumber, style: mt(22, mXBold)),
                  Text('${cat.name} · ${cat.modelYear}', style: mt(12, mMedium, MC.muted)),
                ]),
              ),
              StatusChip.ok('Found'),
            ]),
            KV('Owner', app.ownerOf(m)?.fullName ?? '—'),
            KV('Latest Odometer', fmtKm(m.currentOdometer), valueColor: MC.accentText),
            KV('Last Service', last == null ? 'Not serviced yet' : fmtDate(last.serviceDate)),
          ]),
        ),
        Text('Component Status', style: mt(16, mXBold)),
        MechCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (final (i, s) in statuses.indexed) ...[
              if (i > 0) const Divider(height: 1, color: MC.border),
              SizedBox(
                height: 46,
                child: Row(children: [
                  Expanded(child: Text(s.rule.componentName, style: mt(14, mSemi))),
                  StatusChip.status(s.status),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

/// Short job note: the components that need attention ("Oil + plug").
String _jobNote(AppState app, Motorcycle m) {
  final alerts = app.alertsFor(m).map((s) => s.rule.componentName).take(2).toList();
  return alerts.isEmpty ? 'Routine check' : alerts.join(' + ');
}

// ====================================================================== Maintenance History
enum _HistFilter { all, byMe, byMechanic }

/// Maintenance history of one motorcycle, or — without [motorcycleId] — every service the mechanic recorded.
class MechHistoryScreen extends StatefulWidget {
  const MechHistoryScreen({super.key, this.motorcycleId});

  final String? motorcycleId;

  @override
  State<MechHistoryScreen> createState() => _MechHistoryScreenState();
}

class _MechHistoryScreenState extends State<MechHistoryScreen> {
  _HistFilter _filter = _HistFilter.all;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser?.userId;
    if (me == null) return const SizedBox.shrink();
    final moto = widget.motorcycleId == null ? null : app.motorcycleById(widget.motorcycleId!);
    var records = moto == null ? app.myServices : app.recordsFor(moto);
    records = switch (_filter) {
      _HistFilter.all => records,
      _HistFilter.byMe => records.where((r) => r.recordedByUserId == me).toList(),
      _HistFilter.byMechanic => records.where((r) => r.byMechanic && r.recordedByUserId != me).toList(),
    };
    return MechPage(
      header: MechHeader(moto == null ? 'Service History' : 'Maintenance History'),
      gap: 12,
      children: [
        if (moto != null) MotoPill(motoLine(app, moto)),
        if (moto != null)
          Wrap(spacing: 8, children: [
            for (final (f, label) in [(_HistFilter.all, 'All'), (_HistFilter.byMe, 'By me'), (_HistFilter.byMechanic, 'By mechanic')])
              Material(
                color: _filter == f ? MC.accent : MC.surface,
                shape: StadiumBorder(side: _filter == f ? BorderSide.none : const BorderSide(color: MC.border)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => setState(() => _filter = f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Text(label, style: mt(12, mBold, _filter == f ? Colors.white : MC.text)),
                  ),
                ),
              ),
          ]),
        if (records.isEmpty)
          MechCard(
            child: Text(
              moto == null ? 'You have not recorded any service yet.' : 'No maintenance records for this filter.',
              style: mt(13, mMedium, MC.muted),
            ),
          ),
        for (final r in records) _RecordCard(record: r, showPlate: moto == null),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.showPlate});

  final ServiceRecord record;
  final bool showPlate;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.motorcycleById(record.motorcycleId);
    final names = {if (m != null) for (final r in app.rulesFor(m)) r.componentKey: r.componentName};
    final who = record.recordedByName ?? record.workshopName ?? 'Owner';
    final by = recordedByText(record, app.currentUser?.userId).replaceFirst('Mechanic · ', '');
    return MechCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
        Row(children: [
          Expanded(child: Text(fmtDate(record.serviceDate), style: mt(14, mBold))),
          Text(fmtKm(record.odometerKm), style: mt(13, mBold, MC.accentText)),
        ]),
        if (showPlate && m != null) Text(motoLine(app, m), style: mt(12, mSemi, MC.muted)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in record.componentKeys)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: MC.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: MC.softBorder)),
              child: Text(names[k] ?? k, style: mt(11, mBold, MC.accentText)),
            ),
        ]),
        if (record.description.isNotEmpty) Text(record.description, style: mt(12, mMedium, MC.muted, 1.4)),
        Row(spacing: 8, children: [
          Avatar(initials(who), size: 28, fontSize: 10),
          Expanded(child: Text(by, overflow: TextOverflow.ellipsis, style: mt(12, mSemi))),
          if (record.receipt != null)
            PillButton('Receipt',
                icon: 'receipt',
                onTap: () => Navigator.of(context).push(_r(ReceiptDetailScreen(record: record)))),
        ]),
      ]),
    );
  }
}

// ====================================================================== Receipt Detail
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key, required this.record});

  final ServiceRecord record;

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late final Future<String?> _url = AppScope.read(context).backend.receiptUrl(widget.record.receipt!);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final r = widget.record;
    final receipt = r.receipt!;
    final m = app.motorcycleById(r.motorcycleId);
    final lines = [
      for (final k in r.componentKeys)
        (MockData.receiptLabels[k] ?? k, m == null ? 0 : MockData.samplePrice(app.catalogOf(m).motorcycleType, k)),
      if (r.byMechanic) ('Labor', MockData.labourFee),
    ];
    final total = lines.fold<int>(0, (a, l) => a + l.$2);
    final number = '#${(r.workshopName ?? 'MC').split(' ').map((w) => w[0]).join().toUpperCase()}-'
        '${r.serviceDate.year}-${r.serviceDate.month.toString().padLeft(2, '0')}${r.serviceDate.day.toString().padLeft(2, '0')}';
    return MechPage(
      header: const MechHeader('Receipt Detail'),
      bottom: [MechButton('Back to History', onTap: () => Navigator.of(context).maybePop())],
      children: [
        MechCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
            Row(spacing: 12, children: [
              const IconSquare('receipt'),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text(r.workshopName ?? 'Self-service', style: mt(16, mXBold)),
                  Text('Receipt $number', style: mt(12, mMedium, MC.muted)),
                ]),
              ),
            ]),
            const Divider(height: 1, color: MC.border),
            if (receipt.isSample) ...[
              for (final l in lines)
                Row(children: [
                  Expanded(child: Text(l.$1, style: mt(13, mMedium))),
                  Text(fmtRupiah(l.$2), style: mt(13, mBold)),
                ]),
              const Divider(height: 1, color: MC.border),
              Row(children: [
                Expanded(child: Text('Total', style: mt(14, mBold))),
                Text(fmtRupiah(total), style: mt(18, mXBold, MC.accentText)),
              ]),
            ] else if (receipt.localPath != null)
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(receipt.localPath!), fit: BoxFit.cover))
            else
              FutureBuilder<String?>(
                future: _url,
                builder: (_, snap) => snap.data == null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(receipt.fileName, textAlign: TextAlign.center, style: mt(13, mSemi, MC.muted)))
                    : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(snap.data!)),
              ),
          ]),
        ),
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(spacing: 10, children: [
            KV('Date', fmtDate(r.serviceDate)),
            KV('Odometer', fmtKm(r.odometerKm)),
            if (m != null) KV('Motorcycle', motoLine(app, m)),
            KV('Recorded by', r.recordedByName ?? r.workshopName ?? 'Owner'),
          ]),
        ),
      ],
    );
  }
}

// ====================================================================== Inspect & Repair
class InspectScreen extends StatefulWidget {
  const InspectScreen({super.key, required this.motorcycleId, this.preselect});

  final String motorcycleId;
  final String? preselect;

  @override
  State<InspectScreen> createState() => _InspectScreenState();
}

class _InspectScreenState extends State<InspectScreen> {
  late final Set<String> _selected;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    final m = app.motorcycleById(widget.motorcycleId)!;
    _selected = widget.preselect != null
        ? {widget.preselect!}
        : app.statusesFor(m).where((s) => s.status != MaintenanceStatus.onTrack).map((s) => s.rule.componentKey).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.motorcycleById(widget.motorcycleId)!;
    return MechPage(
      header: const MechHeader('Inspect & Repair'),
      gap: 12,
      bottom: [
        MechButton('Continue to Service Details', onTap: () {
          if (_selected.isEmpty) {
            setState(() => _showError = true);
            return;
          }
          final draft = ServiceDraft(motorcycle: m, components: {..._selected}, serviceDate: today(), odometerKm: m.currentOdometer);
          draft.description = _suggestDescription(app, m, draft.components);
          Navigator.of(context).push(_r(ServiceDetailsScreen(draft: draft)));
        }),
      ],
      children: [
        MotoPill(motoLine(app, m)),
        InfoBanner(_showError
            ? 'Select at least one component you inspected or repaired.'
            : 'Tap the checkbox to select the components you inspected or repaired.'),
        for (final s in app.statusesFor(m))
          MechCard(
            onTap: () => setState(() {
              _showError = false;
              _selected.contains(s.rule.componentKey)
                  ? _selected.remove(s.rule.componentKey)
                  : _selected.add(s.rule.componentKey);
            }),
            child: Row(spacing: 12, children: [
              _Checkbox(_selected.contains(s.rule.componentKey)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
                  Text(s.rule.componentName, style: mt(14, mBold)),
                  ProgressBar(math.max(s.kmPercent, s.timePercent) / 100, color: statusBar(s.status)),
                ]),
              ),
              StatusChip.status(s.status),
            ]),
          ),
      ],
    );
  }
}

String _suggestDescription(AppState app, Motorcycle m, Set<String> keys) {
  final parts = [for (final k in keys) defaultWorkDescription[k] ?? 'Serviced ${app.ruleFor(m, k).componentName}'];
  return parts.isEmpty ? '' : '${parts.join('. ')}.';
}

class _Checkbox extends StatelessWidget {
  const _Checkbox(this.on);

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? MC.accent : MC.surface,
          borderRadius: BorderRadius.circular(8),
          border: on ? null : Border.all(color: MC.border, width: 1.5),
        ),
        child: on ? const AppIcon('check', color: Colors.white, size: 14) : null,
      );
}

// ====================================================================== Service Details / Correct Details
class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({super.key, required this.draft, this.correcting = false});

  final ServiceDraft draft;

  /// True when the form is reopened to fix missing or invalid fields.
  final bool correcting;

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  late final ServiceDraft d = widget.draft;
  late final _km = TextEditingController(text: '${d.odometerKm}');
  late final _desc = TextEditingController(text: d.description);

  @override
  void dispose() {
    _km.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _store() {
    d.odometerKm = int.tryParse(_km.text) ?? 0;
    d.description = _desc.text;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: d.serviceDate,
      firstDate: dateOnly(AppScope.read(context).firstReadingOf(d.motorcycle).recordedAt),
      lastDate: today(),
    );
    if (picked != null) setState(() => d.serviceDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rules = app.rulesFor(d.motorcycle);
    final issues = widget.correcting ? serviceIssues(app, d) : const <String, String>{};
    return MechPage(
      header: MechHeader(widget.correcting ? 'Correct Details' : 'Service Details'),
      bottom: [
        MechButton(widget.correcting ? 'Save Corrections' : 'Continue', onTap: () {
          _store();
          if (widget.correcting) {
            if (serviceIssues(app, d).isNotEmpty) {
              setState(() {});
              return;
            }
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).push(_r(AttachReceiptScreen(draft: d)));
          }
        }),
      ],
      children: [
        if (widget.correcting) const InfoBanner('Review the details below and correct anything that is wrong.'),
        MechField(
          'Service Date',
          child: SelectBox(value: fmtDate(d.serviceDate), placeholder: 'Choose a date', icon: 'cal', onTap: _pickDate),
        ),
        MechField(
          'Odometer (km)',
          error: issues['odometer'],
          helper: 'Current record: ${fmtKm(d.motorcycle.currentOdometer)}. Value must be equal or higher.',
          child: MechInput(
            controller: _km,
            icon: 'gauge',
            digitsOnly: true,
            keyboardType: TextInputType.number,
            error: issues['odometer'] != null,
            onChanged: (_) {
              if (widget.correcting) setState(_store);
            },
          ),
        ),
        MechField(
          'Components Serviced',
          error: issues['components'],
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in rules)
              _ServiceChip(r.componentName, on: d.components.contains(r.componentKey), onTap: () {
                setState(() => d.components.contains(r.componentKey)
                    ? d.components.remove(r.componentKey)
                    : d.components.add(r.componentKey));
              }),
          ]),
        ),
        MechField(
          'Work Description',
          error: issues['description'],
          child: MechInput(
            controller: _desc,
            hint: 'What did you do?',
            maxLines: 5,
            minLines: 3,
            caps: TextCapitalization.sentences,
            error: issues['description'] != null,
            onChanged: (_) {
              if (widget.correcting) setState(_store);
            },
          ),
        ),
      ],
    );
  }
}

/// Missing or invalid fields of [d], as field → problem.
Map<String, String> serviceIssues(AppState app, ServiceDraft d) => {
      if (d.odometerKm < d.motorcycle.currentOdometer)
        'odometer': 'Must be at least ${fmtKm(d.motorcycle.currentOdometer)} (current record).'
      else if (d.odometerKm - d.motorcycle.currentOdometer > AppState.maxOdometerJump)
        'odometer': 'That jump looks too big. Check the number.',
      if (d.components.isEmpty) 'components': 'Select at least one component.',
      if (d.description.trim().length < 5) 'description': 'Describe the work done (at least 5 characters).',
    };

/// Selectable service chip (orange with a check when on).
class _ServiceChip extends StatelessWidget {
  const _ServiceChip(this.label, {required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? MC.accent : MC.surface,
        shape: StadiumBorder(side: on ? BorderSide.none : const BorderSide(color: MC.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
              if (on) const AppIcon('check', color: Colors.white, size: 12),
              Text(label, style: mt(12, mBold, on ? Colors.white : MC.text)),
            ]),
          ),
        ),
      );
}

// ====================================================================== Attach Receipt
class AttachReceiptScreen extends StatefulWidget {
  const AttachReceiptScreen({super.key, required this.draft});

  final ServiceDraft draft;

  @override
  State<AttachReceiptScreen> createState() => _AttachReceiptScreenState();
}

class _AttachReceiptScreenState extends State<AttachReceiptScreen> {
  String? _error;

  Future<bool> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (file == null) return false;
      final size = await file.length();
      final error = ServiceReceipt.validateFile(fileName: file.name, sizeBytes: size);
      if (error != null) {
        setState(() => _error = error);
        return false;
      }
      setState(() {
        _error = null;
        widget.draft.receipt = ServiceReceipt(fileName: file.name, localPath: file.path, sizeBytes: size);
      });
      return true;
    } catch (_) {
      setState(() => _error = source == ImageSource.camera
          ? 'Could not open the camera. Check the app permission.'
          : 'Could not open the gallery. Check the app permission.');
      return false;
    }
  }

  void _next() => Navigator.of(context).push(_r(ReviewServiceScreen(draft: widget.draft)));

  @override
  Widget build(BuildContext context) {
    final receipt = widget.draft.receipt;
    return MechPage(
      header: const MechHeader('Attach Receipt'),
      bottom: [
        MechButton(receipt == null ? 'Upload & Continue' : 'Continue', icon: 'upload', onTap: () async {
          if (receipt != null || await _pick(ImageSource.gallery)) _next();
        }),
        MechButton('Take Photo', icon: 'camera', kind: MechButtonKind.soft, onTap: () async {
          if (await _pick(ImageSource.camera)) _next();
        }),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() => widget.draft.receipt = null);
              _next();
            },
            child: Text('Skip for now', style: mt(14, mBold, MC.muted)),
          ),
        ),
      ],
      children: [
        Text('Optional. Attach a photo of the service receipt so the owner can see the cost details.',
            style: mt(13, mMedium, MC.muted, 1.45)),
        if (receipt == null)
          Material(
            color: MC.soft,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18), side: const BorderSide(color: MC.accent, width: 1.5)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _pick(ImageSource.gallery),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(spacing: 10, children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle, border: Border.all(color: MC.softBorder)),
                    child: const AppIcon('upload', color: MC.accentText, size: 24),
                  ),
                  Text('Tap to upload receipt', style: mt(15, mBold)),
                  Text('JPG, PNG, WEBP or HEIC · max 5 MB', style: mt(12, mMedium, MC.muted)),
                ]),
              ),
            ),
          )
        else
          MechCard(
            child: Row(spacing: 12, children: [
              const IconSquare('image'),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text(receipt.fileName, overflow: TextOverflow.ellipsis, style: mt(14, mBold)),
                  Text('${(receipt.sizeBytes / 1048576).toStringAsFixed(1)} MB · Attached', style: mt(12, mMedium, MC.muted)),
                ]),
              ),
              IconButton(
                tooltip: 'Remove receipt',
                onPressed: () => setState(() => widget.draft.receipt = null),
                icon: const AppIcon('x', color: MC.muted, size: 18),
              ),
            ]),
          ),
        if (_error != null) InfoBanner(_error!, danger: true),
        const InfoBanner('Receipts are visible to the owner in their maintenance history.', icon: 'info'),
      ],
    );
  }
}

// ====================================================================== Review Service
class ReviewServiceScreen extends StatefulWidget {
  const ReviewServiceScreen({super.key, required this.draft});

  final ServiceDraft draft;

  @override
  State<ReviewServiceScreen> createState() => _ReviewServiceScreenState();
}

class _ReviewServiceScreenState extends State<ReviewServiceScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _edit() async {
    await Navigator.of(context).push(_r(ServiceDetailsScreen(draft: widget.draft, correcting: true)));
    if (mounted) setState(() {});
  }

  Future<void> _save(AppState app) async {
    final d = widget.draft;
    if (serviceIssues(app, d).isNotEmpty) return _edit();
    setState(() {
      _busy = true;
      _error = null;
    });
    final (record, err) = await app.saveService(d);
    if (!mounted) return;
    setState(() => _busy = false);
    if (record == null) {
      setState(() => _error = err);
      return;
    }
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst || r.settings.name == '/home');
    nav.push(_r(ServiceSavedScreen(record: record, notified: d.notifyOwner)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = widget.draft;
    final m = d.motorcycle;
    final names = {for (final r in app.rulesFor(m)) r.componentKey: r.componentName};
    final owner = app.ownerOf(m)?.fullName ?? 'the owner';
    return MechPage(
      header: const MechHeader('Review Service'),
      gap: 12,
      bottom: [
        if (_error != null) InfoBanner(_error!, danger: true),
        MechButton('Save Service Record', busy: _busy, onTap: () => _save(app)),
        MechButton('Edit Details', kind: MechButtonKind.soft, onTap: _edit),
      ],
      children: [
        MotoPill(motoLine(app, m)),
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
            KV('Service Date', fmtDate(d.serviceDate)),
            KV('Odometer', fmtKm(d.odometerKm), valueColor: MC.accentText),
            Text('Components Serviced', style: mt(12, mMedium, MC.muted)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in d.components)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: MC.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: MC.softBorder)),
                  child: Text(names[k] ?? k, style: mt(11, mBold, MC.accentText)),
                ),
              if (d.components.isEmpty) Text('None selected', style: mt(12, mSemi, MC.danger)),
            ]),
            Text('Work Description', style: mt(12, mMedium, MC.muted)),
            Text(d.description.trim().isEmpty ? '—' : d.description.trim(), style: mt(13, mSemi, MC.text, 1.4)),
          ]),
        ),
        MechCard(
          onTap: d.receipt == null ? () => Navigator.of(context).pop() : null,
          child: Row(spacing: 12, children: [
            const IconSquare('receipt'),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text(d.receipt?.fileName ?? 'No receipt', overflow: TextOverflow.ellipsis, style: mt(14, mBold)),
                Text(
                    d.receipt == null
                        ? 'Skipped · tap to attach'
                        : '${(d.receipt!.sizeBytes / 1048576).toStringAsFixed(1)} MB · Attached',
                    style: mt(12, mMedium, MC.muted)),
              ]),
            ),
            d.receipt == null
                ? const StatusChip('Skipped', bg: MC.warnBg, fg: MC.warn)
                : StatusChip.ok('Ready'),
          ]),
        ),
        MechCard(
          child: Row(spacing: 12, children: [
            const IconSquare('bell'),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text('Notify owner', style: mt(14, mBold)),
                Text("Update $owner's reminders right away", style: mt(12, mMedium, MC.muted)),
              ]),
            ),
            Switch(
              value: d.notifyOwner,
              activeTrackColor: MC.accent,
              onChanged: (v) => setState(() => d.notifyOwner = v),
            ),
          ]),
        ),
      ],
    );
  }
}

// ====================================================================== Service Saved
class ServiceSavedScreen extends StatelessWidget {
  const ServiceSavedScreen({super.key, required this.record, required this.notified});

  final ServiceRecord record;
  final bool notified;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.motorcycleById(record.motorcycleId)!;
    final first = app.rulesFor(m).where((r) => record.covers(r.componentKey)).firstOrNull;
    final next = first == null ? null : app.statusOf(m, first);
    return MechPage(
      bottom: [
        MechButton('Back to Dashboard', onTap: () => backToDashboard(context)),
        MechButton('View Maintenance History',
            kind: MechButtonKind.soft,
            onTap: () => Navigator.of(context).pushReplacement(_r(MechHistoryScreen(motorcycleId: m.motorcycleId)))),
      ],
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: MC.okBg, shape: BoxShape.circle),
            child: const AppIcon('check', color: MC.ok, size: 56),
          ),
        ),
        Text('Service Record Saved', textAlign: TextAlign.center, style: mt(24, mXBold)),
        Text(
          'Maintenance history for ${m.plateNumber} has been updated'
          '${notified ? " and the owner's reminders were updated" : ''}.',
          textAlign: TextAlign.center,
          style: mt(13, mMedium, MC.muted, 1.45),
        ),
        if (first != null && next != null)
          MechRow(
            icon: 'bell',
            title: 'Next ${first.componentName.toLowerCase()} service',
            subtitle: 'Reminder set for ${fmtKm(next.nextKm)} or ${fmtDate(next.nextDate)}',
          ),
      ],
    );
  }
}

// ====================================================================== Add Motorcycle
class AddMotorcycleScreen extends StatefulWidget {
  const AddMotorcycleScreen({super.key, this.plate});

  final String? plate;

  @override
  State<AddMotorcycleScreen> createState() => _AddMotorcycleScreenState();
}

class _AddMotorcycleScreenState extends State<AddMotorcycleScreen> {
  UserAccount? _owner;
  MotorcycleType? _type;
  String? _make, _model;
  int? _year;
  late final _plate = TextEditingController(text: widget.plate ?? '');
  final _km = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _plate.dispose();
    _km.dispose();
    super.dispose();
  }

  Iterable<MotorcycleCatalog> _models(AppState app) => app.catalog.where((c) =>
      (_type == null || c.motorcycleType == _type) && (_make == null || c.make == _make) && (_model == null || c.model == _model));

  Future<T?> _pick<T>(String title, List<(T, String, String?)> options) => showMechSheet<T>(context,
      title: title,
      children: (sheet) => [
            if (options.isEmpty) Text('No options in the catalog.', style: mt(13, mMedium, MC.muted)),
            for (final (value, label, sub) in options)
              SheetOption(label, subtitle: sub, onTap: () => Navigator.of(sheet).pop(value)),
          ]);

  Future<void> _save(AppState app) async {
    final cat = _models(app).where((c) => c.modelYear == _year).firstOrNull;
    final km = int.tryParse(_km.text);
    setState(() => _errors = {
          if (_owner == null) 'owner': 'Choose the owner.',
          if (_type == null) 'type': 'Choose the motorcycle type.',
          if (_make == null) 'make': 'Choose the make.',
          if (_model == null) 'model': 'Choose the model.',
          if (_year == null || cat == null) 'year': 'Choose the model year.',
          if (km == null) 'km': 'Enter the odometer.',
          if (AppState.validatePlate(_plate.text) case final e?) 'plate': e,
        });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    final plate = AppState.normalizePlate(_plate.text);
    final err = await app.addMotorcycle(catalogId: cat!.catalogId, plateNumber: plate, odometerKm: km!, ownerId: _owner!.userId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errors = {'plate': err});
      return;
    }
    final m = app.findByPlate(plate)!;
    Navigator.of(context).pushReplacement(_r(MotorcycleAddedScreen(motorcycleId: m.motorcycleId)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final catalog = app.catalog;
    final types = {for (final c in catalog) c.motorcycleType}.toList();
    final makes = {for (final c in catalog.where((c) => c.motorcycleType == _type)) c.make}.toList()..sort();
    final models = {for (final c in catalog.where((c) => c.motorcycleType == _type && c.make == _make)) c.model}.toList()..sort();
    final years = [for (final c in _models(app)) c.modelYear]..sort();
    return MechPage(
      header: const MechHeader('Add Motorcycle'),
      bottom: [MechButton('Save Motorcycle', busy: _busy, onTap: () => _save(app))],
      children: [
        const InfoBanner('Registering a motorcycle for a customer. Type, make, model and year options come from the '
            'Motorcycle Catalog managed by Admin.', icon: 'info'),
        MechField('Owner',
            error: _errors['owner'],
            child: SelectBox(
              value: _owner?.fullName,
              placeholder: 'Select owner',
              icon: 'user',
              error: _errors['owner'] != null,
              onTap: () async {
                final o = await _pick('Select Owner', [for (final u in app.owners) (u, u.fullName, 'Registered customer')]);
                if (o != null) setState(() => _owner = o);
              },
            )),
        MechField('Motorcycle Type',
            error: _errors['type'],
            child: SelectBox(
              value: _type?.label,
              placeholder: 'Select type',
              error: _errors['type'] != null,
              onTap: () async {
                final t = await _pick('Motorcycle Type', [for (final t in types) (t, t.label, null)]);
                if (t != null && t != _type) {
                  setState(() {
                    _type = t;
                    _make = null;
                    _model = null;
                    _year = null;
                  });
                }
              },
            )),
        Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
          Expanded(
            child: MechField('Make',
                error: _errors['make'],
                child: SelectBox(
                  value: _make,
                  placeholder: 'Make',
                  enabled: _type != null,
                  error: _errors['make'] != null,
                  onTap: () async {
                    final mk = await _pick('Select Make', [
                      for (final mk in makes)
                        (mk, mk, '${catalog.where((c) => c.make == mk && c.motorcycleType == _type).length} models'),
                    ]);
                    if (mk != null && mk != _make) {
                      setState(() {
                        _make = mk;
                        _model = null;
                        _year = null;
                      });
                    }
                  },
                )),
          ),
          Expanded(
            child: MechField('Model',
                error: _errors['model'],
                child: SelectBox(
                  value: _model,
                  placeholder: 'Model',
                  enabled: _make != null,
                  error: _errors['model'] != null,
                  onTap: () async {
                    final md = await _pick('$_make Models', [for (final md in models) (md, md, null)]);
                    if (md != null) {
                      setState(() {
                        _model = md;
                        final ys = [for (final c in _models(app)) c.modelYear];
                        _year = ys.length == 1 ? ys.first : null;
                      });
                    }
                  },
                )),
          ),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
          Expanded(
            child: MechField('Model Year',
                error: _errors['year'],
                child: SelectBox(
                  value: _year?.toString(),
                  placeholder: 'Year',
                  enabled: _model != null,
                  error: _errors['year'] != null,
                  onTap: () async {
                    final y = await _pick('Model Year', [for (final y in years) (y, '$y', null)]);
                    if (y != null) setState(() => _year = y);
                  },
                )),
          ),
          Expanded(
            child: MechField('Odometer (km)',
                error: _errors['km'],
                child: MechInput(
                  controller: _km,
                  hint: '0',
                  digitsOnly: true,
                  keyboardType: TextInputType.number,
                  error: _errors['km'] != null,
                )),
          ),
        ]),
        MechField('Plate Number',
            error: _errors['plate'],
            helper: 'Used by mechanics to find the motorcycle. Must be unique.',
            child: MechInput(
              controller: _plate,
              icon: 'plate',
              hint: 'B 9999 ZZZ',
              caps: TextCapitalization.characters,
              error: _errors['plate'] != null,
            )),
      ],
    );
  }
}

// ====================================================================== Motorcycle Added
class MotorcycleAddedScreen extends StatelessWidget {
  const MotorcycleAddedScreen({super.key, required this.motorcycleId});

  final String motorcycleId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.motorcycleById(motorcycleId)!;
    final cat = app.catalogOf(m);
    return MechPage(
      bottom: [
        MechButton('Start Inspection', icon: 'wrench', onTap: () async {
          await app.startJob(m, 'Routine check');
          if (context.mounted) Navigator.of(context).pushReplacement(_r(InspectScreen(motorcycleId: m.motorcycleId)));
        }),
        MechButton('Back to Dashboard', kind: MechButtonKind.soft, onTap: () => backToDashboard(context)),
      ],
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: MC.okBg, shape: BoxShape.circle),
            child: const AppIcon('check', color: MC.ok, size: 48),
          ),
        ),
        Text('Motorcycle Added', textAlign: TextAlign.center, style: mt(24, mXBold)),
        Text('The motorcycle is now registered in MotorcycleCare and visible in the owner’s garage.',
            textAlign: TextAlign.center, style: mt(13, mMedium, MC.muted, 1.45)),
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(spacing: 10, children: [
            KV('Plate Number', m.plateNumber, valueColor: MC.accentText),
            KV('Owner', app.ownerOf(m)?.fullName ?? '—'),
            KV('Type', cat.motorcycleType.label),
            KV('Make', cat.make),
            KV('Model', cat.model),
            KV('Model Year', '${cat.modelYear}'),
            KV('Odometer', fmtKm(m.currentOdometer)),
          ]),
        ),
      ],
    );
  }
}
