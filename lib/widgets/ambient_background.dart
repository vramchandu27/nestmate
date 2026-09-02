import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Wraps [child] with the same soft ambient glow used behind the
/// onboarding screens (Login/OTP/Welcome/Signup) — two low-alpha
/// decorative circles behind the content, so the flat page background
/// has some life instead of reading as a single dull slab of color.
/// Purely decorative: sits behind [child] and ignores pointer events, so
/// it never blocks taps or scrolling.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: -60,
          right: -60,
          child: IgnorePointer(child: _Glow(size: 220, alpha: 0.05)),
        ),
        const Positioned(
          bottom: -80,
          left: -70,
          child: IgnorePointer(child: _Glow(size: 260, alpha: 0.045)),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withValues(alpha: alpha),
      ),
    );
  }
}
