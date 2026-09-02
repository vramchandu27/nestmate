import 'package:flutter/material.dart';

/// A 👋 emoji that continuously waves back and forth — used next to "Hi"
/// greetings on the dashboard/home screens instead of a static emoji.
class WavingHand extends StatefulWidget {
  const WavingHand({super.key, this.size = 13});

  final double size;

  @override
  State<WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<WavingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);
  late final Animation<double> _angle = Tween<double>(
    begin: -0.35,
    end: 0.35,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) => Transform.rotate(
        angle: _angle.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: Text('👋', style: TextStyle(fontSize: widget.size)),
    );
  }
}
