import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_seed.dart';
import '../models/role.dart';
import '../providers/app_provider.dart';
import '../providers/society_provider.dart';
import '../services/storage_service.dart';
import '../widgets/loading_overlay.dart';

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
///   in), falling back to the seeded demo resident only if that also comes
///   up empty (e.g. mock mode, or a phone that was never actually claimed).
/// Call this once, right after real phone verification succeeds, before
/// navigating with [resolvePostAuthRoute].
Future<void> completeSignIn(
  BuildContext context, {
  String? flatNumberOverride,
  String? phone,
}) async {
  final appProvider = context.read<AppProvider>();
  final society = context.read<SocietyProvider>();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final photoUrl = await _fetchProfilePhotoUrl(uid);

  if (appProvider.userRole.isAdmin) {
    if (phone != null && phone.isNotEmpty) {
      await society.claimAdminIfUnbound(phone);
    }
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
    return;
  }

  if (appProvider.userRole == UserRole.committee) {
    appProvider.setUserInfo(
      userId: uid,
      communityId: society.building.name,
      role: UserRole.committee,
      userName: 'Committee Member',
      userPhotoUrl: photoUrl,
    );
    return;
  }

  final lookedUpFlat = flatNumberOverride == null && phone != null
      ? await society.findFlatByPhone(phone)
      : null;
  final flatNumber =
      flatNumberOverride ?? lookedUpFlat?.flatNumber ?? MockSeed.demoResidentFlat;
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
}

Future<String?> _fetchProfilePhotoUrl(String uid) async {
  if (uid.isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
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
    if (!context.mounted) return;
    context.read<AppProvider>().clearUserInfo();
    Navigator.pushNamedAndRemoveUntil(context, '/language', (_) => false);
    await awaitRouteTransition();
  });
}
