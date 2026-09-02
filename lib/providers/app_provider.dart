import 'package:flutter/material.dart';
import '../config/localization/app_localizations.dart';
import '../models/role.dart';

/// Provider class for managing global app state
class AppProvider extends ChangeNotifier {
  // Language
  AppLanguage _language = AppLanguage.english;

  // User authentication state
  UserRole _userRole = UserRole.none;
  String? _userId;
  String? _communityId;
  String? _flatNumber;
  String? _userName;
  String? _userPhone;
  String? _userPhotoUrl;

  // Getters for language
  AppLanguage get language => _language;

  Locale get locale => AppLocalizations.getLocale(_language);

  // Getters for user info
  UserRole get userRole => _userRole;
  String? get userId => _userId;
  String? get communityId => _communityId;
  String? get flatNumber => _flatNumber;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  String? get userPhotoUrl => _userPhotoUrl;

  // Helper getters
  bool get isAuthenticated => _userId != null;
  bool get isAdmin => _userRole.isAdmin;

  /// Set language and update app
  void setLanguage(AppLanguage language) {
    if (_language != language) {
      _language = language;
      AppLocalizations.setLanguage(language);
      notifyListeners();
    }
  }

  /// Update user authentication info
  void setUserInfo({
    required String userId,
    required String communityId,
    required UserRole role,
    String? flatNumber,
    String? userName,
    String? userPhone,
    String? userPhotoUrl,
  }) {
    _userId = userId;
    _communityId = communityId;
    _userRole = role;
    _flatNumber = flatNumber;
    _userName = userName;
    _userPhone = userPhone;
    _userPhotoUrl = userPhotoUrl;
    notifyListeners();
  }

  /// Update just the display name — for a lightweight "edit my name"
  /// action, without touching identity/session fields.
  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  /// Update just the profile photo — [url] is null to clear it back to the
  /// initial-letter fallback avatar.
  void updateUserPhoto(String? url) {
    _userPhotoUrl = url;
    notifyListeners();
  }

  /// Update user role
  void setUserRole(UserRole role) {
    if (_userRole != role) {
      _userRole = role;
      notifyListeners();
    }
  }

  /// Clear user info on logout
  void clearUserInfo() {
    _userId = null;
    _communityId = null;
    _userRole = UserRole.none;
    _flatNumber = null;
    _userName = null;
    _userPhone = null;
    _userPhotoUrl = null;
    notifyListeners();
  }

  /// Reset app state (for testing or fresh start)
  void resetAppState() {
    _language = AppLanguage.english;
    AppLocalizations.setLanguage(AppLanguage.english);
    clearUserInfo();
    notifyListeners();
  }
}
