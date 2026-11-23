import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import '../auth/welcome_screen.dart';
import 'admin_forms.dart';

// Admin Activity Diagram:
// Log In → Admin Dashboard → Choose Module (Users · Motorcycle Catalog · Maintenance Rules)
//   → View → Add / Edit / Delete → Save Changes → Return to Admin Dashboard → Manage Another Module? → Log Out

/// B1–B4 · Admin App with bottom navigation (Home · Users · Catalog · Rules · Profile).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  /// Opens a tab from a pushed admin screen (e.g. "View rules" on a catalog model).
  static void goTab(BuildContext context, int tab, {String? ruleModelId}) {
    Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/home');
    _AdminShellState.current?._go(tab, ruleModelId: ruleModelId);
  }

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static _AdminShellState? current;
  int _tab = 0;
  UserRole? _userFilter;
  String? _ruleModelId;

  @override
  void initState() {
    super.initState();
    current = this;
  }

  @override
  void dispose() {
    if (current == this) current = null;
    super.dispose();
  }

  void _go(int tab, {UserRole? userFilter, String? ruleModelId}) {
    if (!mounted) return;
    setState(() {
      _tab = tab;
      if (tab == 1) _userFilter = userFilter;
      if (ruleModelId != null) _ruleModelId = ruleModelId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(go: _go),
      _UsersTab(key: ValueKey('users-$_userFilter'), initialFilter: _userFilter, onBack: () => _go(0)),
      _CatalogTab(onBack: () => _go(0)),
      _RulesTab(
        modelId: _ruleModelId,
        onModel: (id) => setState(() => _ruleModelId = id),
        onBack: () => _go(0),
      ),
      _ProfileTab(go: _go),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              for (final (i, icon, label) in [
                (0, 'home', 'Home'),
                (1, 'users', 'Users'),
                (2, 'book', 'Catalog'),
                (3, 'sliders', 'Rules'),
                (4, 'user', 'Profile'),
              ])
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _go(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                        Container(
                          width: 52,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab == i ? AppColors.accentSoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: AppIcon(icon, color: _tab == i ? AppColors.accentStrong : AppColors.muted, size: 20),
                        ),
                        Text(label,
                            style: ts(11, _tab == i ? bold : semiBold, _tab == i ? AppColors.accentStrong : AppColors.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

typedef _Go = void Function(int tab, {UserRole? userFilter, String? ruleModelId});

/// Colours of the role badge and avatar.
(Color bg, Color fg) roleColors(UserRole r) => switch (r) {
      UserRole.owner => (AppColors.successSoft, AppColors.successText),
      UserRole.mechanic => (AppColors.warnSoft, AppColors.warnText),
      UserRole.admin => (AppColors.accentSoft, AppColors.accentStrong),
    };

/// "Badge/…"
class Badge2 extends StatelessWidget {
  const Badge2(this.label, {super.key, required this.bg, required this.fg});

  factory Badge2.role(UserRole r) {
    final (bg, fg) = roleColors(r);
    return Badge2(r == UserRole.owner ? 'Owner' : r.label, bg: bg, fg: fg);
  }

  factory Badge2.active(bool active) => active
      ? const Badge2('Active', bg: AppColors.successSoft, fg: AppColors.successText)
      : const Badge2('Inactive', bg: AppColors.neutralSoft, fg: AppColors.muted);

  factory Badge2.type(MotoType t) => Badge2(t.label, bg: AppColors.neutralSoft, fg: AppColors.text);

  final String label;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 5, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          Text(label, style: ts(11, semiBold, fg)),
        ]),
      );
}

class RoleAvatar extends StatelessWidget {
  const RoleAvatar(this.user, {super.key, this.size = 44, this.fontSize = 16});

  final UserAccount user;
  final double size, fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = roleColors(user.role);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(initials(user.fullName), style: ts(fontSize, bold, fg)),
    );
  }
}

/// Header of a module screen: back to dashboard, title, "+" add button.
class ModuleHeader extends StatelessWidget {
  const ModuleHeader(this.title, {super.key, required this.onBack, this.onAdd, this.addTooltip});

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onAdd;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) => Row(spacing: 14, children: [
        SquareButton('chevL', iconSize: 20, tooltip: 'Back to dashboard', onTap: onBack),
        Expanded(child: Text(title, style: ts(22, bold), overflow: TextOverflow.ellipsis)),
        if (onAdd != null)
          Tooltip(
            message: addTooltip ?? 'Add',
            child: Material(
              color: AppColors.accentStrong,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onAdd,
                child: const SizedBox(width: 44, height: 44, child: Center(child: AppIcon('plus', color: Colors.white, size: 22))),
              ),
            ),
          ),
      ]);
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AppInput(
        controller: controller,
        icon: 'search',
        hint: hint,
        fontWeight: regular,
        onChanged: onChanged,
        trailing: controller.text.isEmpty
            ? null
            : GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: const Padding(padding: EdgeInsets.all(4), child: AppIcon('x', color: AppColors.muted, size: 16)),
              ),
      );
}

class FilterChip2 extends StatelessWidget {
  const FilterChip2(this.label, {super.key, required this.on, required this.onTap});

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label, style: ts(13, semiBold, on ? Colors.white : AppColors.text)),
          ),
        ),
      );
}

/// Row with an icon tile, title, subtitle and trailing widget (modules, users, models, rules).
class AdminRow extends StatelessWidget {
  const AdminRow({super.key, this.leading, this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});

  final Widget? leading;
  final String? icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        child: Row(spacing: 12, children: [
          leading ?? IconBox(icon ?? 'info', size: 44, radius: 12, iconSize: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text(title, style: ts(15, semiBold)),
              Text(subtitle, style: ts(12, regular, AppColors.muted)),
            ]),
          ),
          trailing ?? const AppIcon('chevR', color: AppColors.muted, size: 18),
        ]),
      );
}

void adminSnack(BuildContext context, String text, {String? action, VoidCallback? onAction}) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action == null ? null : SnackBarAction(label: action, textColor: AppColors.accentSoft, onPressed: onAction!),
      ));

// ====================================================================== B1 · Admin Dashboard
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.go});

  final _Go go;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser;
    if (me == null) return const SizedBox.shrink(); // signed out
    final users = app.users;
    final activity = app.activity.take(4).toList();
    return AppPage(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      onRefresh: () async => app.refresh(),
      children: [
        Row(spacing: 12, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text('Welcome back,', style: ts(13, regular, AppColors.muted)),
              Text(me.fullName, style: ts(24, FontWeight.w800)),
            ]),
          ),
          SquareButton('bell', tooltip: 'Notifications', badge: activity.length, onTap: () => showAdminNotifications(context)),
        ]),
        // Hero card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.accentStrong, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
            Text('Registered accounts', style: ts(13, medium, Colors.white)),
            Row(children: [
              Expanded(child: Text(fmtNum(users.length), style: ts(40, FontWeight.w800, Colors.white))),
              Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => go(1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Manage', style: ts(13, bold, AppColors.accentStrong)),
                  ),
                ),
              ),
            ]),
            Text('Updated ${fmtDate(today())} · 3 roles', style: ts(12, medium, Colors.white)),
          ]),
        ),
        Row(spacing: 10, children: [
          for (final r in UserRole.values)
            Expanded(
              child: Builder(builder: (_) {
                final (bg, fg) = roleColors(r);
                return Material(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => go(1, userFilter: r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(spacing: 2, children: [
                        Text(fmtNum(app.countRole(r)), style: ts(22, FontWeight.w800, fg)),
                        Text(r.plural, style: ts(12, semiBold, fg)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
        ]),
        _SectionTitle('Manage modules', '3 modules'),
        AdminRow(
          icon: 'users',
          title: 'Users',
          subtitle: '${fmtNum(users.length)} accounts · owners, mechanics, admins',
          onTap: () => go(1),
        ),
        AdminRow(
          icon: 'book',
          title: 'Motorcycle Catalog',
          subtitle: '${app.catalog.length} models · type, make, model, year',
          onTap: () => go(2),
        ),
        AdminRow(
          icon: 'sliders',
          title: 'Maintenance Rules',
          subtitle: '${app.allRules.length} rules · intervals per component',
          onTap: () => go(3),
        ),
        _SectionTitle('Recent changes', activity.isEmpty ? '' : timeAgo(activity.first.at)),
        CardBox(
          radius: 18,
          padding: const EdgeInsets.all(12),
          child: activity.isEmpty
              ? Text('No changes yet. Edits you save in any module show up here.', style: ts(13, regular, AppColors.muted))
              : Column(spacing: 10, children: [
                  for (final a in activity)
                    Row(spacing: 10, children: [
                      IconBox(a.icon, size: 36, radius: 10, iconSize: 18),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 1, children: [
                          Text(a.title, style: ts(14, semiBold)),
                          Text(a.subtitle, style: ts(12, regular, AppColors.muted)),
                        ]),
                      ),
                      Text(timeAgo(a.at), style: ts(12, medium, AppColors.muted)),
                    ]),
                ]),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.meta);

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

/// B2 · Notifications (overlay)
Future<void> showAdminNotifications(BuildContext context) {
  final app = AppScope.read(context);
  return showAppSheet(context, title: 'Notifications', children: (sheet) {
    final list = app.activity;
    return [
      if (list.isEmpty) Text('No notifications yet.', style: ts(13, regular, AppColors.muted)),
      for (final a in list.take(8))
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(spacing: 12, children: [
            IconBox(a.icon, size: 40, radius: 11, iconSize: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text(a.title, style: ts(15, semiBold)),
                Text('${a.subtitle} · ${timeAgo(a.at).toLowerCase()}', style: ts(12, regular, AppColors.muted)),
              ]),
            ),
          ]),
        ),
    ];
  });
}

// ====================================================================== C1 · Manage users
class _UsersTab extends StatefulWidget {
  const _UsersTab({super.key, this.initialFilter, required this.onBack});

  final UserRole? initialFilter;
  final VoidCallback onBack;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late UserRole? _filter = widget.initialFilter;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.users;
    final q = _q.text.trim().toLowerCase();
    final list = all
        .where((u) => _filter == null || u.role == _filter)
        .where((u) => q.isEmpty || u.fullName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return AppPage(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        ModuleHeader('Manage users',
            onBack: widget.onBack,
            addTooltip: 'Add user',
            onAdd: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserFormScreen()))),
        SearchField(controller: _q, hint: 'Search name or email', onChanged: (_) => setState(() {})),
        if (q.isNotEmpty) Text('Search looks at full name and email address.', style: ts(12, regular, AppColors.muted)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(spacing: 8, children: [
            FilterChip2('All ${fmtNum(all.length)}', on: _filter == null, onTap: () => setState(() => _filter = null)),
            for (final r in UserRole.values)
              FilterChip2('${r.plural} ${fmtNum(app.countRole(r))}', on: _filter == r, onTap: () => setState(() => _filter = r)),
          ]),
        ),
        _SectionTitle(_filter == null ? 'All accounts' : _filter!.plural,
            q.isEmpty ? 'Showing ${list.length} of ${all.length}' : '${list.length} match${list.length == 1 ? '' : 'es'}'),
        if (list.isEmpty) CardBox(child: Text('No accounts found.', style: ts(13, regular, AppColors.muted))),
        for (final u in list)
          AdminRow(
            leading: RoleAvatar(u),
            title: u.fullName,
            subtitle: u.email,
            trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, spacing: 4, children: [
              Badge2.role(u.role),
              Badge2.active(u.active),
            ]),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserFormScreen(user: u))),
          ),
      ],
    );
  }
}

// ====================================================================== D1 · Motorcycle catalog
class _CatalogTab extends StatefulWidget {
  const _CatalogTab({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> {
  MotoType? _filter;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.catalog;
    final q = _q.text.trim().toLowerCase();
    final list = all
        .where((c) => _filter == null || c.type == _filter)
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return AppPage(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        ModuleHeader('Motorcycle catalog',
            onBack: widget.onBack,
            addTooltip: 'Add model',
            onAdd: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModelFormScreen()))),
        SearchField(controller: _q, hint: 'Search make or model', onChanged: (_) => setState(() {})),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(spacing: 8, children: [
            FilterChip2('All ${all.length}', on: _filter == null, onTap: () => setState(() => _filter = null)),
            for (final t in MotoType.values)
              FilterChip2('${t.label} ${all.where((c) => c.type == t).length}',
                  on: _filter == t, onTap: () => setState(() => _filter = t)),
          ]),
        ),
        _SectionTitle(_filter == null ? 'All models' : '${_filter!.label} models',
            q.isEmpty ? 'Showing ${list.length} of ${all.length}' : '${list.length} match${list.length == 1 ? '' : 'es'}'),
        if (list.isEmpty) CardBox(child: Text('No models found.', style: ts(13, regular, AppColors.muted))),
        for (final c in list)
          AdminRow(
            icon: 'bike',
            title: c.name,
            subtitle: '${c.year} · ${app.rulesForCatalog(c.id).length} maintenance rules',
            trailing: Badge2.type(c.type),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModelFormScreen(model: c))),
          ),
      ],
    );
  }
}

// ====================================================================== E1 · Maintenance rules
class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.modelId, required this.onModel, required this.onBack});

  final String? modelId;
  final ValueChanged<String> onModel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final catalog = app.catalog;
    final model = catalog.where((c) => c.id == modelId).firstOrNull ?? catalog.firstOrNull;
    if (model == null) {
      return AppPage(children: [
        ModuleHeader('Maintenance rules', onBack: onBack),
        CardBox(child: Text('Add a motorcycle model to the catalog first.', style: ts(13, regular, AppColors.muted))),
      ]);
    }
    final rules = app.rulesForCatalog(model.id);
    Future<void> choose() async {
      final id = await showAppSheet<String>(context, title: 'Choose a model', children: (sheet) => [
            for (final c in catalog)
              AdminRow(
                icon: 'bike',
                title: c.name,
                subtitle: '${c.type.label} · ${c.year} · ${app.rulesForCatalog(c.id).length} rules',
                trailing: c.id == model.id ? const AppIcon('check', color: AppColors.accentStrong, size: 18) : null,
                onTap: () => Navigator.of(sheet).pop(c.id),
              ),
          ]);
      if (id != null) onModel(id);
    }

    return AppPage(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        ModuleHeader('Maintenance rules',
            onBack: onBack,
            addTooltip: 'Add rule',
            onAdd: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RuleFormScreen(model: model)))),
        CardBox(
          radius: 18,
          borderColor: AppColors.accentStrong,
          borderWidth: 1.5,
          onTap: choose,
          child: Row(spacing: 12, children: [
            const IconBox('bike', size: 44, radius: 12, iconSize: 22),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                Text('Motorcycle model', style: ts(12, medium, AppColors.muted)),
                Text(model.name, style: ts(16, bold)),
                Text('${model.type.label} · ${model.year}', style: ts(12, regular, AppColors.muted)),
              ]),
            ),
            Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Text('Change', style: ts(13, bold, AppColors.accentStrong)),
              const AppIcon('chevD', color: AppColors.accentStrong, size: 16),
            ]),
          ]),
        ),
        _SectionTitle('Service intervals', '${rules.length} rule${rules.length == 1 ? '' : 's'}'),
        if (rules.isEmpty)
          CardBox(
              child: Text('No maintenance rules yet. Tap + to add the first one.', style: ts(13, regular, AppColors.muted))),
        for (final r in rules)
          AdminRow(
            icon: componentIconName(r.componentKey),
            title: r.componentName,
            subtitle: ruleSentence(r),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => RuleFormScreen(model: model, rule: r))),
          ),
        Text('Owners get a reminder at whichever limit comes first.', style: ts(12, regular, AppColors.muted)),
      ],
    );
  }
}

// ====================================================================== B3 · Admin Profile
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.go});

  final _Go go;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser;
    if (me == null) return const SizedBox.shrink(); // signed out
    return AppPage(
      gap: 14,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Text('Profile', style: ts(22, bold)),
        CardBox(
          radius: 18,
          padding: const EdgeInsets.all(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserFormScreen(user: me))),
          child: Row(spacing: 14, children: [
            RoleAvatar(me, size: 64, fontSize: 22),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                Text(me.fullName, style: ts(18, bold)),
                Text(me.email, style: ts(13, regular, AppColors.muted)),
                Row(spacing: 8, children: [
                  Badge2.role(UserRole.admin),
                  Text('Since ${me.createdAt == null ? '—' : fmtMonthYear(me.createdAt!)}',
                      style: ts(12, medium, AppColors.muted)),
                ]),
              ]),
            ),
          ]),
        ),
        Row(spacing: 10, children: [
          for (final (n, label, tab) in [
            (app.users.length, 'Users', 1),
            (app.catalog.length, 'Models', 2),
            (app.allRules.length, 'Rules', 3),
          ])
            Expanded(
              child: CardBox(
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: () => go(tab),
                child: Column(spacing: 2, children: [
                  Text(fmtNum(n), style: ts(20, FontWeight.w800)),
                  Text(label, style: ts(12, semiBold, AppColors.muted)),
                ]),
              ),
            ),
        ]),
        Text('Modules', style: ts(16, bold)),
        CardBox(
          radius: 18,
          padding: const EdgeInsets.all(8),
          child: Column(spacing: 4, children: [
            for (final (icon, title, sub, tab) in [
              ('users', 'Manage users', 'Add, edit or remove accounts', 1),
              ('book', 'Motorcycle catalog', 'Types, makes, models and years', 2),
              ('sliders', 'Maintenance rules', 'Service intervals per component', 3),
            ])
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => go(tab),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(spacing: 12, children: [
                    IconBox(icon, size: 40, radius: 11, iconSize: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 1, children: [
                        Text(title, style: ts(14, semiBold)),
                        Text(sub, style: ts(12, regular, AppColors.muted)),
                      ]),
                    ),
                    const AppIcon('chevR', color: AppColors.muted, size: 18),
                  ]),
                ),
              ),
          ]),
        ),
        AppButton('Log Out', kind: ButtonKind.danger, onPressed: () => _logOut(context)),
      ],
    );
  }
}

/// B4 · Log Out (overlay)
Future<void> _logOut(BuildContext context) => showAppSheet(context, title: 'Log out?', gap: 14, children: (sheet) => [
      Text('You will need to log in again to manage users, the catalog and maintenance rules.',
          style: ts(14, regular, AppColors.muted, 1.45)),
      AppButton('Log Out', kind: ButtonKind.danger, onPressed: () async {
        final app = AppScope.read(context);
        final nav = Navigator.of(context);
        Navigator.of(sheet).pop();
        await app.logout();
        nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
      }),
      AppButton('Cancel', kind: ButtonKind.secondary, onPressed: () => Navigator.of(sheet).pop()),
    ]);
