import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_theme.dart';
import '../config/localization/app_localizations.dart';

enum _PickAction { camera, gallery, remove }

/// A circular profile photo — shows the uploaded photo, or an
/// initial-letter fallback when there isn't one — with a small edit badge
/// that opens the same camera/gallery/remove sheet [PhotoPickerField] uses
/// elsewhere in the app, sized and shaped for an avatar instead of a
/// banner. [onPicked] receives the picked [File], or null if the user chose
/// "remove photo".
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.photoUrl,
    required this.initial,
    required this.onPicked,
    this.radius = 44,
    this.isLoading = false,
  });

  final String? photoUrl;
  final String initial;
  final ValueChanged<File?> onPicked;
  final double radius;
  final bool isLoading;

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
              if (photoUrl != null)
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
      onPicked(null);
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: action == _PickAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) onPicked(File(picked.path));
    } catch (e) {
      debugPrint('AvatarPicker pick failed: $e');
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
    return GestureDetector(
      onTap: isLoading ? null : () => _pick(context),
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppTheme.primary,
            backgroundImage: photoUrl != null
                ? NetworkImage(photoUrl!)
                : null,
            child: photoUrl == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: radius * 0.7,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
