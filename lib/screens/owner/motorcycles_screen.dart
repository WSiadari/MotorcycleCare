import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'add_motorcycle_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

/// The owner's motorcycles, or an empty state with Add Motorcycle.
class MotorcyclesScreen extends StatelessWidget {
  const MotorcyclesScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const MotorcyclesScreen(),
        settings: const RouteSettings(name: '/motorcycles'),
      );

  void _open(BuildContext context, Motorcycle m) {
    AppScope.read(context).selectMotorcycle(m.motorcycleId);
    Navigator.of(context).push(DashboardScreen.route());
  }

  void _add(BuildContext context) => Navigator.of(context).push(AddMotorcycleScreen.route());

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final motos = app.myMotorcycles;

    Future<void> refresh() async {
      final err = await app.refresh();
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }

    if (motos.isEmpty) {
      return AppPage(onRefresh: refresh, children: [
        TopBar('My Motorcycles', back: false, actions: [
          SquareButton('user', tooltip: 'Profile & settings', onTap: () => Navigator.of(context).push(OwnerProfileScreen.route())),
        ]),
        CardBox(
          radius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(spacing: 10, children: [
            const IconBox('bike', size: 64, radius: 20, iconSize: 30),
            Text('No motorcycle yet', style: ts(17, bold)),
            Text('Add the motorcycle you ride to start tracking its components and service schedule.',
                textAlign: TextAlign.center, style: ts(13, regular, AppColors.muted, 1.45)),
          ]),
        ),
        AppButton('Add Motorcycle', onPressed: () => _add(context)),
      ]);
    }

    return AppPage(onRefresh: refresh, children: [
      TopBar('My Motorcycles', back: false, actions: [
          SquareButton('user', tooltip: 'Profile & settings', onTap: () => Navigator.of(context).push(OwnerProfileScreen.route())),
        ]),
      Text('Select a motorcycle to open its dashboard, or add a new one.',
          style: ts(14, regular, AppColors.muted, 1.43)),
      for (final m in motos)
        CardBox(
          onTap: () => _open(context, m),
          child: Row(spacing: 12, children: [
            const IconBox('bike', size: 44, radius: 12, iconSize: 22),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text(app.catalogOf(m).name, style: ts(15, semiBold)),
                Text('${m.plateNumber} · ${fmtKm(m.currentOdometer)}', style: ts(12, regular, AppColors.muted)),
              ]),
            ),
            StatusBadge(app.worstStatus(m)),
            const AppIcon('chevR', color: AppColors.muted, size: 16),
          ]),
        ),
      AppButton('Add Motorcycle', kind: ButtonKind.ghost, onPressed: () => _add(context)),
      const Note('Motorcycle types come from the catalog managed by Admin.'),
    ]);
  }
}
