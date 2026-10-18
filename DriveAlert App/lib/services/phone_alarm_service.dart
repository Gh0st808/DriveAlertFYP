import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

/// Android owns the monitoring loop; it does not depend on this screen's timers.
class PhoneAlarmService {
  static const _channel = MethodChannel('drivealert/phone_alarm');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static DateTime? _configured;

  static Future<void> prepare({
    bool requestPermission = true,
    bool background = true,
  }) async {
    if (!supported) {
      throw StateError('Background phone alarms require the Android app.');
    }
    await _channel.invokeMethod<void>('prepare', {
      'requestPermission': requestPermission,
      'background': background,
    });
  }

  static Future<void> watch(Map<String, dynamic> status) async {
    if (!supported) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (status['monitoring'] != true) {
      await stop();
      return;
    }
    final run = status['run_id']?.toString();
    final token = status['phone_alarm_token']?.toString();
    if (run == null || token == null || token.isEmpty) {
      throw StateError(
        'Phone alarms are unavailable. Reconnect and try starting monitoring again.',
      );
    }
    final state =
        await _channel.invokeMapMethod<String, dynamic>('state') ?? {};
    if (state['active'] == true &&
        state['run'] == run &&
        _configured != null &&
        DateTime.now().difference(_configured!) < const Duration(minutes: 5)) {
      return;
    }
    await prepare(requestPermission: false);
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await _channel.invokeMethod<void>('start', {
      'run': run,
      'token': token,
      'endpoint': '${ApiService.baseUrl}/monitor/phone-alarm/',
    });
    _configured = DateTime.now();
  }

  static Future<void> stop() async {
    _configured = null;
    if (supported) await _channel.invokeMethod<void>('stop');
  }

  static Future<void> test() async {
    await prepare(background: false);
    await _channel.invokeMethod<void>('test');
  }

  static Future<void> batterySettings() async {
    if (!supported) {
      throw StateError('Background alarm settings require Android.');
    }
    await _channel.invokeMethod<void>('batterySettings');
  }
}
