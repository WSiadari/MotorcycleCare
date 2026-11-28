import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'sheets.dart';

/// Owner profile and settings: name, phone, reminder notifications and log out.
class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const OwnerProfileScreen(),
        settings: const RouteSettings(name: '/profile'),
      );

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  late final MotorcycleOwner _me = AppScope.read(context).currentUser! as MotorcycleOwner;
  late final _name = TextEditingController(text: _me.fullName);
  late final _phone = TextEditingController(text: _me.phone ?? '');
  bool _busy = false, _switching = false;
  String? _error, _nameError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _nameError = _name.text.trim().length < 3 ? 'Enter your full name.' : null;
    });
    if (_nameError != null) return;
    setState(() => _busy = true);
    final err = await AppScope.read(context).updateMyProfile(fullName: _name.text, phone: _phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    }
  }

  /// The switch is saved right away (motorcycle_owners.notification_enabled).
  Future<void> _setReminders(bool on) async {
    final app = AppScope.read(context);
    final me = app.currentUser!;
    setState(() => _switching = true);
    final err = await app.updateMyProfile(fullName: me.fullName, phone: me.phone, notificationEnabled: on);
    if (!mounted) return;
    setState(() {
      _switching = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser;
    if (me is! MotorcycleOwner) return const Scaffold(body: SizedBox.shrink()); // signed out
    final motos = app.myMotorcycles.length;
    return AppPage(children: [
      const TopBar('Profile & Settings'),
      CardBox(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(spacing: 14, children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: Text(initials(me.fullName), style: ts(20, bold, AppColors.accentStrong)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text(me.fullName, style: ts(17, bold)),
              Text(me.email, style: ts(13, regular, AppColors.muted)),
              Text(
                  '${UserRole.owner.label} · $motos motorcycle${motos == 1 ? '' : 's'}'
                  '${me.createdAt == null ? '' : ' · since ${fmtMonthYear(me.createdAt!)}'}',
                  style: ts(12, medium, AppColors.muted)),
            ]),
          ),
        ]),
      ),
      if (_error != null) ErrorBanner(_error!),
      const SectionHeader('Personal information'),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Full name'),
        AppInput(
          controller: _name,
          icon: 'user',
          textCapitalization: TextCapitalization.words,
          hasError: _nameError != null,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        if (_nameError != null) ErrorLine(_nameError!),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Phone'),
        AppInput(controller: _phone, icon: 'phone', hint: '+62 812-3456-7890', keyboardType: TextInputType.phone),
        const Helper('Optional. Your email is your login and can only be changed by the admin.'),
      ]),
      AppButton('Save Changes', busy: _busy, onPressed: _save),
      const SectionHeader('Notifications'),
      CardBox(
        child: Row(spacing: 12, children: [
          const IconBox('bell', size: 40, radius: 11, iconSize: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text('Maintenance reminders', style: ts(15, semiBold)),
              Text('Notify me on this phone when a component is due soon or overdue.',
                  style: ts(12, regular, AppColors.muted, 1.35)),
            ]),
          ),
          Switch(
            value: me.notificationEnabled,
            activeTrackColor: AppColors.accentStrong,
            onChanged: _switching ? null : _setReminders,
          ),
        ]),
      ),
      const Note('Reminders are always listed under the bell on the dashboard. This switch only turns the phone '
          'notifications on or off.'),
      AppButton('Log Out', kind: ButtonKind.danger, onPressed: () => showLogOut(context)),
    ]);
  }
}
