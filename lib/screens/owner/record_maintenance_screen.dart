import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'component_status_screen.dart';
import 'maintenance_saved_screen.dart';

/// 07a · Record Maintenance → Attach service receipt? (skip / attach) → Save Maintenance Record
class RecordMaintenanceScreen extends StatefulWidget {
  const RecordMaintenanceScreen({super.key, this.preselected = const {}});

  final Set<String> preselected;

  static Route<void> route(Set<String> preselected) => MaterialPageRoute(
        builder: (_) => RecordMaintenanceScreen(preselected: preselected),
        settings: const RouteSettings(name: '/record'),
      );

  @override
  State<RecordMaintenanceScreen> createState() => _RecordMaintenanceScreenState();
}

class _RecordMaintenanceScreenState extends State<RecordMaintenanceScreen> {
  late final Set<String> _items = {...widget.preselected};
  DateTime _date = today();
  late final TextEditingController _km;
  final _workshop = TextEditingController();
  late final TextEditingController _desc;
  bool _descEdited = false;
  bool _byMechanic = true;
  Receipt? _receipt;
  bool _busy = false;
  String? _itemsError, _kmError, _workshopError, _fileError, _saveError;

  @override
  void initState() {
    super.initState();
    final moto = AppScope.read(context).selected!;
    _km = TextEditingController(text: '${moto.odometer}');
    _desc = TextEditingController(text: _autoDescription());
  }

  @override
  void dispose() {
    _km.dispose();
    _workshop.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _autoDescription() => _items.length == 1 ? (defaultWorkDescription[_items.first] ?? '') : '';

  void _toggle(String key) => setState(() {
        _items.contains(key) ? _items.remove(key) : _items.add(key);
        _itemsError = null;
        if (!_descEdited) _desc.text = _autoDescription();
      });

  Future<void> _pickDate(Motorcycle moto) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: moto.registeredAt,
      lastDate: today(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        setState(() => _fileError = 'File is larger than 5 MB. Choose a smaller photo.');
        return;
      }
      setState(() {
        _fileError = null;
        _receipt = Receipt(name: file.name, path: file.path, sizeBytes: size);
      });
    } catch (_) {
      setState(() => _fileError = 'Could not open the gallery. Check the app permission.');
    }
  }

  Future<void> _save(AppState app, Motorcycle moto, List<MaintenanceRule> rules) async {
    if (_busy) return;
    final km = int.tryParse(_km.text);
    final minKm = app.minServiceOdometer(moto, _items);
    setState(() {
      _saveError = null;
      _itemsError = _items.isEmpty ? 'Pick at least one component.' : null;
      _kmError = km == null
          ? 'Enter the odometer at the time of service.'
          : km < minKm
              ? 'Must be at least ${fmtKm(minKm)} (${_minReason(rules)}).'
              : km > moto.odometer + AppState.maxOdometerJump
                  ? 'That number looks too high.'
                  : null;
      _workshopError = _byMechanic && _workshop.text.trim().isEmpty ? 'Enter the workshop name.' : null;
    });
    if (_itemsError != null || _kmError != null || _workshopError != null) return;

    final typed = _desc.text.trim();
    final items = {
      for (final r in rules)
        if (_items.contains(r.componentKey))
          r.componentKey: (_descEdited && typed.isNotEmpty)
              ? typed
              : (_items.length == 1 && typed.isNotEmpty ? typed : (defaultWorkDescription[r.componentKey] ?? 'Serviced')),
    };
    setState(() => _busy = true);
    final (record, err) = await app.saveRecord(
      motorcycle: moto,
      date: _date,
      odometer: km!,
      items: items,
      workshop: _byMechanic ? _workshop.text : null,
      receipt: _receipt,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (record == null) {
      setState(() => _saveError = err);
      return;
    }
    Navigator.of(context).pushReplacement(MaintenanceSavedScreen.route(record));
  }

  String _minReason(List<MaintenanceRule> rules) {
    if (_items.length == 1) {
      final name = rules.firstWhere((r) => r.componentKey == _items.first).componentName.toLowerCase();
      return 'last $name service';
    }
    return 'last service of the selected parts';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected!;
    final rules = app.rulesFor(moto);
    final minKm = app.minServiceOdometer(moto, _items);

    return AppPage(children: [
      const TopBar('Record Maintenance'),
      VehicleChip(vehicleLine(app, moto)),
      // Components serviced
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Components serviced'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in rules) _SelectChip(r.componentName, on: _items.contains(r.componentKey), onTap: () => _toggle(r.componentKey)),
        ]),
        if (_itemsError != null) ErrorLine(_itemsError!) else const Helper('Pick every part done in this visit.'),
      ]),
      // Service date
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Service date'),
        InputBox(
          onTap: () => _pickDate(moto),
          child: Row(spacing: 10, children: [
            const AppIcon('cal', color: AppColors.muted, size: 16),
            Text(fmtDate(_date), style: ts(15, semiBold)),
          ]),
        ),
      ]),
      // Odometer at service
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Odometer at service'),
        AppInput(
          controller: _km,
          suffix: 'km',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          hasError: _kmError != null,
          onChanged: (_) => setState(() => _kmError = null),
        ),
        if (_kmError != null)
          ErrorLine(_kmError!)
        else
          Helper(_items.isEmpty
              ? 'At least ${fmtKm(minKm)} (odometer at registration).'
              : 'At least ${fmtKm(minKm)} (${_minReason(rules)}).'),
      ]),
      // Performed By Field
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Performed by'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(12)),
          child: Row(spacing: 4, children: [
            Expanded(child: _Segment('Myself', on: !_byMechanic, onTap: () => setState(() => _byMechanic = false))),
            Expanded(
                child: _Segment('Mechanic / workshop', on: _byMechanic, onTap: () => setState(() => _byMechanic = true))),
          ]),
        ),
        if (_byMechanic) ...[
          const SizedBox(height: 8),
          const FieldLabel('Workshop name'),
          AppInput(
            controller: _workshop,
            icon: 'wrench',
            hint: 'e.g. AHASS Sudirman',
            textCapitalization: TextCapitalization.words,
            hasError: _workshopError != null,
            onChanged: (_) => setState(() => _workshopError = null),
          ),
          if (_workshopError != null) ErrorLine(_workshopError!),
        ] else
          const Helper('Logged as self-service. No workshop needed.'),
      ]),
      // Work description
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Work description'),
        AppInput(
          controller: _desc,
          hint: 'e.g. Replaced gear oil (120 ml)',
          minLines: 2,
          maxLines: 4,
          fontWeight: medium,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _descEdited = true,
        ),
      ]),
      // Receipt Field
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Service receipt (optional)'),
        if (_receipt != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(spacing: 10, children: [
              const AppIcon('check', color: AppColors.successIcon, size: 16),
              Expanded(
                child: Text('${_receipt!.name} · ${(_receipt!.sizeBytes / 1048576).toStringAsFixed(1)} MB',
                    overflow: TextOverflow.ellipsis, style: ts(13, semiBold, AppColors.successText)),
              ),
              IconButton(
                tooltip: 'Remove receipt',
                onPressed: () => setState(() => _receipt = null),
                icon: const AppIcon('x', color: AppColors.successText, size: 16),
              ),
            ]),
          )
        else
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.accent, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickReceipt,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(spacing: 4, children: [
                  const AppIcon('upload', color: AppColors.accent, size: 22),
                  Text('Attach receipt', style: ts(14, semiBold, AppColors.accentStrong)),
                  Text('JPG or PNG photo, up to 5 MB', style: ts(12, regular, AppColors.muted)),
                ]),
              ),
            ),
          ),
        if (_fileError != null)
          ErrorLine(_fileError!)
        else
          Helper(_receipt != null
              ? 'Receipt attached. Tap X to remove it.'
              : 'You can skip this and attach the receipt later.'),
      ]),
      if (_saveError != null) ErrorBanner(_saveError!),
      AppButton('Save Maintenance Record', busy: _busy, onPressed: () => _save(app, moto, rules)),
    ]);
  }
}

/// "Select Chip" (State=Off / State=On)
class _SelectChip extends StatelessWidget {
  const _SelectChip(this.label, {required this.on, required this.onTap});

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 5, children: [
              if (on) const AppIcon('check', color: Colors.white, size: 12),
              Text(label, style: ts(12, semiBold, on ? Colors.white : AppColors.text)),
            ]),
          ),
        ),
      );
}

class _Segment extends StatelessWidget {
  const _Segment(this.label, {required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(label, style: ts(13, semiBold, on ? AppColors.accentStrong : AppColors.muted)),
            ),
          ),
        ),
      );
}
