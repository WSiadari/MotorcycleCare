import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// "Every 2,000 km or 2 months"
String ruleSentence(MaintenanceRule r) => 'Every ${fmtKm(r.intervalKm)} or ${fmtMonths(r.intervalMonths)}';

Widget _field(String label, Widget input, {String? error, String? helper}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 7, children: [
      Text(label, style: ts(13, semiBold)),
      input,
      if (error != null) ErrorLine(error) else if (helper != null) Helper(helper),
    ]);

Widget _header(BuildContext context, String title, [String? subtitle]) => Row(spacing: 14, children: [
      SquareButton('chevL', iconSize: 20, tooltip: 'Back', onTap: () => Navigator.of(context).maybePop()),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 1, children: [
          Text(title, style: ts(22, bold)),
          if (subtitle != null) Text(subtitle, style: ts(12, medium, AppColors.muted)),
        ]),
      ),
    ]);

/// Select box that opens a list sheet.
Widget _select(BuildContext context,
    {required String? value, required String placeholder, required VoidCallback onTap, bool error = false, bool enabled = true}) {
  return Opacity(
    opacity: enabled ? 1 : 0.6,
    child: InputBox(
      hasError: error,
      onTap: enabled ? onTap : null,
      child: Row(children: [
        Expanded(
          child: Text(value ?? placeholder,
              style: ts(15, value == null ? regular : semiBold, value == null ? AppColors.muted : AppColors.text)),
        ),
        if (enabled) const AppIcon('chevD', color: AppColors.muted, size: 16),
      ]),
    ),
  );
}

Future<T?> _pick<T>(BuildContext context, String title, List<(T, String, String?)> options, T? current) =>
    showAppSheet<T>(context, title: title, gap: 8, children: (sheet) => [
          for (final (v, label, sub) in options)
            CardBox(
              radius: 14,
              borderColor: v == current ? AppColors.accentStrong : AppColors.border,
              borderWidth: v == current ? 1.5 : 1,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => Navigator.of(sheet).pop(v),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                    Text(label, style: ts(15, semiBold)),
                    if (sub != null) Text(sub, style: ts(12, regular, AppColors.muted)),
                  ]),
                ),
                if (v == current) const AppIcon('check', color: AppColors.accentStrong, size: 18),
              ]),
            ),
        ]);

Future<bool> _confirmDelete(BuildContext context, String title, String message, String button) async {
  final ok = await showAppSheet<bool>(context, title: title, gap: 14, children: (sheet) => [
        Text(message, style: ts(14, regular, AppColors.muted, 1.45)),
        AppButton(button, kind: ButtonKind.danger, onPressed: () => Navigator.of(sheet).pop(true)),
        AppButton('Cancel', kind: ButtonKind.secondary, onPressed: () => Navigator.of(sheet).pop(false)),
      ]);
  return ok ?? false;
}

// ====================================================================== Edit user · Add user
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user});

  /// Null when adding a new user.
  final UserAccount? user;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  late final UserAccount? u = widget.user;
  late final _name = TextEditingController(text: u?.fullName ?? '');
  late final _email = TextEditingController(text: u?.email ?? '');
  late final _workshop = TextEditingController(text: switch (u) { Mechanic(:final workshopName) => workshopName ?? '', _ => '' });
  final _password = TextEditingController();
  late UserRole? _role = u?.role;
  late bool _active = u?.active ?? true;
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final c in [_name, _email, _workshop, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final isNew = u == null;
    setState(() {
      _error = null;
      _errors = {
        if (_name.text.trim().length < 3) 'name': 'Enter the full name.',
        if (isNew)
          if (AppState.validateEmail(_email.text) case final e?) 'email': e,
        if (isNew && _password.text.length < 8) 'password': 'Use at least 8 characters.',
        if (_role == null) 'role': 'Choose a role to continue.',
        if (_role == UserRole.mechanic && _workshop.text.trim().isEmpty) 'workshop': 'Enter the workshop name.',
      };
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final String? err;
    if (isNew) {
      err = await app.addUser(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        role: _role!,
        workshopName: _role == UserRole.mechanic ? _workshop.text.trim() : null,
      );
    } else {
      final ws = _workshop.text.trim();
      final current = u;
      err = await app.saveUser(u!.copyWith(
        fullName: _name.text.trim(),
        role: _role,
        // a new workshop name is looked up (or created) by the backend
        workshop: _role == UserRole.mechanic && (current is! Mechanic || current.workshopName != ws)
            ? Workshop(workshopId: '', name: ws)
            : null,
        active: _active,
      ));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() {
        if (err!.contains('email')) {
          _errors = {'email': err};
        } else {
          _error = err;
        }
      });
      return;
    }
    adminSnack(context, isNew ? '${_name.text.trim()} added as ${_role!.label}' : 'Changes saved');
    nav.pop();
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final ok = await _confirmDelete(context, 'Delete user?',
        "${u!.fullName} (${u!.email}) will lose access to MotorcycleCare. This can't be undone.", 'Delete User');
    if (!ok || !mounted) return;
    final err = await app.deleteUser(u!);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    adminSnack(context, '${u!.fullName} deleted');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = u == null;
    final isMe = u?.userId == AppScope.of(context).currentUser?.userId;
    final preview = (u ?? const MotorcycleOwner(userId: '', fullName: '', email: ''))
        .copyWith(fullName: _name.text.isEmpty ? (u?.fullName ?? 'New user') : _name.text, role: _role ?? UserRole.owner);
    return AppPage(
      gap: 14,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _header(context, isNew ? 'Add user' : 'Edit user',
            isNew ? null : 'User ID · USR-${u!.userId.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')}'),
        if (isNew)
          Text('Create an account for an owner, mechanic or admin. Workshop or staff details can be completed after '
              'the account is created.', style: ts(14, regular, AppColors.muted, 1.45))
        else
          CardBox(
            radius: 18,
            child: Row(spacing: 14, children: [
              RoleAvatar(preview, size: 60, fontSize: 22),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                  Text(preview.fullName, style: ts(18, bold)),
                  Text(u!.email, style: ts(13, regular, AppColors.muted)),
                  Wrap(spacing: 6, runSpacing: 4, children: [Badge2.role(preview.role), Badge2.active(_active)]),
                  if (u case Admin(:final staffCode?))
                    Text('Registered with staff code $staffCode', style: ts(12, regular, AppColors.muted)),
                  if (u case MotorcycleOwner(:final notificationEnabled))
                    Text('Maintenance reminders ${notificationEnabled ? 'on' : 'off'}',
                        style: ts(12, regular, AppColors.muted)),
                ]),
              ),
            ]),
          ),
        if (_error != null) ErrorBanner(_error!),
        _field(
            'Full name',
            AppInput(
              controller: _name,
              icon: 'user',
              hint: 'e.g. Andi Wijaya',
              textCapitalization: TextCapitalization.words,
              hasError: _errors['name'] != null,
              onChanged: (_) => setState(() => _errors.remove('name')),
            ),
            error: _errors['name']),
        _field(
            'Email',
            isNew
                ? AppInput(
              controller: _email,
              icon: 'mail',
              hint: 'name@mail.com',
              keyboardType: TextInputType.emailAddress,
              hasError: _errors['email'] != null,
              onChanged: (_) => setState(() => _errors.remove('email')),
            )
                : InputBox(child: Text(u!.email, style: ts(15, semiBold, AppColors.muted))),
            error: _errors['email'],
            helper: isNew ? 'The user logs in with this email.' : "Email is the login name and can't be changed here."),
        if (isNew)
          _field(
              'Temporary password',
              AppInput(
                controller: _password,
                icon: 'lock',
                hasError: _errors['password'] != null,
                onChanged: (_) => setState(() => _errors.remove('password')),
              ),
              error: _errors['password'],
              helper: 'Share it with the user. At least 8 characters.'),
        _field(
          'Role',
          _select(
            context,
            value: _role?.label,
            placeholder: 'Choose a role',
            error: _errors['role'] != null,
            enabled: !isMe,
            onTap: () async {
              final r = await _pick(context, 'Choose a role', [
                (UserRole.owner, UserRole.owner.label, 'Owners manage their own motorcycles in the user app.'),
                (UserRole.mechanic, UserRole.mechanic.label, 'Mechanics record services for any motorcycle.'),
                (UserRole.admin, UserRole.admin.label, 'Admins manage users, the catalog and maintenance rules.'),
              ], _role);
              if (r != null) {
                setState(() {
                  _role = r;
                  _errors.remove('role');
                });
              }
            },
          ),
          error: _errors['role'],
          helper: isMe ? "You can't change your own role." : null,
        ),
        if (_role == UserRole.mechanic)
          _field(
              'Workshop name',
              AppInput(
                controller: _workshop,
                icon: 'wrench',
                hint: 'e.g. Maju Jaya Motor',
                textCapitalization: TextCapitalization.words,
                hasError: _errors['workshop'] != null,
                onChanged: (_) => setState(() => _errors.remove('workshop')),
              ),
              error: _errors['workshop']),
        if (!isNew) ...[
          CardBox(
            child: Row(spacing: 12, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text(_active ? 'Active account' : 'Inactive account', style: ts(15, semiBold)),
                  Text("Inactive users can't log in.", style: ts(12, regular, AppColors.muted)),
                ]),
              ),
              Switch(
                value: _active,
                activeTrackColor: AppColors.accentStrong,
                onChanged: isMe ? null : (v) => setState(() => _active = v),
              ),
            ]),
          ),
          const Note('Changing the role changes which dashboard this user sees after login.'),
        ],
        AppButton(isNew ? 'Add User' : 'Save Changes', busy: _busy, onPressed: _save),
        if (!isNew && !isMe) AppButton('Delete User', kind: ButtonKind.danger, onPressed: _delete),
      ],
    );
  }
}

// ====================================================================== Edit model · Add model
class ModelFormScreen extends StatefulWidget {
  const ModelFormScreen({super.key, this.model});

  final MotorcycleCatalog? model;

  @override
  State<ModelFormScreen> createState() => _ModelFormScreenState();
}

class _ModelFormScreenState extends State<ModelFormScreen> {
  late final MotorcycleCatalog? m = widget.model;
  late MotorcycleType? _type = m?.motorcycleType;
  late final _make = TextEditingController(text: m?.make ?? '');
  late final _model = TextEditingController(text: m?.model ?? '');
  late final _year = TextEditingController(text: m == null ? '' : '${m!.modelYear}');
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final c in [_make, _model, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final year = int.tryParse(_year.text);
    setState(() {
      _error = null;
      _errors = {
        if (_type == null) 'type': 'Choose a type to continue.',
        if (_make.text.trim().isEmpty) 'make': 'Enter the make, e.g. Yamaha.',
        if (_model.text.trim().isEmpty) 'model': 'Enter the model, e.g. Aerox 155.',
        if (year == null || year < 1950 || year > today().year + 1) 'year': 'Enter a year between 1950 and ${today().year + 1}.',
      };
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    final app = AppScope.read(context);
    final (saved, err) = await app.saveModel(MotorcycleCatalog(
      catalogId: m?.catalogId ?? '',
      make: _make.text.trim(),
      model: _model.text.trim(),
      motorcycleType: _type!,
      modelYear: year!,
    ));
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) {
      setState(() => _error = err);
      return;
    }
    if (m == null) {
      adminSnack(context, '${saved.name} added to the catalog',
          action: 'Add rules', onAction: () => AdminShell.goTab(context, 3, ruleModelId: saved.catalogId));
    } else {
      adminSnack(context, 'Model changes saved');
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete(int rules) async {
    final app = AppScope.read(context);
    final ok = await _confirmDelete(
        context,
        'Delete model?',
        '${m!.name} (${m!.modelYear}) and its $rules maintenance rule${rules == 1 ? '' : 's'} will be removed from the catalog.',
        'Delete Model');
    if (!ok || !mounted) return;
    final err = await app.deleteModel(m!);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    adminSnack(context, '${m!.name} deleted');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isNew = m == null;
    final rules = isNew ? 0 : app.rulesForCatalog(m!.catalogId).length;
    Widget input(TextEditingController c, String hint, String key, {bool digits = false}) => AppInput(
          controller: c,
          hint: hint,
          keyboardType: digits ? TextInputType.number : null,
          inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)] : null,
          textCapitalization: TextCapitalization.words,
          hasError: _errors[key] != null,
          onChanged: (_) => setState(() => _errors.remove(key)),
        );
    return AppPage(
      gap: 14,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _header(context, isNew ? 'Add motorcycle model' : 'Edit model',
            isNew ? null : 'Catalog ID · CAT-${m!.catalogId.toUpperCase()}'),
        if (isNew)
          Text('New models appear in the user app when owners register a motorcycle. Add maintenance rules afterwards.',
              style: ts(14, regular, AppColors.muted, 1.45))
        else
          CardBox(
            radius: 18,
            child: Row(spacing: 14, children: [
              const IconBox('bike', size: 56, radius: 14, iconSize: 26),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                  Text(m!.name, style: ts(18, bold)),
                  Text('Model year ${m!.modelYear}', style: ts(13, regular, AppColors.muted)),
                  Badge2.type(m!.motorcycleType),
                ]),
              ),
            ]),
          ),
        if (_error != null) ErrorBanner(_error!),
        _field(
          'Motorcycle type',
          _select(context,
              value: _type?.label,
              placeholder: 'Select a type',
              error: _errors['type'] != null,
              onTap: () async {
                final t = await _pick(context, 'Motorcycle type', [for (final t in MotorcycleType.values) (t, t.label, null)], _type);
                if (t != null) {
                  setState(() {
                    _type = t;
                    _errors.remove('type');
                  });
                }
              }),
          error: _errors['type'],
        ),
        _field('Make', input(_make, 'e.g. Yamaha', 'make'), error: _errors['make']),
        _field('Model', input(_model, 'e.g. Aerox 155', 'model'), error: _errors['model']),
        _field('Model year', input(_year, 'e.g. 2024', 'year', digits: true), error: _errors['year']),
        if (!isNew) ...[
          CardBox(
            onTap: () => AdminShell.goTab(context, 3, ruleModelId: m!.catalogId),
            child: Row(spacing: 12, children: [
              const IconBox('sliders', size: 40, radius: 11, iconSize: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text('$rules maintenance rule${rules == 1 ? '' : 's'}', style: ts(15, semiBold)),
                  Text('View the service intervals for this model', style: ts(12, regular, AppColors.muted)),
                ]),
              ),
              const AppIcon('chevR', color: AppColors.muted, size: 18),
            ]),
          ),
          Note('Deleting a model also removes its $rules maintenance rule${rules == 1 ? '' : 's'}.'),
        ],
        AppButton(isNew ? 'Add Model' : 'Save Changes', busy: _busy, onPressed: _save),
        if (!isNew) AppButton('Delete Model', kind: ButtonKind.danger, onPressed: () => _delete(rules)),
      ],
    );
  }
}

// ====================================================================== Edit rule · Add rule
class RuleFormScreen extends StatefulWidget {
  const RuleFormScreen({super.key, required this.model, this.rule});

  final MotorcycleCatalog model;
  final MaintenanceRule? rule;

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  late final MaintenanceRule? r = widget.rule;
  late String? _key = r?.componentKey;
  late String? _name = r?.componentName;
  late final _km = TextEditingController(text: r == null ? '' : '${r!.intervalKm}');
  late final _months = TextEditingController(text: r == null ? '' : '${r!.intervalMonths}');
  late final _source = TextEditingController(text: r?.sourceReference ?? "${widget.model.name} Owner's Manual · Periodic maintenance");
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final c in [_km, _months, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final km = int.tryParse(_km.text.replaceAll(',', ''));
    final months = int.tryParse(_months.text);
    setState(() {
      _error = null;
      _errors = {
        if (_key == null) 'component': 'Choose a component.',
        if (km == null || km < 100) 'km': 'Enter at least 100 km.',
        if (months == null || months < 1 || months > 120) 'months': 'Enter 1–120 months.',
        if (_source.text.trim().isEmpty) 'source': 'Enter where this interval comes from.',
      };
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    final err = await AppScope.read(context).saveRule(MaintenanceRule(
      ruleId: r?.ruleId ?? '',
      catalogId: widget.model.catalogId,
      componentKey: _key!,
      componentName: _name!,
      intervalKm: km!,
      intervalMonths: months!,
      sourceReference: _source.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    adminSnack(context, r == null ? '$_name rule added' : 'Rule changes saved');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final ok = await _confirmDelete(
        context,
        'Delete rule?',
        'The ${r!.componentName} rule (${ruleSentence(r!).replaceFirst('Every', 'every')}) will be removed from '
            '${widget.model.name}. Owners stop getting this reminder.',
        'Delete Rule');
    if (!ok || !mounted) return;
    final err = await app.deleteRule(r!);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    adminSnack(context, '${r!.componentName} rule deleted');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isNew = r == null;
    final used = {for (final x in app.rulesForCatalog(widget.model.catalogId)) if (x.ruleId != r?.ruleId) x.componentKey};
    final km = int.tryParse(_km.text);
    final months = int.tryParse(_months.text);
    Widget numInput(TextEditingController c, String key, String? suffix) => AppInput(
          controller: c,
          suffix: suffix,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          hasError: _errors[key] != null,
          onChanged: (_) => setState(() => _errors.remove(key)),
        );
    return AppPage(
      gap: 14,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _header(context, isNew ? 'Add maintenance rule' : 'Edit rule', isNew ? null : 'Rule ID · R-${r!.ruleId}'),
        if (isNew)
          Text('Choose a component. Recommended intervals fill in automatically and can be edited later.',
              style: ts(14, regular, AppColors.muted, 1.45))
        else
          CardBox(
            radius: 18,
            child: Row(spacing: 14, children: [
              IconBox(componentIconName(r!.componentKey), size: 56, radius: 14, iconSize: 26),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 3, children: [
                  Text(r!.componentName, style: ts(18, bold)),
                  Text(widget.model.name, style: ts(13, regular, AppColors.muted)),
                  Badge2.type(widget.model.motorcycleType),
                ]),
              ),
            ]),
          ),
        if (_error != null) ErrorBanner(_error!),
        _field(
          'Motorcycle model',
          InputBox(
            child: Text(widget.model.name, style: ts(15, semiBold, AppColors.muted)),
          ),
          helper: 'Rules belong to one catalog model.',
        ),
        _field(
          'Component',
          _select(context, value: _name, placeholder: 'Choose a component', error: _errors['component'] != null,
              onTap: () async {
            final p = await _pick(context, 'Component', [
              for (final p in componentPresets)
                if (!used.contains(p.$1)) (p, p.$2, 'Recommended: every ${fmtKm(p.$3)} or ${fmtMonths(p.$4)}'),
            ], null);
            if (p == null) return;
            setState(() {
              _key = p.$1;
              _name = p.$2;
              _errors.remove('component');
              if (isNew || _km.text.isEmpty) _km.text = '${p.$3}';
              if (isNew || _months.text.isEmpty) _months.text = '${p.$4}';
            });
          }),
          error: _errors['component'],
          helper: isNew && _key != null ? 'Filled from the component' : null,
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
          Expanded(child: _field('Interval (km)', numInput(_km, 'km', 'km'), error: _errors['km'])),
          Expanded(child: _field('Interval (months)', numInput(_months, 'months', 'mo'), error: _errors['months'])),
        ]),
        _field(
          'Source reference',
          AppInput(
            controller: _source,
            hint: "e.g. Owner's Manual · Periodic maintenance",
            fontWeight: medium,
            maxLines: 3,
            minLines: 1,
            hasError: _errors['source'] != null,
            onChanged: (_) => setState(() => _errors.remove('source')),
          ),
          error: _errors['source'],
        ),
        Note(km != null && months != null
            ? 'Owners are reminded at ${fmtKm(km)} or ${fmtMonths(months)}, whichever comes first.'
            : 'New rules apply to every owner of this model on their next odometer update.'),
        AppButton(isNew ? 'Add Rule' : 'Save Changes', busy: _busy, onPressed: _save),
        if (!isNew) AppButton('Delete Rule', kind: ButtonKind.danger, onPressed: _delete),
      ],
    );
  }
}
