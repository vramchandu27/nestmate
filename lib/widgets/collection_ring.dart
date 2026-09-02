import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The circular collection-progress ring used on the admin dashboard:
/// percent value, big center label, small center sub-label.
class CollectionRing extends StatelessWidget {
  const CollectionRing({
    super.key,
    required this.percent,
    required this.centerLabel,
    required this.centerSubLabel,
    this.size = 100,
    this.strokeWidth = 9,
  });

  final double percent;
  final String centerLabel;
  final String centerSubLabel;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 1),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: AppTheme.accentBlue,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                centerLabel,
                style: AppTheme.displayStyle(
                  context,
                  size: 22,
                  weight: FontWeight.w800,
                ),
              ),
              Text(
                centerSubLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLight,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
