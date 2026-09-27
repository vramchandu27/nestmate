import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../providers/society_provider.dart';
import '../screens/resident/community_screen.dart';
import '../screens/resident/pay_now_screen.dart';

/// Real push notifications — the OS-level kind that reach a resident or
/// admin even with the app closed, unlike the in-app-only Notifications
/// screen list. A Cloud Function (see `functions/`) sends
/// the actual push whenever a notice is posted, a payment is confirmed, an
/// issue is reported, or a screenshot is uploaded; this service is just the
/// client half — registering this device's token, and reacting when a
/// push arrives or is tapped.
class PushNotificationService {
  final _messaging = FirebaseMessaging.instance;

  /// Wires up foreground/tap handling — call once, right after
  /// `Firebase.initializeApp` in `main()`. [navigatorKey] is the app's
  /// global navigator, needed here because a notification tap can happen
  /// with no screen's own [BuildContext] available yet (app freshly
  /// launched from a terminated state).
  void init(GlobalKey<NavigatorState> navigatorKey) {
    FirebaseMessaging.onMessage.listen((message) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final notification = message.notification;
      if (notification == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notification.body ?? notification.title ?? '',
            maxLines: 2,
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleTap(navigatorKey, message),
    );
    _messaging.getInitialMessage().then((message) {
      if (message != null) _handleTap(navigatorKey, message);
    });
  }

  void _handleTap(
    GlobalKey<NavigatorState> navigatorKey,
    RemoteMessage message,
  ) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    switch (message.data['type']) {
      case 'payment_confirmed':
        navigator.push(
          MaterialPageRoute(builder: (_) => const PayNowScreen()),
        );
      case 'new_notice':
        navigator.push(
          MaterialPageRoute(builder: (_) => const CommunityScreen()),
        );
      case 'new_issue':
        navigator.pushNamed('/admin-issues');
      case 'screenshot_uploaded':
        navigator.pushNamed('/admin-confirm-payments');
    }
  }

  /// Requests notification permission and registers this device's token
  /// against whichever role just signed in — the resident's own flat doc,
  /// or the building doc for the admin. Call once, right after
  /// [completeSignIn] succeeds. Non-fatal on any failure (denied
  /// permission, no token yet, offline): push notifications are an
  /// enhancement, never something sign-in should be blocked by.
  Future<void> registerToken(BuildContext context) async {
    // Captured once, up front, as plain values rather than held onto as a
    // BuildContext — onTokenRefresh can fire much later in the session,
    // long after the screen that called this has been disposed.
    final appProvider = context.read<AppProvider>();
    final isAdmin = appProvider.isAdmin;
    final flatNumber = appProvider.flatNumber;
    // Which society's document this token belongs to — captured here for
    // the same reason as the values above, since onTokenRefresh can fire
    // long after this context is gone.
    final buildingId = context.read<SocietyProvider>().buildingId;
    if (buildingId == null) return;

    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _writeToken(
          buildingId: buildingId,
          isAdmin: isAdmin,
          flatNumber: flatNumber,
          token: token,
        );
      }

      _messaging.onTokenRefresh.listen(
        (newToken) => _writeToken(
          buildingId: buildingId,
          isAdmin: isAdmin,
          flatNumber: flatNumber,
          token: newToken,
        ),
      );
    } catch (_) {
      // Push registration is best-effort — never block sign-in over it.
    }
  }

  Future<void> _writeToken({
    required String buildingId,
    required bool isAdmin,
    required String? flatNumber,
    required String token,
  }) async {
    if (isAdmin) {
      await FirebaseFirestore.instance
          .collection('buildings')
          .doc(buildingId)
          .set({'adminFcmToken': token}, SetOptions(merge: true));
      return;
    }
    if (flatNumber == null || flatNumber.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('buildings')
        .doc(buildingId)
        .collection('flats')
        .doc(flatNumber)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
