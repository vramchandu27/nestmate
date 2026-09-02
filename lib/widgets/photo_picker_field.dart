import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_theme.dart';
import '../config/localization/app_localizations.dart';
import 'full_screen_network_photo.dart';

enum _PickAction { camera, gallery, remove }

/// A tappable box for attaching a real photo — camera or gallery — with a
/// thumbnail preview once one is picked. The picked [File] only lives in
/// the calling screen's local state until the screen itself uploads it and
/// saves the resulting URL; pass that URL back in as [existingUrl] on a
/// later visit so a saved photo previews correctly without needing to be
/// re-picked.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.label,
    required this.file,
    required this.onChanged,
    this.existingUrl,
    this.height = 120,
    this.previewHeight,
    this.placeholderGradient,
    this.placeholderIconColor = AppTheme.textLight,
    this.placeholderTextColor = AppTheme.textMedium,
  });

  final String label;
  final File? file;
  final ValueChanged<File?> onChanged;

  /// A previously-uploaded photo's URL — shown as the preview whenever no
  /// new [file] has been picked yet in this session (e.g. re-opening a
  /// form that already has a saved photo on record).
  final String? existingUrl;

  /// Height of the empty tap-to-upload box.
  final double height;

  /// Height once a photo is actually picked — bigger than [height] by
  /// default so the user can clearly see what they uploaded, not just a
  /// thumbnail-sized strip.
  final double? previewHeight;

  /// Optional branded background for the empty-state box (e.g. the block
  /// setup screen's blue gradient) instead of the default plain card.
  final Gradient? placeholderGradient;
  final Color placeholderIconColor;
  final Color placeholderTextColor;

  Future<void> _pick(BuildContext context) async {
    final action = await showModalBottomSheet<_PickAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppTheme.primary,
                ),
                title: Text(AppLocalizations.t('takePhoto')),
                onTap: () => Navigator.pop(sheetContext, _PickAction.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.primary,
                ),
                title: Text(AppLocalizations.t('chooseFromGallery')),
                onTap: () => Navigator.pop(sheetContext, _PickAction.gallery),
              ),
              if (file != null || existingUrl != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.error,
                  ),
                  title: Text(
                    AppLocalizations.t('removePhoto'),
                    style: const TextStyle(color: AppTheme.error),
                  ),
                  onTap: () => Navigator.pop(sheetContext, _PickAction.remove),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    if (action == _PickAction.remove) {
      onChanged(null);
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: action == _PickAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
        // Camera photos default to full sensor resolution (often 4000px+
        // on a side) — decoding that into memory for the preview/full-
        // screen viewer can crash a debug build. 1600px is plenty for a
        // phone-screen viewer and keeps Storage uploads small too.
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) onChanged(File(picked.path));
    } catch (e) {
      debugPrint('PhotoPickerField pick failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('photoPickFailed')),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (file != null) return _preview(context);
    if (existingUrl != null) return _networkPreview(context);
    return GestureDetector(
      onTap: () => _pick(context),
      child: _placeholder(),
    );
  }

  Widget _preview(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showFullScreen(context),
            child: Container(
              height: previewHeight ?? height + 100,
              width: double.infinity,
              color: AppTheme.cardBackground,
              // Contain (not cover) so the whole picked photo is always
              // visible — no cropping, even if its aspect ratio doesn't
              // match this box.
              child: Image.file(file!, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _pick(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkPreview(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FullScreenNetworkPhoto(url: existingUrl!),
              ),
            ),
            child: Container(
              height: previewHeight ?? height + 100,
              width: double.infinity,
              color: AppTheme.cardBackground,
              child: Image.network(
                existingUrl!,
                fit: BoxFit.contain,
                cacheWidth: 800,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.textLight,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _pick(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FullScreenPhotoView(file: file!)),
    );
  }

  Widget _placeholder() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: placeholderGradient == null ? AppTheme.cardBackground : null,
        gradient: placeholderGradient,
        borderRadius: BorderRadius.circular(14),
        border: placeholderGradient == null
            ? Border.all(color: const Color(0xFFCDDCF3), width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_rounded,
            color: placeholderIconColor,
            size: 26,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: placeholderTextColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom view of a picked photo — reached by tapping
/// its thumbnail in [PhotoPickerField].
class _FullScreenPhotoView extends StatelessWidget {
  const _FullScreenPhotoView({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.file(file),
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
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
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
