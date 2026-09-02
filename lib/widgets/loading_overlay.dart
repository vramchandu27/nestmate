import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Shows a full-screen, opaque loading page over everything while [action]
/// runs, then removes it automatically. Used instead of swapping a
/// button's own label for a spinner — pressing the action reads as
/// "the app is taking you somewhere" (its own transitional screen) rather
/// than "this button is busy".
Future<T> withLoadingOverlay<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final overlayState = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(builder: (_) => const _LoadingPage());
  overlayState.insert(entry);
  try {
    return await action();
  } finally {
    entry.remove();
  }
}

/// A `Navigator.push*` call kicks off its own slide transition and returns
/// immediately — it does not wait for that animation to finish. Calling
/// this (and awaiting it) right after navigating, while still inside a
/// [withLoadingOverlay] action, keeps the overlay up until the transition
/// has actually settled — otherwise the overlay is torn down the instant
/// the push is *requested*, exposing the screen underneath sliding away
/// mid-transition. Matches Material's default route transition duration.
Future<void> awaitRouteTransition() =>
    Future.delayed(const Duration(milliseconds: 300));

class _LoadingPage extends StatefulWidget {
  const _LoadingPage();

  @override
  State<_LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<_LoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(
    begin: 0.88,
    end: 1.08,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppTheme.background,
        child: Center(
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Text('🏡', style: TextStyle(fontSize: 30)),
            ),
          ),
        ),
      ),
    );
  }
}
