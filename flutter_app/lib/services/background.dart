import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Keeps the phone line alive while the app is in the background or the
/// screen is off, by running as an Android foreground service (the small
/// "CallCenter Pro is running" notification). Without this, Android freezes
/// the app a few minutes after it leaves the screen and calls stop ringing.
class Background {
  static bool _ready = false;

  static void _init() {
    if (_ready) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cc_phone_line',
        channelName: 'Phone line',
        channelDescription: 'Keeps your phone line connected so calls can ring.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _ready = true;
  }

  static Future<void> start(String who) async {
    if (!Platform.isAndroid) return;
    try {
      await Permission.notification.request();
      // Ask the phone not to put the app to sleep. Shows one system prompt.
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
      _init();
      await FlutterForegroundTask.startService(
        notificationTitle: 'CallCenter Pro',
        notificationText: 'Phone line active · $who',
      );
    } catch (_) {
      // Never block sign-in because the service could not start.
    }
  }

  static Future<void> update(String text) async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.updateService(
          notificationTitle: 'CallCenter Pro', notificationText: text);
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
