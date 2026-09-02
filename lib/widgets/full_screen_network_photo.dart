import 'package:flutter/material.dart';

/// Full-screen view of a photo already uploaded to Storage — the
/// network-image counterpart to [PhotoPickerField]'s own full-screen
/// viewer for a locally-picked [File], used wherever a previously-uploaded
/// photo (an issue report, a payment screenshot) needs the same viewer.
///
/// Deliberately not wrapped in an [InteractiveViewer] — on at least one
/// test device, InteractiveViewer around a just-decoded Storage image
/// reliably tore down the Activity/Surface at the OS level (no Dart
/// exception, just the app dropping back to the login screen).
class FullScreenNetworkPhoto extends StatelessWidget {
  const FullScreenNetworkPhoto({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.network(
              url,
              cacheWidth: 2000,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
