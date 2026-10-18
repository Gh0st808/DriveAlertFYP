import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import 'api_service.dart';
import 'phone_alarm_service.dart';

@pragma('vm:entry-point')
Future<void> driveAlertBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: driveAlertFirebaseOptions);
  // Android displays the notification payload. No video or account data is processed here.
}

class NotificationService {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool available = false;
  static bool _enabled = false;
  static int _epoch = 0;
  static bool _pendingHistory = false;
  static String? _token;
  static String? lastError;

  static Future<void> initialize() async {
    if (!supported || available) return;
    try {
      await Firebase.initializeApp(options: driveAlertFirebaseOptions);
      FirebaseMessaging.onBackgroundMessage(driveAlertBackgroundMessage);
      FirebaseMessaging.onMessage.listen((message) {
        if (!_enabled || ApiService.accessToken == null) return;
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              message.notification?.body ??
                  'A new DriveAlert event was recorded.',
            ),
            action: SnackBarAction(label: 'History', onPressed: _openHistory),
          ),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) => _openHistory());
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        if (!_enabled || ApiService.accessToken == null) return;
        final epoch = _epoch;
        try {
          final response = await ApiService.registerPushToken(token);
          if (epoch == _epoch && response.statusCode == 200) _token = token;
        } catch (_) {
          lastError =
              'Notification setup will retry when you sign in or enable notifications.';
        }
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      _pendingHistory = initial != null;
      available = true;
    } catch (_) {
      lastError =
          'Notifications are unavailable. Check that Google Play services is available and try again.';
    }
  }

  static void _openHistory() {
    if (ApiService.accessToken == null) {
      _pendingHistory = true;
      return;
    }
    navigatorKey.currentState?.pushNamed('/history');
  }

  static Future<void> afterLogin() async {
    if (!supported) return;
    final epoch = ++_epoch;
    try {
      final response = await ApiService.getProfile();
      if (epoch != _epoch || response.statusCode != 200) return;
      final enabled =
          jsonDecode(response.body)['push_notifications_enabled'] == true;
      if (enabled) await enable(requestPermission: false);
      if (epoch == _epoch && _pendingHistory) {
        _pendingHistory = false;
        _openHistory();
      }
    } catch (_) {
      lastError = 'Notification registration could not be refreshed.';
    }
  }

  static Future<String> enable({bool requestPermission = true}) async {
    if (!supported) {
      throw StateError(
        'Push notifications are configured for Android in this build.',
      );
    }
    await initialize();
    if (!available) {
      throw StateError(
        lastError ?? 'Notifications are temporarily unavailable.',
      );
    }
    final epoch = _epoch;
    final messaging = FirebaseMessaging.instance;
    final permission = requestPermission
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await messaging.getNotificationSettings();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError(
        'Notification permission is denied. Enable it in Android app settings.',
      );
    }
    await messaging.setAutoInitEnabled(true);
    final token = await messaging.getToken();
    if (token == null || epoch != _epoch || ApiService.accessToken == null) {
      throw StateError(
        'Unable to register this device. Sign in and try again.',
      );
    }
    final response = await ApiService.registerPushToken(token);
    if (response.statusCode != 200) {
      throw StateError(ApiService.errorText(response));
    }
    if (epoch != _epoch) {
      return 'Account changed. Please enable notifications again.';
    }
    _enabled = true;
    _token = token;
    return jsonDecode(response.body)['server_configured'] == true
        ? 'Notifications enabled on this phone.'
        : 'Your preference was saved. Notification delivery is temporarily unavailable.';
  }

  static Future<void> disable() async {
    _epoch++;
    _enabled = false;
    final response = await ApiService.savePreferences({
      'push_notifications_enabled': false,
    });
    if (response.statusCode != 200) {
      throw StateError(ApiService.errorText(response));
    }
    if (available) {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    }
    _token = null;
  }

  static Future<String> sendTest() async {
    if (!_enabled || _token == null) {
      throw StateError('Enable notifications on this phone first.');
    }
    final response = await ApiService.testPush(_token!);
    if (response.statusCode != 200) {
      throw StateError(ApiService.errorText(response));
    }
    return 'Test notification requested. It may take a moment to arrive.';
  }

  static Future<void> beforeLogout() async {
    await PhoneAlarmService.stop();
    _epoch++;
    _enabled = false;
    if (!supported || !available) return;
    final token = _token;
    try {
      if (token != null) {
        await ApiService.removePushToken(
          token,
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      /* Cloud token invalidation is also attempted below. */
    }
    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      /* Offline cleanup can retry at next sign-in. */
    }
    _token = null;
  }
}
