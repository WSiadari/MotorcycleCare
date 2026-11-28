import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Welcome screen with Log In and Create Account.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Hero (390 × 440 incl. status bar) and the status card overlapping its bottom edge.
          SizedBox(
            height: 412 + topInset,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 0, right: 0, top: 0, height: 396 + topInset, child: const _HeroBackground()),
              Positioned(
                left: 0,
                right: 0,
                top: topInset,
                bottom: 0,
                child: const Center(child: FittedBox(child: SizedBox(width: 390, height: 412, child: _HeroArt()))),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Service on time,\nevery kilometre.', style: ts(30, bold, AppColors.text, 1.2)),
              const SizedBox(height: 12),
              Text('Log your odometer, follow the service rules for your model, and get a reminder before a part wears out.',
                  style: ts(15, regular, AppColors.muted, 1.47)),
              const SizedBox(height: 48),
              AppButton('Get started',
                  height: 52,
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Already have an account?', style: ts(14, regular, AppColors.muted)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Log in', style: ts(14, bold, AppColors.accentStrong)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        color: AppColors.accent,
        child: Stack(children: [
          Positioned(
            left: -170,
            top: -210,
            child: Container(
              width: 440,
              height: 440,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Wordmark, gauge, odometer drum, reminder pill and status card.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: 24,
        top: 24,
        child: Row(spacing: 8, children: [
          const AppIcon('bike', color: Colors.white, size: 20),
          Text('MotorcycleCare', style: ts(15, bold, Colors.white)),
        ]),
      ),
      const Positioned(left: 55, top: 78, width: 280, height: 170, child: CustomPaint(painter: _GaugePainter())),
      Positioned(left: 289, top: 242, child: Text('SERVICE', style: ts(11, semiBold, Colors.white))),
      Positioned(
        left: 100,
        top: 256,
        width: 191,
        child: Column(spacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            Row(spacing: 4, children: [
              for (final (i, d) in '08450'.split('').indexed)
                Container(
                  width: 28,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 4 ? Colors.white : AppColors.text,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(d, style: ts(20, bold, i == 4 ? AppColors.text : Colors.white)),
                ),
            ]),
            Text('km', style: ts(13, semiBold, Colors.white)),
          ]),
          Text('88% to the next engine oil service', style: ts(12, medium, Colors.white)),
        ]),
      ),
      Positioned(
        left: 196,
        top: 58,
        child: Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
              const AppIcon('bell', color: AppColors.warnText, size: 14),
              Text('Engine oil · 250 km left', style: ts(12, semiBold, AppColors.warnText)),
            ]),
          ),
        ),
      ),
      Positioned(
        left: 24,
        top: 352,
        width: 275,
        child: Transform.rotate(
          angle: -0.03,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x1A1E1A17), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Row(spacing: 12, children: [
              const IconBox('drop', bg: AppColors.dangerSoft, color: AppColors.dangerIcon),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text('Gear Oil', style: ts(14, semiBold)),
                  Text('Was due at 8,200 km', style: ts(11, regular, AppColors.muted)),
                ]),
              ),
              const StatusBadge(MaintenanceStatus.overdue),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// Semicircle gauge at 88 %, with ticks, needle and the "SERVICE" end marker.
class _GaugePainter extends CustomPainter {
  const _GaugePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const c = Offset(140, 150);
    const r = 120.0;
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint stroke(Color color, double w) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, stroke(Colors.white.withValues(alpha: 0.28), 16));
    canvas.drawArc(rect, math.pi, math.pi * 0.88, false, stroke(Colors.white, 16));

    for (var i = 0; i <= 10; i++) {
      final a = math.pi + math.pi * i / 10;
      final major = i == 0 || i == 5 || i == 10;
      final inner = major ? 76.0 : 80.0;
      const outer = 90.0;
      canvas.drawLine(
        c + Offset(math.cos(a) * inner, math.sin(a) * inner),
        c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        stroke(Colors.white.withValues(alpha: major ? 0.9 : 0.55), major ? 3 : 2),
      );
    }

    // needle at 88 %
    const na = math.pi + math.pi * 0.88;
    canvas.drawLine(c, c + Offset(math.cos(na) * 84, math.sin(na) * 84), stroke(Colors.white, 4));
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 4, Paint()..color = AppColors.accentStrong);

    // service point at the end of the arc
    const end = Offset(260, 150);
    canvas.drawCircle(end, 10, Paint()..color = AppColors.text);
    canvas.drawCircle(end, 10, stroke(Colors.white, 3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
