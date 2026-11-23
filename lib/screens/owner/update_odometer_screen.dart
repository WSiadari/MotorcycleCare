import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'component_status_screen.dart';
import 'sheets.dart';

/// 02 · Update Odometer → Odometer valid? → 02b Confirm (Save) / 02c Confirm (Use Latest)
class UpdateOdometerScreen extends StatefulWidget {
  const UpdateOdometerScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const UpdateOdometerScreen(),
        settings: const RouteSettings(name: '/odometer'),
      );

  @override
  State<UpdateOdometerScreen> createState() => _UpdateOdometerScreenState();
}

class _UpdateOdometerScreenState extends State<UpdateOdometerScreen> {
  late final TextEditingController _ctrl;
  bool _busy = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${AppScope.read(context).selected!.odometer}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppState app, int value) async {
    final moto = app.selected!;
    final ok = await confirmOdometerSheet(context,
        km: value, message: 'All component statuses will be recalculated with the Admin maintenance rules.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await app.updateOdometer(moto, value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _serverError = err);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Odometer saved: ${fmtKm(value)}.')));
    Navigator.of(context).pop();
  }

  Future<void> _useLatest(AppState app) async {
    final moto = app.selected!;
    final ok = await confirmOdometerSheet(context,
        km: moto.odometer,
        message: 'Keep the latest reading from ${fmtDate(moto.odometerUpdatedAt)} and refresh the maintenance schedule.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await app.confirmOdometer(moto);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _serverError = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final moto = app.selected!;
    final value = int.tryParse(_ctrl.text);
    final error = app.validateOdometer(moto, value);

    return AppPage(children: [
      const TopBar('Update Odometer'),
      VehicleChip(vehicleLine(app, moto)),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
          Text('Latest odometer', style: ts(13, regular, AppColors.muted)),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, spacing: 6, children: [
            Text(fmtNum(moto.odometer), style: ts(26, bold)),
            Text('km', style: ts(14, medium, AppColors.muted)),
          ]),
          Text('Updated ${fmtDate(moto.odometerUpdatedAt)} · by you', style: ts(12, regular, AppColors.muted)),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('New odometer reading'),
        AppInput(
          controller: _ctrl,
          suffix: 'km',
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          hasError: error != null,
          onChanged: (_) => setState(() => _serverError = null),
        ),
        if (error != null)
          ErrorLine(value != null && value < moto.odometer
              ? "Can't be lower than the latest reading (${fmtKm(moto.odometer)})."
              : error)
        else if (_serverError != null)
          ErrorLine(_serverError!)
        else
          Helper('Must be equal to or higher than ${fmtKm(moto.odometer)}.'),
      ]),
      const Note('Saving recalculates every component status using the Admin maintenance rules (interval km & months).'),
      AppButton('Save Odometer', busy: _busy, onPressed: error != null ? null : () => _save(app, value!)),
      AppButton('Use Latest Odometer (${fmtKm(moto.odometer)})',
          kind: ButtonKind.secondary, onPressed: _busy ? null : () => _useLatest(app)),
    ]);
  }
}
