import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import 'mech_flow.dart';
import 'mech_more.dart';
import 'mech_ui.dart';

/// "Honda Vario 160 · B 4521 KXR"
String motoLine(AppState app, Motorcycle m) => '${app.catalogOf(m).name} · ${m.plate}';

/// Mechanic Activity Diagram: Log In → Mechanic Dashboard (Home · Search · Jobs · Profile).
class MechanicShell extends StatefulWidget {
  const MechanicShell({super.key});

  /// Switches the bottom navigation from any mechanic screen below the shell.
  static void goTab(BuildContext context, int tab) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst || r.settings.name == '/home');
    _MechanicShellState.current?._go(tab);
  }

  @override
  State<MechanicShell> createState() => _MechanicShellState();
}

class _MechanicShellState extends State<MechanicShell> {
  static _MechanicShellState? current;
  int _tab = 0;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    current = this;
  }

  @override
  void dispose() {
    if (current == this) current = null;
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(int tab) {
    if (!mounted) return;
    setState(() => _tab = tab);
    if (tab == 1) WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(onTab: _go),
      SearchTab(focus: _searchFocus),
      const _JobsTab(),
      const _ProfileTab(),
    ];
    return Scaffold(
      backgroundColor: MC.bg,
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: MC.surface, border: Border(top: BorderSide(color: MC.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final (i, icon, label) in [(0, 'home', 'Home'), (1, 'search', 'Search'), (2, 'wrench', 'Jobs'), (3, 'user', 'Profile')])
                Material(
                  color: _tab == i ? MC.soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _go(i),
                    child: SizedBox(
                      width: 72,
                      height: 56,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: 4, children: [
                        AppIcon(icon, color: _tab == i ? MC.accentText : MC.muted, size: 22),
                        Text(label, style: mt(11, _tab == i ? mBold : mSemi, _tab == i ? MC.accentText : MC.muted)),
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

// ====================================================================== 01 Dashboard
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser;
    if (me == null) return const SizedBox.shrink(); // signed out
    final jobs = app.todaysJobs;
    final inProgress = jobs.where((j) => j.status == JobStatus.inProgress).length;
    final waiting = jobs.length - inProgress;
    final recent = app.myServices.take(2).toList();
    final flags = app.overdueFlags.length;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return MechPage(
      gap: 14,
      onRefresh: () async => app.refresh(),
      children: [
        // Brand + workshop pill
        Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: MC.gradient, borderRadius: BorderRadius.circular(9)),
            child: const AppIcon('wrench', color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('Motorcycle Care', style: mt(14, mXBold, MC.accentText))),
          GestureDetector(
            onTap: () => push(const WorkshopScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: MC.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: MC.softBorder)),
              child: Text(me.workshopName ?? 'No workshop', style: mt(11, mBold, MC.accentText)),
            ),
          ),
        ]),
        // Welcome
        Row(spacing: 12, children: [
          GestureDetector(onTap: () => onTab(3), child: Avatar(initials(me.fullName))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text('Welcome back,', style: mt(12, mMedium, MC.muted)),
              Text(me.fullName, overflow: TextOverflow.ellipsis, style: mt(20, mXBold)),
            ]),
          ),
          MechIconButton('bell',
              tooltip: 'Notifications', dot: flags > 0 || waiting > 0, onTap: () => push(const NotificationsScreen())),
        ]),
        // Hero card: Today's Jobs
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(gradient: MC.gradient, borderRadius: BorderRadius.circular(24)),
          child: Stack(children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                    Text("Today's Jobs", style: mt(13, mMedium, MC.heroText)),
                    Text('${jobs.length}', style: mt(36, mXBold, Colors.white, 1.2)),
                    Text('$inProgress in progress · $waiting waiting', style: mt(12, mSemi, MC.heroText)),
                  ]),
                ),
                PillButton('View Jobs', white: true, onTap: () => onTab(2)),
              ]),
            ),
          ]),
        ),
        // Tiles
        Row(spacing: 10, children: [
          StatTile('${app.doneToday.length}', 'Done today', onTap: () => push(const DoneTodayScreen())),
          StatTile('${app.thisWeek.length}', 'This week', onTap: () => push(const ThisWeekScreen())),
          StatTile('$flags', 'Overdue flags',
              valueColor: flags > 0 ? MC.danger : MC.text, onTap: () => push(const OverdueFlagsScreen())),
        ]),
        // Search bar
        MechCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          onTap: () => onTab(1),
          child: Row(spacing: 10, children: [
            const AppIcon('search', color: MC.muted, size: 18),
            Expanded(child: Text('Search plate number', style: mt(14, mSemi, MC.hint))),
            const AppIcon('scan', color: MC.muted, size: 18),
          ]),
        ),
        // Quick actions
        Text('Quick Actions', style: mt(16, mXBold)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _Quick('search', 'Search', () => onTab(1)),
          _Quick('plus', 'Add', () => push(const AddMotorcycleScreen())),
          _Quick('wrench', 'Jobs', () => onTab(2)),
          _Quick('scan', 'Scan', () => scanPlate(context)),
        ]),
        // Recent services
        SectionTitle('Recent Services', link: 'See all', onLink: () => push(const MechHistoryScreen())),
        if (recent.isEmpty)
          MechCard(child: Text('Services you save will appear here.', style: mt(13, mMedium, MC.muted)))
        else
          for (final r in recent)
            if (app.motorcycleById(r.motorcycleId) case final m?)
              MechRow(
                icon: 'bike',
                title: app.catalogOf(m).name,
                subtitle: '${m.plate} · ${r.description.isEmpty ? 'Service' : r.description}',
                trailing: StatusChip.ok('Saved'),
                onTap: () => push(MotorcycleInfoScreen(motorcycleId: m.id)),
              ),
      ],
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.onTap);

  final String icon, label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(spacing: 6, children: [
            IconSquare(icon, size: 52, radius: 18, iconSize: 22, border: true),
            Text(label, style: mt(11, mSemi)),
          ]),
        ),
      );
}

/// Plate scanning needs a text-recognition module that is not part of this version.
void scanPlate(BuildContext context) {
  MechanicShell.goTab(context, 1);
  mechSnack(context, 'Camera plate scanning is not available yet. Type the plate number instead.');
}

// ====================================================================== 02 Search Motorcycle
class SearchTab extends StatefulWidget {
  const SearchTab({super.key, this.focus});

  final FocusNode? focus;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _plate = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  /// Search Motorcycle → Motorcycle Found? → Yes: Motorcycle Information · No: Motorcycle Not Found
  void _search([String? plate]) {
    final value = plate ?? _plate.text;
    if (value.trim().isEmpty) {
      setState(() => _error = 'Enter a plate number, e.g. B 4521 KXR.');
      return;
    }
    final app = AppScope.read(context);
    final normalized = AppState.normalizePlate(value);
    _plate.text = normalized;
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    final m = app.findByPlate(normalized);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => m == null ? NotFoundScreen(plate: normalized) : MotorcycleInfoScreen(motorcycleId: m.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final recent = app.recentSearches;
    return MechPage(
      header: const MechTabHeader('Search Motorcycle'),
      children: [
        Text('Enter the plate number to find the motorcycle you are about to service.',
            style: mt(13, mMedium, MC.muted, 1.4)),
        MechField(
          'Plate Number',
          error: _error,
          child: Focus(
            focusNode: widget.focus,
            child: MechInput(
              controller: _plate,
              icon: 'search',
              hint: 'B 4521 KXR',
              caps: TextCapitalization.characters,
              error: _error != null,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _search(),
            ),
          ),
        ),
        MechButton('Search', icon: 'search', onTap: _search),
        MechButton('Scan Plate with Camera', icon: 'camera', kind: MechButtonKind.soft, onTap: () => scanPlate(context)),
        Align(
          alignment: Alignment.centerLeft,
          child: PillButton('Try a plate that is not registered', icon: 'alert', onTap: () => _search('B 9999 ZZZ')),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: PillButton('Register a new motorcycle',
              icon: 'alert',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMotorcycleScreen()))),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Recent Searches', style: mt(16, mXBold)),
          for (final m in recent)
            MechRow(
              icon: 'clock',
              title: m.plate,
              subtitle: app.catalogOf(m).name,
              trailing: const AppIcon('chevR', color: MC.muted, size: 18),
              onTap: () => _search(m.plate),
            ),
        ],
      ],
    );
  }
}

// ====================================================================== 13 Today's Jobs
class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  JobStatus? _filter; // null = Total

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.todaysJobs;
    final inProgress = all.where((j) => j.status == JobStatus.inProgress).length;
    final jobs = _filter == null ? all : all.where((j) => j.status == _filter).toList();
    return MechPage(
      header: const MechTabHeader("Today's Jobs"),
      gap: 12,
      onRefresh: () async => app.refresh(),
      children: [
        Row(spacing: 10, children: [
          StatTile('${all.length}', 'Total', highlight: _filter == null, onTap: () => setState(() => _filter = null)),
          StatTile('$inProgress', 'In progress',
              highlight: _filter == JobStatus.inProgress, onTap: () => setState(() => _filter = JobStatus.inProgress)),
          StatTile('${all.length - inProgress}', 'Waiting',
              highlight: _filter == JobStatus.waiting, onTap: () => setState(() => _filter = JobStatus.waiting)),
        ]),
        if (jobs.isEmpty)
          MechCard(
            child: Text(
                _filter == null
                    ? 'No jobs yet. Search a motorcycle and tap Start Inspection to add it here.'
                    : 'No ${_filter == JobStatus.waiting ? 'waiting' : 'in-progress'} jobs.',
                style: mt(13, mMedium, MC.muted, 1.4)),
          ),
        for (final (i, j) in jobs.indexed)
          if (app.motorcycleById(j.motorcycleId) case final m?)
            MechRow(
              icon: 'bike',
              titleSize: 13,
              highlight: i == 0 && j.status == JobStatus.inProgress,
              title: app.catalogOf(m).name,
              subtitle: '${m.plate} · ${j.note}',
              trailing: j.status == JobStatus.inProgress
                  ? const StatusChip('In Progress', bg: MC.soft, fg: MC.accentText)
                  : const StatusChip('Waiting', bg: MC.warnBg, fg: MC.warn),
              onTap: () {
                app.findByPlate(m.plate);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => MotorcycleInfoScreen(motorcycleId: m.id)));
              },
            ),
      ],
    );
  }
}

// ====================================================================== 15 Profile
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser;
    if (me == null) return const SizedBox.shrink(); // signed out
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return MechPage(
      header: const MechTabHeader('Profile'),
      children: [
        MechCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          onTap: () => push(const PersonalInfoScreen()),
          child: Column(spacing: 8, children: [
            Avatar(initials(me.fullName), size: 76, fontSize: 26),
            Text(me.fullName, style: mt(20, mXBold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: MC.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: MC.softBorder)),
              child: Text('Mechanic · ${me.workshopName ?? 'No workshop'}', style: mt(12, mBold, MC.accentText)),
            ),
          ]),
        ),
        Row(spacing: 10, children: [
          StatTile('${app.myServices.length}', 'Services', onTap: () => push(const ServicesCompletedScreen())),
          StatTile('${app.thisMonth.length}', 'This month', onTap: () => push(const ThisMonthScreen())),
          StatTile(app.reviews.isEmpty ? '–' : app.rating.toStringAsFixed(1), 'Rating',
              onTap: () => push(const ReviewsScreen())),
        ]),
        MechCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (final (i, (icon, label, Widget screen)) in [
              ('bell', 'Notifications', const NotificationsScreen()),
              ('clock', 'Service History', const MechHistoryScreen()),
              ('store', 'Workshop', const WorkshopScreen()),
              ('help', 'Help & Support', const HelpScreen()),
            ].indexed) ...[
              if (i > 0) const Divider(height: 1, color: MC.border),
              InkWell(
                onTap: () => push(screen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(spacing: 12, children: [
                    IconSquare(icon, size: 36, radius: 12, iconSize: 18),
                    Expanded(child: Text(label, style: mt(14, mSemi))),
                    const AppIcon('chevR', color: MC.muted, size: 18),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        MechButton('Log Out', icon: 'logout', kind: MechButtonKind.danger, onTap: () async {
          final name = me.fullName;
          final email = me.email;
          final nav = Navigator.of(context);
          await app.logout();
          nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => LoggedOutScreen(name: name, email: email)), (_) => false);
        }),
      ],
    );
  }
}
