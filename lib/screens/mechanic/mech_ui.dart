import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../widgets/app_icon.dart';

/// Colors of the mechanic app.
class MC {
  MC._();

  static const bg = Color(0xFFFFF9F4);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFF0E4DA);
  static const text = Color(0xFF201A16);
  static const muted = Color(0xFF7A6E66);
  static const faint = Color(0xFF9A8D84);
  static const hint = Color(0xFFA99D94);
  static const accent = Color(0xFFFF6B1A);
  static const accentText = Color(0xFFEA580C);
  static const soft = Color(0xFFFFF7ED);
  static const softBorder = Color(0xFFFFEDD5);
  static const heroText = Color(0xFFFFE8D6);
  static const gradA = Color(0xFFFF8A3D);
  static const okBg = Color(0xFFDCFCE7);
  static const ok = Color(0xFF15803D);
  static const okBar = Color(0xFF22C55E);
  static const warnBg = Color(0xFFFEF3C7);
  static const warn = Color(0xFFB45309);
  static const warnBar = Color(0xFFF59E0B);
  static const dangerBg = Color(0xFFFEE2E2);
  static const danger = Color(0xFFDC2626);
  static const barLight = Color(0xFFFDBA74);

  static const gradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [gradA, accentText]);
}

const mMedium = FontWeight.w500;
const mSemi = FontWeight.w600;
const mBold = FontWeight.w700;
const mXBold = FontWeight.w800;

TextStyle mt(double size, FontWeight w, [Color c = MC.text, double? h]) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: h);

// ------------------------------------------------------------------ page
/// Screen with a header, scrolling content and buttons pinned at the bottom.
class MechPage extends StatelessWidget {
  const MechPage({super.key, this.header, required this.children, this.bottom = const [], this.gap = 14, this.onRefresh});

  final Widget? header;
  final List<Widget> children;
  final List<Widget> bottom;
  final double gap;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: children),
      ],
    );
    return Scaffold(
      backgroundColor: MC.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (header != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 10), child: header),
          Expanded(
            child: onRefresh == null ? scroll : RefreshIndicator(color: MC.accent, onRefresh: onRefresh!, child: scroll),
          ),
          if (bottom.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: bottom),
            ),
        ]),
      ),
    );
  }
}

/// Header with a back button and title.
class MechHeader extends StatelessWidget {
  const MechHeader(this.title, {super.key, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(spacing: 12, children: [
        MechIconButton('chevL', size: 40, onTap: onBack ?? () => Navigator.of(context).maybePop(), tooltip: 'Back'),
        Expanded(child: Text(title, style: mt(20, mXBold), overflow: TextOverflow.ellipsis)),
        if (trailing != null) trailing!,
      ]);
}

/// Header with a title only (bottom navigation tabs).
class MechTabHeader extends StatelessWidget {
  const MechTabHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 41, child: Align(alignment: Alignment.centerLeft, child: Text(title, style: mt(20, mXBold))));
}

class MechIconButton extends StatelessWidget {
  const MechIconButton(this.icon, {super.key, required this.onTap, this.size = 44, this.dot = false, this.tooltip});

  final String icon;
  final VoidCallback onTap;
  final double size;
  final bool dot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: MC.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: MC.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(alignment: Alignment.center, children: [
                AppIcon(icon, color: MC.text, size: 20),
                if (dot)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: MC.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------------ buttons
enum MechButtonKind { primary, soft, danger }

class MechButton extends StatelessWidget {
  const MechButton(this.label, {super.key, required this.onTap, this.kind = MechButtonKind.primary, this.icon, this.busy = false, this.height = 54});

  final String label;
  final VoidCallback? onTap;
  final MechButtonKind kind;
  final String? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (kind) {
      MechButtonKind.primary => (MC.accent, Colors.white, BorderSide.none),
      MechButtonKind.soft => (MC.soft, MC.accentText, const BorderSide(color: MC.softBorder, width: 1.5)),
      MechButtonKind.danger => (MC.dangerBg, MC.danger, BorderSide.none),
    };
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: side),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: height,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 8, children: [
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icon != null)
                AppIcon(icon!, color: fg, size: 18),
              Text(label, style: mt(height < 50 ? 13 : 15, mBold, fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small rounded pill button ("View Jobs", "Receipt", demo chips).
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onTap, this.icon, this.white = false});

  final String label;
  final VoidCallback onTap;
  final String? icon;
  final bool white;

  @override
  Widget build(BuildContext context) => Material(
        color: white ? Colors.white : MC.soft,
        shape: StadiumBorder(side: white ? BorderSide.none : const BorderSide(color: MC.softBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: white ? 16 : 12, vertical: white ? 9 : 7),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
              if (icon != null) AppIcon(icon!, color: MC.accentText, size: 14),
              Text(label, style: mt(white ? 12 : 11, mBold, MC.accentText)),
            ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------ boxes
class MechCard extends StatelessWidget {
  const MechCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 18, this.onTap, this.highlight = false, this.color = MC.surface, this.borderColor = MC.border});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool highlight;
  final Color color, borderColor;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: highlight ? const BorderSide(color: MC.accent, width: 2) : BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, {super.key, this.size = 40, this.radius = 14, this.iconSize = 20, this.bg = MC.soft, this.color = MC.accentText, this.border = false});

  final String icon;
  final double size, radius, iconSize;
  final Color bg, color;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(radius), border: border ? Border.all(color: MC.softBorder) : null),
        child: AppIcon(icon, color: color, size: iconSize),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 48, this.fontSize = 16});

  final String initials;
  final double size, fontSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(gradient: MC.gradient, shape: BoxShape.circle),
        child: Text(initials, style: mt(fontSize, mXBold, Colors.white)),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.bg, required this.fg, this.dot = true});

  factory StatusChip.status(MaintenanceStatus h) => switch (h) {
        MaintenanceStatus.overdue => const StatusChip('Overdue', bg: MC.dangerBg, fg: MC.danger),
        MaintenanceStatus.dueSoon => const StatusChip('Due Soon', bg: MC.warnBg, fg: MC.warn),
        MaintenanceStatus.onTrack => const StatusChip('OK', bg: MC.okBg, fg: MC.ok),
      };

  factory StatusChip.ok(String label) => StatusChip(label, bg: MC.okBg, fg: MC.ok);

  final String label;
  final Color bg, fg;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
          if (dot) Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          Text(label, style: mt(11, mBold, fg)),
        ]),
      );
}

Color statusBar(MaintenanceStatus h) => switch (h) {
      MaintenanceStatus.overdue => MC.danger,
      MaintenanceStatus.dueSoon => MC.warnBar,
      MaintenanceStatus.onTrack => MC.okBar,
    };

/// Motorcycle pill: Honda Vario 160 · B 4521 KXR
class MotoPill extends StatelessWidget {
  const MotoPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: MC.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: MC.softBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
            const AppIcon('bike', color: MC.accentText, size: 16),
            Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: mt(12, mBold, MC.accentText))),
          ]),
        ),
      );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.danger = false, this.icon = 'alert'});

  final String text, icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: danger ? MC.dangerBg : MC.soft,
          borderRadius: BorderRadius.circular(16),
          border: danger ? null : Border.all(color: MC.softBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
          AppIcon(icon, color: danger ? MC.danger : MC.accentText, size: 18),
          Expanded(child: Text(text, style: mt(12, mSemi, danger ? MC.danger : MC.accentText, 1.4))),
        ]),
      );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.fraction, {super.key, this.color = MC.accent, this.height = 6});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: height,
          color: MC.border,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: fraction.clamp(0, 1).toDouble(), child: Container(color: color)),
        ),
      );
}

/// Stat tile: big number and label.
class StatTile extends StatelessWidget {
  const StatTile(this.value, this.label, {super.key, this.valueColor = MC.text, this.highlight = false, this.onTap});

  final String value, label;
  final Color valueColor;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: MechCard(
          radius: 16,
          highlight: highlight,
          padding: const EdgeInsets.all(12),
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
            Text(value, style: mt(24, mXBold, valueColor)),
            Text(label, style: mt(11, mSemi, MC.muted)),
          ]),
        ),
      );
}

class KV extends StatelessWidget {
  const KV(this.label, this.value, {super.key, this.valueColor = MC.text});

  final String label, value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
        Text(label, style: mt(12, mMedium, MC.muted)),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: mt(13, mBold, valueColor))),
      ]);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.link, this.onLink});

  final String title;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: mt(16, mXBold))),
        if (link != null)
          GestureDetector(
            onTap: onLink,
            behavior: HitTestBehavior.opaque,
            child: Padding(padding: const EdgeInsets.all(4), child: Text(link!, style: mt(12, mBold, MC.accentText))),
          ),
      ]);
}

/// List row with an icon square, title, subtitle and a trailing widget.
class MechRow extends StatelessWidget {
  const MechRow({super.key, required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap, this.highlight = false, this.extra, this.titleSize = 14});

  final String icon, title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlight;
  final String? extra;
  final double titleSize;

  @override
  Widget build(BuildContext context) => MechCard(
        highlight: highlight,
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(spacing: 12, children: [
          IconSquare(icon),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text(title, style: mt(titleSize, mBold)),
              Text(subtitle, style: mt(12, mMedium, MC.muted)),
              if (extra != null) Text(extra!, style: mt(11, mSemi, MC.faint)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

// ------------------------------------------------------------------ form
class MechField extends StatelessWidget {
  const MechField(this.label, {super.key, required this.child, this.helper, this.error});

  final String label;
  final Widget child;
  final String? helper, error;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
        Text(label, style: mt(12, mMedium, MC.muted)),
        child,
        if (error != null)
          Text(error!, style: mt(11, mSemi, MC.danger))
        else if (helper != null)
          Text(helper!, style: mt(11, mMedium, MC.muted)),
      ]);
}

class MechInput extends StatelessWidget {
  const MechInput({super.key, required this.controller, this.hint, this.icon, this.keyboardType, this.maxLines = 1, this.minLines, this.onChanged, this.onSubmitted, this.error = false, this.suffix, this.digitsOnly = false, this.caps = TextCapitalization.none, this.readOnly = false, this.focused = false});

  final TextEditingController controller;
  final String? hint, icon, suffix;
  final TextInputType? keyboardType;
  final int? maxLines, minLines;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool error, digitsOnly, readOnly, focused;
  final TextCapitalization caps;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: caps,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)] : null,
      style: mt(14, mSemi, readOnly ? MC.muted : MC.text, 1.4),
      cursorColor: MC.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: MC.surface,
        hintText: hint,
        hintStyle: mt(14, mSemi, MC.hint),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines == 1 ? 16 : 14),
        prefixIcon: icon == null
            ? null
            : Padding(padding: const EdgeInsets.only(left: 16, right: 10), child: AppIcon(icon!, color: MC.muted, size: 18)),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixText: suffix,
        suffixStyle: mt(14, mSemi, MC.muted),
        enabledBorder: b(error ? MC.danger : (focused ? MC.accent : MC.border), error || focused ? 1.5 : 1),
        focusedBorder: b(error ? MC.danger : MC.accent, 1.5),
        disabledBorder: b(MC.border, 1),
      ),
    );
  }
}

/// Input that opens a picker sheet.
class SelectBox extends StatelessWidget {
  const SelectBox({super.key, required this.value, required this.placeholder, required this.onTap, this.icon, this.error = false, this.enabled = true});

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? icon;
  final bool error, enabled;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.55,
        child: MechCard(
          radius: 14,
          borderColor: error ? MC.danger : MC.border,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          onTap: enabled ? onTap : null,
          child: Row(spacing: 10, children: [
            if (icon != null) AppIcon(icon!, color: MC.muted, size: 18),
            Expanded(
              child: Text(value ?? placeholder,
                  overflow: TextOverflow.ellipsis, style: mt(14, mSemi, value == null ? MC.hint : MC.text)),
            ),
            const AppIcon('chevD', color: MC.muted, size: 16),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ sheet
/// Bottom sheet with grabber, title and close button.
Future<T?> showMechSheet<T>(BuildContext context, {required String title, required List<Widget> Function(BuildContext) children}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [
            Center(
              child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: MC.border, borderRadius: BorderRadius.circular(2))),
            ),
            Row(children: [
              Expanded(child: Text(title, style: mt(18, mXBold))),
              Material(
                color: MC.soft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: MC.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(sheet).pop(),
                  child: const SizedBox(width: 36, height: 36, child: Center(child: AppIcon('x', color: MC.text, size: 18))),
                ),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: children(sheet)),
          ]),
        ),
      ),
    ),
  );
}

class SheetOption extends StatelessWidget {
  const SheetOption(this.title, {super.key, this.subtitle, required this.onTap, this.icon, this.selected = false});

  final String title;
  final String? subtitle, icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => MechCard(
        radius: 16,
        highlight: selected,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(spacing: 12, children: [
          if (icon != null) IconSquare(icon!, size: 36, radius: 12, iconSize: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text(title, style: mt(14, mBold)),
              if (subtitle != null) Text(subtitle!, style: mt(12, mMedium, MC.muted)),
            ]),
          ),
          if (selected) const AppIcon('check', color: MC.accent, size: 18) else const AppIcon('chevR', color: MC.muted, size: 18),
        ]),
      );
}

void mechSnack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
