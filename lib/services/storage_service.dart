import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Thin wrapper around Firebase Storage — every real photo in the app
/// (issue reports, payment screenshots, the building cover photo, expense
/// receipts) goes through this one upload method.
class StorageService {
  final _storage = FirebaseStorage.instance;

  /// Uploads [file] to Storage at [basePath] (no extension) and returns its
  /// public download URL. The real file extension and a matching
  /// Content-Type are derived from [file] itself rather than assumed —
  /// camera photos are JPEG, but a gallery-picked screenshot is commonly
  /// PNG, and serving a real PNG under an `image/jpeg` Content-Type (which
  /// is what happens if every upload is just hardcoded to `.jpg`) crashed
  /// some devices' hardware image decoders on load. A repeat upload to the
  /// same [basePath] simply overwrites the previous photo there.
  Future<String> uploadPhoto({
    required String basePath,
    required File file,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final ref = _storage.ref('$basePath.$ext');
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
