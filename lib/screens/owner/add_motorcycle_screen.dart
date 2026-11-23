import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'dashboard_screen.dart';

/// B2 · Add Motorcycle → Motorcycle valid? → Save Motorcycle → Motorcycle Dashboard
class AddMotorcycleScreen extends StatefulWidget {
  const AddMotorcycleScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const AddMotorcycleScreen(),
        settings: const RouteSettings(name: '/add-motorcycle'),
      );

  @override
  State<AddMotorcycleScreen> createState() => _AddMotorcycleScreenState();
}

class _AddMotorcycleScreenState extends State<AddMotorcycleScreen> {
  final _plate = TextEditingController();
  final _odo = TextEditingController(text: '0');
  String? _catalogId;
  bool _pickerOpen = false;
  bool _busy = false;
  String? _modelError, _plateError, _odoError, _error;
  Motorcycle? _saved;

  @override
  void dispose() {
    _plate.dispose();
    _odo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final odo = int.tryParse(_odo.text);
    setState(() {
      _error = null;
      _modelError = _catalogId == null ? 'Choose your motorcycle from the catalog.' : null;
      _plateError = AppState.validatePlate(_plate.text);
      _odoError = odo == null ? 'Enter the odometer reading in km.' : (odo > 500000 ? 'That number looks too high.' : null);
    });
    if (_modelError != null || _plateError != null || _odoError != null) return; // Show motorcycle error
    setState(() => _busy = true);
    final app = AppScope.read(context);
    final err = await app.addMotorcycle(catalogId: _catalogId!, plate: _plate.text, odometer: odo!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() {
        if (err.contains('already registered')) {
          _plateError = err;
        } else {
          _error = err;
        }
      });
      return;
    }
    setState(() => _saved = app.selected);
  }

  void _reset() => setState(() {
        _saved = null;
        _catalogId = null;
        _plate.clear();
        _odo.text = '0';
      });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final catalog = app.catalog;
    final selected = catalog.where((c) => c.id == _catalogId).firstOrNull;

    if (_saved != null) {
      final m = _saved!;
      final cat = app.catalogOf(m);
      return AppPage(children: [
        const TopBar('Add Motorcycle'),
        Text('Register a motorcycle to start tracking its maintenance.',
            style: ts(14, regular, AppColors.muted, 1.43)),
        CardBox(
          radius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
            const IconBox('check', size: 48, radius: 24, iconSize: 24, bg: AppColors.successSoft, color: AppColors.successIcon),
            Text('${cat.name} saved', style: ts(18, bold)),
            Text(
              'Plate ${m.plate} · ${fmtKm(m.odometer)}. Its maintenance schedule was created from the Admin rules '
              'for the ${cat.model} (${cat.type.label}).',
              style: ts(13, regular, AppColors.muted, 1.45),
            ),
          ]),
        ),
        AppButton('Done', onPressed: () => Navigator.of(context).pushReplacement(DashboardScreen.route())),
        AppButton('Add another motorcycle', kind: ButtonKind.secondary, onPressed: _reset),
      ]);
    }

    return AppPage(children: [
      const TopBar('Add Motorcycle'),
      Text('Register a motorcycle to start tracking its maintenance.', style: ts(14, regular, AppColors.muted, 1.43)),
      if (_error != null) ErrorBanner(_error!),
      // Field / Motorcycle (from catalog)
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Motorcycle (from catalog)'),
        InputBox(
          focused: _pickerOpen,
          hasError: _modelError != null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          onTap: () => setState(() => _pickerOpen = !_pickerOpen),
          child: Row(spacing: 10, children: [
            const AppIcon('bike', color: AppColors.accent, size: 18),
            Expanded(
              child: selected == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Choose your motorcycle', style: ts(15, regular, AppColors.muted)),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                      Text(selected.name, style: ts(15, semiBold)),
                      Text('${selected.type.label} · ${selected.year}', style: ts(12, regular, AppColors.muted)),
                    ]),
            ),
            AppIcon(_pickerOpen ? 'chevU' : 'chevD', color: AppColors.muted, size: 16),
          ]),
        ),
        if (_pickerOpen)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(spacing: 2, children: [
              for (final c in catalog)
                Material(
                  color: c.id == _catalogId ? AppColors.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _catalogId = c.id;
                      _pickerOpen = false;
                      _modelError = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: Row(spacing: 10, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                            Text(c.name,
                                style: ts(14, semiBold, c.id == _catalogId ? AppColors.accentStrong : AppColors.text)),
                            Text('${c.type.label} · ${c.year}', style: ts(12, regular, AppColors.muted)),
                          ]),
                        ),
                        if (c.id == _catalogId) const AppIcon('check', color: AppColors.accent, size: 16),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        if (_modelError != null)
          ErrorLine(_modelError!)
        else
          Helper(_pickerOpen
              ? 'Catalog is managed by Admin. Pick type, make, model and year.'
              : 'Tap to choose from the Admin catalog.'),
      ]),
      if (selected != null)
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
            Text('Filled from catalog', style: ts(12, semiBold, AppColors.muted)),
            InfoRow('Type', selected.type.label),
            InfoRow('Make', selected.make),
            InfoRow('Model', selected.model),
            InfoRow('Year', '${selected.year}'),
          ]),
        ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Plate number'),
        AppInput(
          controller: _plate,
          icon: 'plate',
          hint: 'e.g. B 4521 KXR',
          textCapitalization: TextCapitalization.characters,
          hasError: _plateError != null,
          onChanged: (_) => setState(() => _plateError = null),
        ),
        if (_plateError != null)
          ErrorLine(_plateError!.contains('already registered')
              ? _plateError!
              : 'Use a valid plate format, for example B 4521 KXR.')
        else
          const Helper('Write it as shown on the plate.'),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Current odometer'),
        AppInput(
          controller: _odo,
          icon: 'gauge',
          suffix: 'km',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          hasError: _odoError != null,
          onChanged: (_) => setState(() => _odoError = null),
        ),
        if (_odoError != null) ErrorLine(_odoError!) else const Helper('Reading on the day you register the motorcycle.'),
      ]),
      AppButton('Save Motorcycle', busy: _busy, onPressed: _save),
    ]);
  }
}
