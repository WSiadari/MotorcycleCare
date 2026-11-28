import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../widgets/app_icon.dart';
import '../auth/login_screen.dart';
import 'mech_flow.dart';
import 'mech_ui.dart';
import 'mechanic_shell.dart';

Route<void> _r(Widget w) => MaterialPageRoute(builder: (_) => w);

/// Number of services per component name.
List<(String, int)> _byType(AppState app, List<ServiceRecord> records) {
  final counts = <String, int>{};
  for (final r in records) {
    final m = app.motorcycleById(r.motorcycleId);
    for (final k in r.componentKeys) {
      final name = m == null ? k : (app.rulesFor(m).where((x) => x.componentKey == k).firstOrNull?.componentName ?? k);
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  return counts.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
}

Widget _breakdown(List<(String, int)> rows) {
  final top = rows.fold<int>(1, (a, r) => math.max(a, r.$2));
  return MechCard(
    radius: 20,
    padding: const EdgeInsets.all(16),
    child: rows.isEmpty
        ? Text('No services yet.', style: mt(13, mMedium, MC.muted))
        : Column(spacing: 12, children: [
            for (final (name, n) in rows)
              Row(spacing: 10, children: [
                SizedBox(width: 92, child: Text(name, style: mt(13, mSemi))),
                Expanded(child: ProgressBar(n / top)),
                SizedBox(width: 26, child: Text('$n', textAlign: TextAlign.right, style: mt(13, mXBold, MC.accentText))),
              ]),
          ]),
  );
}

Widget _serviceRow(BuildContext context, AppState app, ServiceRecord r, {bool time = false}) {
  final m = app.motorcycleById(r.motorcycleId);
  if (m == null) return const SizedBox.shrink();
  return MechRow(
    icon: 'check',
    title: app.catalogOf(m).name,
    subtitle: '${m.plateNumber} · ${r.description.isEmpty ? 'Service' : r.description}',
    extra: time ? 'Completed at ${fmtTime(r.createdAt ?? r.serviceDate)}' : fmtDate(r.serviceDate),
    onTap: () => Navigator.of(context).push(_r(MechHistoryScreen(motorcycleId: m.motorcycleId))),
  );
}

// ====================================================================== Notifications
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = <(String icon, String title, String body, DateTime at, bool unread, VoidCallback onTap)>[
      for (final (m, s) in app.overdueFlags)
        ('alert', '${s.rule.componentName} overdue', '${m.plateNumber} needs a ${s.rule.componentName.toLowerCase()} service.',
            m.odometerUpdatedAt, true, () => Navigator.of(context).push(_r(MotorcycleInfoScreen(motorcycleId: m.motorcycleId)))),
      for (final j in app.todaysJobs.where((j) => j.status == JobStatus.waiting))
        if (app.motorcycleById(j.motorcycleId) case final m?)
          ('wrench', 'New job assigned', '${app.catalogOf(m).name} · ${m.plateNumber} · ${j.note}', j.createdAt, true,
              () => Navigator.of(context).push(_r(MotorcycleInfoScreen(motorcycleId: m.motorcycleId)))),
      for (final r in app.myServices.where((r) => r.receipt != null).take(3))
        if (app.motorcycleById(r.motorcycleId) case final m?)
          ('receipt', 'Receipt uploaded', 'Receipt attached to ${m.plateNumber} service.', r.createdAt ?? r.serviceDate, false,
              () => Navigator.of(context).push(_r(ReceiptDetailScreen(record: r)))),
      for (final rv in app.reviews.take(2))
        ('star', 'New review', '${rv.ownerName} rated your service ${rv.rating}/5.', rv.createdAt, false,
            () => Navigator.of(context).push(_r(const ReviewsScreen()))),
    ]..sort((a, b) => b.$4.compareTo(a.$4));
    return MechPage(
      header: const MechHeader('Notifications'),
      gap: 10,
      children: [
        if (items.isEmpty) MechCard(child: Text('You are all caught up.', style: mt(13, mMedium, MC.muted))),
        for (final (icon, title, body, at, unread, onTap) in items)
          MechCard(
            color: unread ? MC.soft : MC.surface,
            borderColor: unread ? MC.softBorder : MC.border,
            onTap: onTap,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
              IconSquare(icon, bg: Colors.white, border: true),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 3, children: [
                  Text(title, style: mt(14, mBold)),
                  Text(body, style: mt(12, mMedium, MC.muted, 1.35)),
                  Text(timeAgo(at), style: mt(11, mSemi, MC.faint)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }
}

// ====================================================================== Logged Out
class LoggedOutScreen extends StatelessWidget {
  const LoggedOutScreen({super.key, required this.name, required this.email});

  final String name, email;

  @override
  Widget build(BuildContext context) => MechPage(
        bottom: [
          MechButton('Sign Back In',
              onTap: () => Navigator.of(context)
                  .pushAndRemoveUntil(_r(LoginScreen(prefillEmail: email)), (_) => false)),
        ],
        children: [
          const SizedBox(height: 120),
          Center(
            child: Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: MC.gradient, borderRadius: BorderRadius.circular(30)),
              child: const AppIcon('wrench', color: Colors.white, size: 28),
            ),
          ),
          Text('MotorcycleCare', textAlign: TextAlign.center, style: mt(24, mXBold, MC.accentText)),
          Text("You've been logged out", textAlign: TextAlign.center, style: mt(18, mXBold)),
          Text('See you next time, $name. Your service records are safely saved.',
              textAlign: TextAlign.center, style: mt(13, mMedium, MC.muted, 1.45)),
        ],
      );
}

// ====================================================================== Done Today
class DoneTodayScreen extends StatelessWidget {
  const DoneTodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final list = app.doneToday;
    return MechPage(
      header: const MechHeader('Done Today'),
      gap: 12,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: MC.gradient, borderRadius: BorderRadius.circular(20)),
          child: Row(spacing: 12, children: [
            Text('${list.length}', style: mt(32, mXBold, Colors.white)),
            Text('services completed today\n${fmtDate(today())}', style: mt(12, mSemi, MC.heroText, 1.4)),
          ]),
        ),
        if (list.isEmpty) MechCard(child: Text('No services completed yet today.', style: mt(13, mMedium, MC.muted))),
        for (final r in list) _serviceRow(context, app, r, time: true),
      ],
    );
  }
}

// ====================================================================== This Week
class ThisWeekScreen extends StatelessWidget {
  const ThisWeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final week = app.thisWeek;
    final start = app.weekStart;
    final last = app.servicesBetween(start.subtract(const Duration(days: 7)), start).length;
    final perDay = [for (var i = 0; i < 7; i++) week.where((r) => dateOnly(r.serviceDate) == start.add(Duration(days: i))).length];
    final top = perDay.fold<int>(1, math.max);
    final change = last == 0 ? null : ((week.length - last) / last * 100).round();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return MechPage(
      header: const MechHeader('This Week'),
      gap: 12,
      children: [
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(spacing: 12, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text('${week.length}', style: mt(32, mXBold)),
                  Text('services this week', style: mt(12, mMedium, MC.muted)),
                ]),
              ),
              if (change != null)
                change >= 0
                    ? StatusChip.ok('+$change% vs last week')
                    : StatusChip('$change% vs last week', bg: MC.warnBg, fg: MC.warn),
            ]),
            SizedBox(
              height: 130,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: 10, children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, spacing: 4, children: [
                      Text('${perDay[i]}', style: mt(11, mBold)),
                      Container(
                        height: perDay[i] == 0 ? 8 : 80 * perDay[i] / top,
                        decoration: BoxDecoration(
                          color: perDay[i] == 0 ? MC.border : (perDay[i] == top ? MC.accent : MC.barLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Text(days[i], style: mt(11, mSemi, MC.muted)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        Text('By Service Type', style: mt(16, mXBold)),
        _breakdown(_byType(app, week)),
      ],
    );
  }
}

// ====================================================================== Overdue Flags
class OverdueFlagsScreen extends StatelessWidget {
  const OverdueFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final flags = app.overdueFlags;
    return MechPage(
      header: const MechHeader('Overdue Flags'),
      gap: 12,
      children: [
        flags.isEmpty
            ? const InfoBanner('No overdue components on your motorcycles.', icon: 'check')
            : InfoBanner(
                '${flags.length} component${flags.length == 1 ? '' : 's'} passed their service limit and need attention.',
                danger: true),
        for (final (m, s) in flags)
          MechCard(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
              Row(spacing: 12, children: [
                IconSquare(componentIconName(s.rule.componentKey), bg: MC.dangerBg, color: MC.danger),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                    Text(s.rule.componentName, style: mt(15, mXBold)),
                    Text(motoLine(app, m), style: mt(12, mMedium, MC.muted)),
                  ]),
                ),
                StatusChip.status(MaintenanceStatus.overdue),
              ]),
              const ProgressBar(1, color: MC.danger),
              Text(
                s.kmLeft(m.currentOdometer) < 0
                    ? 'Overdue by ${fmtKm(-s.kmLeft(m.currentOdometer))}'
                    : 'Time limit passed on ${fmtDate(s.nextDate)}',
                style: mt(12, mBold, MC.danger),
              ),
              MechButton('Inspect Now', height: 44, kind: MechButtonKind.soft, onTap: () async {
                await app.startJob(m, s.rule.componentName);
                if (context.mounted) {
                  Navigator.of(context).push(_r(InspectScreen(motorcycleId: m.motorcycleId, preselect: s.rule.componentKey)));
                }
              }),
            ]),
          ),
      ],
    );
  }
}

// ====================================================================== Services Completed
class ServicesCompletedScreen extends StatelessWidget {
  const ServicesCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.myServices;
    final t = today();
    final months = [
      for (var i = 0; i < 3; i++)
        (DateTime(t.year, t.month - i), app.servicesBetween(DateTime(t.year, t.month - i), DateTime(t.year, t.month - i + 1)).length),
    ];
    return MechPage(
      header: const MechHeader('Services Completed'),
      gap: 12,
      bottom: [
        MechButton('View Maintenance History', onTap: () => Navigator.of(context).push(_r(const MechHistoryScreen()))),
      ],
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: MC.gradient, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
            Text('Total services', style: mt(13, mMedium, MC.heroText)),
            Text('${all.length}', style: mt(40, mXBold, Colors.white, 1.15)),
            Text('Since you joined ${app.currentMechanic?.workshopName ?? 'MotorcycleCare'}', style: mt(12, mSemi, MC.heroText)),
          ]),
        ),
        Text('By Month', style: mt(16, mXBold)),
        _breakdown([for (final (d, n) in months) (fmtMonthYear(d), n)]),
      ],
    );
  }
}

// ====================================================================== This Month
class ThisMonthScreen extends StatelessWidget {
  const ThisMonthScreen({super.key});

  /// Monthly service target of the workshop.
  static const target = 80;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final month = app.thisMonth;
    final t = today();
    final daysInMonth = DateTime(t.year, t.month + 1, 0).day;
    final expected = target * t.day / daysInMonth;
    final onTrack = month.length >= expected * 0.9;
    final left = math.max(0, target - month.length);
    return MechPage(
      header: const MechHeader('This Month'),
      gap: 12,
      children: [
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
            Row(children: [
              Expanded(child: Text('Monthly target', style: mt(13, mSemi, MC.muted))),
              onTrack ? StatusChip.ok('On track') : const StatusChip('Behind', bg: MC.warnBg, fg: MC.warn),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, spacing: 6, children: [
              Text('${month.length}', style: mt(32, mXBold)),
              Text('/ $target services', style: mt(13, mSemi, MC.muted)),
            ]),
            ProgressBar(month.length / target),
            Text(left == 0 ? 'Target reached. Great work!' : '$left more services to reach your target.',
                style: mt(12, mMedium, MC.muted)),
          ]),
        ),
        Text('By Service Type', style: mt(16, mXBold)),
        _breakdown(_byType(app, month)),
      ],
    );
  }
}

// ====================================================================== Rating & Reviews
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final reviews = app.reviews;
    Widget stars(int n, double size) => Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
          for (var i = 1; i <= 5; i++) Icon(Icons.star_rounded, size: size, color: i <= n ? MC.warnBar : MC.border),
        ]);
    return MechPage(
      header: const MechHeader('Rating & Reviews'),
      gap: 12,
      children: [
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Row(spacing: 16, children: [
            Column(spacing: 4, children: [
              Text(reviews.isEmpty ? '–' : app.rating.toStringAsFixed(1), style: mt(40, mXBold, MC.text, 1.1)),
              stars(app.rating.round(), 14),
              Text('${reviews.length} review${reviews.length == 1 ? '' : 's'}', style: mt(11, mSemi, MC.muted)),
            ]),
            Expanded(
              child: Column(spacing: 6, children: [
                for (var s = 5; s >= 1; s--)
                  Builder(builder: (_) {
                    final pct = reviews.isEmpty ? 0.0 : reviews.where((r) => r.rating == s).length / reviews.length;
                    return Row(spacing: 8, children: [
                      Text('$s', style: mt(11, mBold, MC.muted)),
                      Expanded(child: ProgressBar(pct, color: MC.warnBar)),
                      SizedBox(
                          width: 32,
                          child: Text('${(pct * 100).round()}%', textAlign: TextAlign.right, style: mt(11, mSemi, MC.muted))),
                    ]);
                  }),
              ]),
            ),
          ]),
        ),
        Text('Owner Reviews', style: mt(16, mXBold)),
        if (reviews.isEmpty) MechCard(child: Text('No reviews yet.', style: mt(13, mMedium, MC.muted))),
        for (final r in reviews)
          MechCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
              Row(spacing: 10, children: [
                Avatar(initials(r.ownerName), size: 32, fontSize: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                    Text(r.ownerName, style: mt(13, mBold)),
                    Text(timeAgo(r.createdAt), style: mt(11, mMedium, MC.muted)),
                  ]),
                ),
                stars(r.rating, 14),
              ]),
              Text(r.comment, style: mt(12, mMedium, MC.text, 1.4)),
            ]),
          ),
      ],
    );
  }
}

// ====================================================================== Personal Information
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final UserAccount me = AppScope.read(context).currentUser!;
  late final _name = TextEditingController(text: me.fullName);
  late final _phone = TextEditingController(text: me.phone ?? '');
  late final _email = TextEditingController(text: me.email);
  late final _workshop = TextEditingController(text: switch (me) { Mechanic(:final workshopName) => workshopName ?? '', _ => '' });
  late final _id = TextEditingController(
      text: 'MC-${me.userId.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _workshop, _id]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AppScope.read(context)
        .updateMyProfile(fullName: _name.text, phone: _phone.text, workshopName: _workshop.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      mechSnack(context, 'Changes saved');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) => MechPage(
        header: const MechHeader('Personal Information'),
        bottom: [MechButton('Save Changes', busy: _busy, onTap: _save)],
        children: [
          Center(child: Avatar(initials(_name.text.isEmpty ? me.fullName : _name.text), size: 84, fontSize: 28)),
          if (_error != null) InfoBanner(_error!, danger: true),
          MechField('Full Name',
              child: MechInput(controller: _name, caps: TextCapitalization.words, onChanged: (_) => setState(() {}))),
          MechField('Mechanic ID', child: MechInput(controller: _id, readOnly: true)),
          MechField('Phone', child: MechInput(controller: _phone, hint: '+62 812-3456-7890', keyboardType: TextInputType.phone)),
          MechField('Email', helper: 'Contact the admin to change your email.', child: MechInput(controller: _email, readOnly: true)),
          MechField('Workshop', child: MechInput(controller: _workshop, caps: TextCapitalization.words)),
        ],
      );
}

// ====================================================================== Workshop
class WorkshopScreen extends StatelessWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.currentUser;
    if (me == null) return const SizedBox.shrink(); // signed out
    final w = app.workshop;
    final now = DateTime.now();
    final closes = int.tryParse((w?.closesAt ?? '').split(':').first);
    final open = closes != null && now.weekday != DateTime.sunday && now.hour >= 8 && now.hour < closes;
    return MechPage(
      header: const MechHeader('Workshop'),
      children: [
        MechCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(spacing: 8, children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: MC.gradient, borderRadius: BorderRadius.circular(20)),
              child: const AppIcon('store', color: Colors.white, size: 30),
            ),
            Text(app.currentMechanic?.workshopName ?? 'No workshop', style: mt(20, mXBold)),
            if (w != null)
              open
                  ? StatusChip.ok('Open now · until ${w.closesAt}')
                  : const StatusChip('Closed now', bg: MC.dangerBg, fg: MC.danger),
          ]),
        ),
        MechCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(spacing: 12, children: [
            KV('Address', w?.address ?? 'Not set'),
            KV('City', w?.city ?? 'Not set'),
            KV('Opening hours', w?.hours ?? 'Not set'),
            KV('Phone', w?.phone ?? 'Not set'),
            const KV('Your role', 'Mechanic'),
          ]),
        ),
        if (w == null) const InfoBanner('Workshop details are not registered yet. Ask the admin to add them.', icon: 'info'),
      ],
    );
  }
}

// ====================================================================== Help & Support
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const faqs = [
    ('How do I record a service?',
        'Search the motorcycle by plate number, inspect the components, then fill in the service details and save.'),
    ('Is the receipt required?',
        'No. Attaching a receipt is optional. You can upload JPG, PNG, WEBP or HEIC photos up to 5 MB, or skip this step.'),
    ('What if I entered the wrong data?',
        'Open Edit Details on the review screen, correct the highlighted fields and save again before submitting.'),
    ('Does the owner get notified?',
        "Yes. With Notify owner on, the owner's maintenance reminders are recalculated as soon as the record is saved. "
            "They show up as new reminders in the owner's app."),
  ];

  @override
  Widget build(BuildContext context) => MechPage(
        header: const MechHeader('Help & Support'),
        gap: 12,
        children: [
          for (final (q, a) in faqs)
            MechCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
                Text(q, style: mt(14, mBold)),
                Text(a, style: mt(12, mMedium, MC.muted, 1.45)),
              ]),
            ),
          const MechCard(
            radius: 20,
            padding: EdgeInsets.all(16),
            child: Column(spacing: 12, children: [
              KV('Email', 'support@motorcyclecare.app'),
              KV('Phone', '+62 21 5000 1234'),
              KV('Support hours', 'Mon–Fri · 08:00–18:00'),
            ]),
          ),
        ],
      );
}
