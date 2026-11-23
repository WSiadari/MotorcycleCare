import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';

// ------------------------------------------------------------------ text
const regular = FontWeight.w400;
const medium = FontWeight.w500;
const semiBold = FontWeight.w600;
const bold = FontWeight.w700;

TextStyle ts(double size, FontWeight weight, [Color color = AppColors.text, double? height]) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color, height: height);

// ------------------------------------------------------------------ status
class HealthStyle {
  const HealthStyle(this.label, this.soft, this.text, this.bar, this.dot, this.iconBg, this.icon);

  final String label;
  final Color soft, text, bar, dot, iconBg, icon;

  static HealthStyle of(Health h) => switch (h) {
        Health.overdue => const HealthStyle('Overdue', AppColors.dangerSoft, AppColors.danger, AppColors.danger,
            AppColors.danger, AppColors.dangerSoft, AppColors.dangerIcon),
        Health.dueSoon => const HealthStyle('Due soon', AppColors.warnSoft, AppColors.warnText, AppColors.warn,
            AppColors.warn, AppColors.warnSoft, AppColors.warnText),
        Health.onTrack => const HealthStyle('On track', AppColors.successSoft, AppColors.successText,
            AppColors.success, AppColors.success, AppColors.accentSoft, AppColors.accent),
      };

  /// Colour of a "% used" label (on-track uses the green text colour).
  Color get percent => text;
}

/// "Badge / Overdue · Due soon · On track"
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.health, {super.key});

  final Health health;

  @override
  Widget build(BuildContext context) {
    final s = HealthStyle.of(health);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: s.soft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: s.dot, shape: BoxShape.circle)),
        Text(s.label, style: ts(12, medium, s.text)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ boxes
class IconBox extends StatelessWidget {
  const IconBox(
    this.icon, {
    super.key,
    this.size = 36,
    this.radius = 10,
    this.iconSize = 18,
    this.bg = AppColors.accentSoft,
    this.color = AppColors.accent,
  });

  final String icon;
  final double size, radius, iconSize;
  final Color bg, color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: AppIcon(icon, color: color, size: iconSize),
      );
}

/// White card with the light border used everywhere in the design.
class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    this.color = AppColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius, borderWidth;
  final Color borderColor, color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderWidth == 0 ? BorderSide.none : BorderSide(color: borderColor, width: borderWidth),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Coloured note with an icon (Info Note, banners).
class Note extends StatelessWidget {
  const Note(
    this.text, {
    super.key,
    this.icon = 'info',
    this.bg = AppColors.accentSoft,
    this.iconColor = AppColors.accent,
    this.textColor = AppColors.accentStrong,
    this.radius = 14,
  });

  final String text, icon;
  final Color bg, iconColor, textColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
          AppIcon(icon, color: iconColor, size: 18),
          Expanded(child: Text(text, style: ts(13, medium, textColor, 1.38))),
        ]),
      );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Note(text,
      icon: 'alert', bg: AppColors.dangerSoft, iconColor: AppColors.dangerIcon, textColor: AppColors.danger, radius: 12);
}

class SuccessBanner extends StatelessWidget {
  const SuccessBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Note(text,
      icon: 'check',
      bg: AppColors.successSoft,
      iconColor: AppColors.successIcon,
      textColor: AppColors.successText,
      radius: 12);
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.percent, required this.color, this.height = 7});

  final double percent;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.track)),
            FractionallySizedBox(
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
              ),
            ),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ buttons
enum ButtonKind { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = ButtonKind.primary,
    this.height = 48,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (kind) {
      ButtonKind.primary => (AppColors.accentStrong, Colors.white, BorderSide.none),
      ButtonKind.secondary => (AppColors.surface, AppColors.text, const BorderSide(color: AppColors.border, width: 1.5)),
      ButtonKind.ghost => (AppColors.accentSoft, AppColors.accentStrong, BorderSide.none),
      ButtonKind.danger => (AppColors.dangerSoft, AppColors.danger, BorderSide.none),
    };
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: side),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                  : Text(label, style: ts(15, semiBold, fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40×40 white square button with an icon (Back, Bell, Log Out, Close).
class SquareButton extends StatelessWidget {
  const SquareButton(this.icon,
      {super.key, required this.onTap, this.iconSize = 18, this.badge = 0, this.tooltip});

  final String icon;
  final VoidCallback onTap;
  final double iconSize;
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(child: AppIcon(icon, color: AppColors.text, size: iconSize)),
        ),
      ),
    );
    final withBadge = badge <= 0
        ? button
        : Stack(clipBehavior: Clip.none, children: [
            button,
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: Text('$badge', style: ts(11, bold, Colors.white)),
              ),
            ),
          ]);
    return tooltip == null ? withBadge : Tooltip(message: tooltip!, child: withBadge);
  }
}

/// "Top Bar": back button, title, optional actions.
class TopBar extends StatelessWidget {
  const TopBar(this.title, {super.key, this.back = true, this.onBack, this.actions = const []});

  final String title;
  final bool back;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(spacing: 14, children: [
      if (back)
        SquareButton('chevL',
            iconSize: 20, tooltip: 'Back', onTap: onBack ?? () => Navigator.of(context).maybePop()),
      Expanded(child: Text(title, style: ts(20, bold), overflow: TextOverflow.ellipsis)),
      ...actions,
    ]);
  }
}

/// "Vehicle Info" / "Vehicle Chip": Honda Vario 160 · B 4521 KXR · 8,450 km
class VehicleChip extends StatelessWidget {
  const VehicleChip(this.text, {super.key, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(spacing: 10, children: [
            const AppIcon('bike', color: AppColors.accent, size: 18),
            Expanded(child: Text(text, style: ts(13, medium), overflow: TextOverflow.ellipsis)),
            if (onTap != null) const AppIcon('pencil', color: AppColors.muted, size: 15),
          ]),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.link, this.onLink});

  final String title;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: ts(15, semiBold))),
        if (link != null)
          GestureDetector(
            onTap: onLink,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(link!, style: ts(13, semiBold, AppColors.accentStrong)),
            ),
          ),
      ]);
}

/// Label/value row inside cards ("Interval · Every 4,000 km or 6 months").
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor = AppColors.text});

  final String label, value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
        Text(label, style: ts(13, regular, AppColors.muted)),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: ts(13, semiBold, valueColor))),
      ]);
}

// ------------------------------------------------------------------ form fields
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: ts(13, semiBold));
}

class Helper extends StatelessWidget {
  const Helper(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: ts(12, regular, AppColors.muted, 1.3));
}

class ErrorLine extends StatelessWidget {
  const ErrorLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
        const Padding(padding: EdgeInsets.only(top: 1), child: AppIcon('alert', color: AppColors.dangerIcon, size: 14)),
        Expanded(child: Text(text, style: ts(12, medium, AppColors.danger, 1.3))),
      ]);
}

/// Text input styled like "Input / …" in the design (white, 1.5 px border, radius 12).
class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    this.controller,
    this.icon,
    this.hint,
    this.suffix,
    this.hasError = false,
    this.keyboardType,
    this.obscure = false,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.trailing,
    this.textInputAction,
    this.autofillHints,
    this.fontWeight = semiBold,
  });

  final TextEditingController? controller;
  final String? icon, hint, suffix;
  final bool hasError, obscure, autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines, minLines;
  final Widget? trailing;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: 1.5));
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      style: ts(15, fontWeight),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        hintText: hint,
        hintStyle: ts(15, regular, AppColors.muted),
        contentPadding: EdgeInsets.fromLTRB(icon == null ? 14 : 0, 14, 14, 14),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: AppIcon(icon!, color: hasError ? AppColors.dangerIcon : AppColors.muted, size: 16),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: trailing ??
            (suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 14, left: 8),
                    child: Text(suffix!, style: ts(14, medium, AppColors.muted)),
                  )),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: b(hasError ? AppColors.danger : AppColors.borderStrong),
        focusedBorder: b(hasError ? AppColors.danger : AppColors.accent),
        border: b(AppColors.borderStrong),
      ),
    );
  }
}

/// A tappable field that looks like an input (date, select).
class InputBox extends StatelessWidget {
  const InputBox({super.key, required this.child, this.onTap, this.focused = false, this.hasError = false,
      this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13)});

  final Widget child;
  final VoidCallback? onTap;
  final bool focused, hasError;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? AppColors.danger : (focused ? AppColors.accent : AppColors.borderStrong);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

// ------------------------------------------------------------------ page + sheet
/// Standard page: background, safe area, 20 px padding, 16 px gap between blocks.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.gap = 16,
    this.padding = const EdgeInsets.all(20),
    this.onRefresh,
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry padding;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: children),
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: onRefresh == null
            ? scroll
            : RefreshIndicator(color: AppColors.accent, onRefresh: onRefresh!, child: scroll),
      ),
    );
  }
}

/// Bottom sheet with the "Sheet Header" (title + close button).
Future<T?> showAppSheet<T>(BuildContext context,
    {required String title, required List<Widget> Function(BuildContext sheetContext) children, double gap = 12}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: [
          Row(spacing: 12, children: [
            Expanded(child: Text(title, style: ts(20, bold))),
            SquareButton('x', tooltip: 'Close', onTap: () => Navigator.of(sheetContext).pop()),
          ]),
          ...children(sheetContext),
        ]),
      ),
    ),
  );
}

/// Small spinner used while a screen loads data.
class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key});

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
}
