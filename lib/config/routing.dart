import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_seed.dart';
import '../models/role.dart';
import '../providers/app_provider.dart';
import '../providers/society_provider.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/loading_overlay.dart';

/// How long a signed-in session stays valid with no fresh login — matches
/// [tryResumeSession]. Each successful sign-in (including a resumed one)
/// resets the clock, so this is a rolling window from last use, not a
/// fixed expiry from the very first login.
const _sessionValidity = Duration(days: 7);
const _lastLoginPrefsKey = 'lastLoginAtMillis';

/// Decides where to land the user right after a successful login / OTP /
/// signup, based on their role and how far along the admin setup flow is.
String resolvePostAuthRoute(BuildContext context) {
  final appProvider = context.read<AppProvider>();
  final society = context.read<SocietyProvider>();

  if (appProvider.userRole == UserRole.committee) {
    return '/committee-dashboard';
  }
  if (!appProvider.userRole.isAdmin) {
    return '/resident-shell';
  }
  if (!society.building.setupComplete) return '/admin-setup';
  if (society.flats.isEmpty) return '/admin-add-people';
  return '/admin-dashboard';
}

/// Completes sign-in based on whatever role the user picked on the way in
/// (the login screen's Resident/Admin tabs and the "continue as committee"
/// link set [AppProvider.userRole] before this runs), using the real
/// Firebase [FirebaseAuth.instance.currentUser] as the identity:
/// - communityAdmin → fills in the admin's identity from the building, and
///   binds [phone] as the sole admin if the seat isn't claimed yet (see
///   [SocietyProvider.claimAdminIfUnbound] — there is only ever one admin).
/// - committee → generic committee identity (read-only, not tied to a flat).
/// - otherwise (resident) → signs in as [flatNumberOverride] if given (e.g.
///   the flat a signup just validated against the roster — see
///   [SocietyProvider.claimFlatForSignup]); otherwise looks up the flat
///   whose stored phone matches [phone] (a returning resident logging back
///   in). In mock mode only, a miss falls back to the seeded demo resident
///   so the widget-test/demo build always has something to show; in real
///   mode a miss returns `false` instead — a phone number with no matching
///   flat must never silently sign someone into an unrelated flat's real
///   data just because a fallback flat number happened to exist.
/// Call this once, right after real phone verification succeeds. Returns
/// whether sign-in actually completed — the caller must check this before
/// navigating with [resolvePostAuthRoute]; on `false`, it should sign the
/// user back out of Firebase Auth and show an error instead.
Future<bool> completeSignIn(
  BuildContext context, {
  String? flatNumberOverride,
  String? phone,
}) async {
  final appProvider = context.read<AppProvider>();
  final society = context.read<SocietyProvider>();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final photoUrl = await _fetchProfilePhotoUrl(uid);
  await _recordLoginTimestamp();

  if (appProvider.userRole.isAdmin) {
    // The Admin tab merely being selected proves nothing on its own — the
    // login/OTP screens' own "adminAlreadyExists" pre-checks are only
    // best-effort (see SocietyProvider.canSignInAsAdmin's doc comment).
    // claimAdminIfUnbound is the real, authoritative gate: without checking
    // its result here, ANY phone number that completes verification on the
    // Admin tab would be granted full admin access, regardless of whether
    // it actually holds the seat.
    if (phone == null || phone.isEmpty) return false;
    final isRealAdmin = await society.claimAdminIfUnbound(phone);
    if (!isRealAdmin) return false;

    appProvider.setUserInfo(
      userId: uid,
      communityId: society.building.name,
      role: UserRole.communityAdmin,
      userName: society.building.adminName.isEmpty
          ? 'Admin'
          : society.building.adminName,
      userPhone: phone,
      userPhotoUrl: photoUrl,
    );
    if (!context.mounted) return true;
    await PushNotificationService().registerToken(context);
    return true;
  }

  if (appProvider.userRole == UserRole.committee) {
    appProvider.setUserInfo(
      userId: uid,
      communityId: society.building.name,
      role: UserRole.committee,
      userName: 'Committee Member',
      userPhotoUrl: photoUrl,
    );
    if (!context.mounted) return true;
    await PushNotificationService().registerToken(context);
    return true;
  }

  final lookedUpFlat = flatNumberOverride == null && phone != null
      ? await society.findFlatByPhone(phone)
      : null;
  var flatNumber = flatNumberOverride ?? lookedUpFlat?.flatNumber;
  if (flatNumber == null) {
    if (!society.isMock) return false;
    flatNumber = MockSeed.demoResidentFlat;
  }
  final flat = lookedUpFlat ?? society.flatByNumber(flatNumber);
  appProvider.setUserInfo(
    userId: uid,
    communityId: society.building.name,
    role: UserRole.resident,
    flatNumber: flatNumber,
    userName: flat?.residentName,
    userPhone: flat?.phone,
    userPhotoUrl: photoUrl,
  );
  if (!context.mounted) return true;
  await PushNotificationService().registerToken(context);
  return true;
}

Future<void> _recordLoginTimestamp() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastLoginPrefsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {
    // Worst case, the next app launch just won't auto-resume — never
    // worth failing sign-in over.
  }
}

/// Called once at app launch, before showing Language Selection — Firebase
/// itself already keeps a signed-in session alive across restarts, but the
/// app was never checking for it, always forcing Welcome → Login again
/// regardless. This resumes that session automatically if it's both still
/// signed in AND the last successful login was within [_sessionValidity];
/// otherwise it signs out (if stale) and returns null so the normal
/// Welcome/Login flow shows instead.
///
/// Returns the route to land on (same shape as [resolvePostAuthRoute]), or
/// null if there's nothing to resume. Committee sessions never resume —
/// that role has no persistent phone-based identity to re-derive from a
/// bare Firebase user, so a committee member just taps "continue as
/// committee" again, which is quick anyway.
Future<String?> tryResumeSession(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  try {
    final prefs = await SharedPreferences.getInstance();
    final lastLoginMillis = prefs.getInt(_lastLoginPrefsKey);
    if (lastLoginMillis == null) {
      await FirebaseAuth.instance.signOut();
      return null;
    }
    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMillis);
    if (DateTime.now().difference(lastLogin) > _sessionValidity) {
      await FirebaseAuth.instance.signOut();
      return null;
    }
  } catch (_) {
    return null;
  }

  final phone = user.phoneNumber;
  if (phone == null) return null;
  if (!context.mounted) return null;

  final appProvider = context.read<AppProvider>();
  final society = context.read<SocietyProvider>();

  try {
    final buildingDoc = await FirebaseFirestore.instance
        .collection('buildings')
        .doc('main')
        .get()
        .timeout(const Duration(seconds: 8));
    if (buildingDoc.data()?['adminPhone'] == phone) {
      appProvider.setUserRole(UserRole.communityAdmin);
      if (!context.mounted) return null;
      await completeSignIn(context, phone: phone);
      if (!context.mounted) return null;
      return resolvePostAuthRoute(context);
    }

    final flat = await society.findFlatByPhone(phone);
    if (flat != null) {
      appProvider.setUserRole(UserRole.resident);
      if (!context.mounted) return null;
      await completeSignIn(
        context,
        phone: phone,
        flatNumberOverride: flat.flatNumber,
      );
      if (!context.mounted) return null;
      return resolvePostAuthRoute(context);
    }
  } catch (_) {
    // Offline or a genuine lookup failure — fall through to a normal,
    // explicit login rather than guessing.
  }
  return null;
}

Future<String?> _fetchProfilePhotoUrl(String uid) async {
  if (uid.isEmpty) return null;
  try {
    // A profile photo is a nice-to-have, not something sign-in should ever
    // hang on — this document may not be cached locally yet (e.g. first
    // sign-in on a new device), and a Firestore .get() with no cached data
    // and a flaky connection can otherwise stall indefinitely with no
    // built-in timeout of its own.
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 5));
    return doc.data()?['photoUrl'] as String?;
  } catch (_) {
    return null;
  }
}

/// Uploads a new profile photo (or clears it, if [file] is null) for the
/// currently signed-in user — stored at `users/{uid}` in Firestore
/// (`photoUrl` field) and `users/{uid}/profile` in Storage, matching the
/// same per-user scoping [PersonalExpenseProvider] uses. Shared by both the
/// admin and resident profile screens.
Future<void> updateProfilePhoto(BuildContext context, File? file) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  await withLoadingOverlay(context, () async {
    String? url;
    if (file != null) {
      url = await StorageService().uploadPhoto(
        basePath: 'users/$uid/profile',
        file: file,
      );
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'photoUrl': url,
    }, SetOptions(merge: true));
    if (!context.mounted) return;
    context.read<AppProvider>().updateUserPhoto(url);
  });
}

/// Undoes [completeSignIn] — every "Logout" button should call this
/// instead of clearing [AppProvider] directly. Signs out of the real
/// Firebase session too, not just the local app state: leaving the
/// Firebase session alive after "logging out" is what let a stale
/// identity linger on-device for whoever logs in next on the same phone.
Future<void> performLogout(BuildContext context) async {
  await withLoadingOverlay(context, () async {
    await FirebaseAuth.instance.signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginPrefsKey);
    } catch (_) {
      // Already signed out either way — a stale local timestamp alone
      // can't resume a session with no Firebase user behind it.
    }
    if (!context.mounted) return;
    context.read<AppProvider>().clearUserInfo();
    Navigator.pushNamedAndRemoveUntil(context, '/language', (_) => false);
    await awaitRouteTransition();
  });
}
