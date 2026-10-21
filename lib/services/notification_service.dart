import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/config.dart';
import '../models/timetable.dart';
import 'sleep_recorder.dart';

/// Runs in a background isolate when a notification button is pressed.
/// "Yes" on the sleep / wake prompts records the time without opening the app.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  final id = response.actionId;
  if (id != 'sleep_yes' && id != 'wake_yes') return;
  DartPluginRegistrant.ensureInitialized();
  await SleepRecorder.recordFromPrefs(
    id == 'sleep_yes' ? SleepAction.start : SleepAction.wake,
    DateTime.now(),
  );
}

class ReminderStatus {
  final bool notificationsOn;
  final bool exactOk;
  final int scheduled; // timetable reminders currently scheduled
  final String? lastError;
  const ReminderStatus(this.notificationsOn, this.exactOk, this.scheduled, this.lastError);
}

/// Daily reminders (timetable) and silent sleep / wake prompts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Last scheduling error, shown on the Time Table screen.
  String? lastError;

  static const _channelId = 'fitfam_reminders';
  static const _promptChannelId = 'fitfam_sleep_prompts';
  static const _testId = 9999;
  static const _sleepPromptId = 100;
  static const _wakePromptId = 101;

  /// Timetable reminders: sound, heads-up, with a Dismiss button.
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'FitFam reminders',
      channelDescription: 'Daily reminders for wake up, workout, meals and sleep',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      autoCancel: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
    ),
  );

  /// Sleep / wake prompts: silent, sits in the notification shade with a
  /// single "Yes" button. Swiping it away means "no".
  static NotificationDetails _promptDetails(String actionId, int timeoutMs) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _promptChannelId,
          'Sleep & wake prompts',
          channelDescription: 'Silent prompts to record when you sleep and wake up',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          silent: true,
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
          timeoutAfter: timeoutMs,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              actionId,
              'Yes',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
        ),
      );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      // flutter_timezone returns a String (older) or TimezoneInfo (newer).
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      final String name = info is String ? info : info.identifier as String;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Could not read local timezone, using default: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    _ready = true;
  }

  /// Notification permission only (no exact-alarm screen).
  Future<bool> requestNotificationPermission() async {
    final android = _android;
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Notification permission, then (if needed) exact-alarm permission.
  Future<bool> requestPermissions() async {
    final android = _android;
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission() ?? false;
    if (!granted) return false;
    if (!await _canExact()) await android.requestExactAlarmsPermission();
    return true;
  }

  Future<void> openExactAlarmSettings() async => _android?.requestExactAlarmsPermission();

  Future<bool> _canExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return false;
    }
  }

  /// For the Time Table status card.
  Future<ReminderStatus> status() async {
    final a = _android;
    var on = true, exact = true, scheduled = 0;
    try {
      on = await a?.areNotificationsEnabled() ?? true;
    } catch (_) {}
    exact = await _canExact();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      scheduled = pending.where((p) => p.id < _sleepPromptId).length;
    } catch (_) {}
    return ReminderStatus(on, exact, scheduled, lastError);
  }

  Future<void> _scheduleDaily({
    required int id,
    required int minutesOfDay,
    required String title,
    required String body,
    required NotificationDetails details,
    required bool exact,
  }) async {
    final when = tz.TZDateTime.from(nextOccurrenceOf(minutesOfDay, DateTime.now()), tz.local);
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time, // repeats daily
        );
    try {
      await go(exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (_) {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  // ---- timetable reminders (ids 0..n-1) ----

  /// One failing row no longer stops the others.
  Future<void> scheduleAll(Timetable t) async {
    if (!_ready) return;
    lastError = null;
    final exact = await _canExact();
    for (var i = 0; i < t.entries.length; i++) {
      try {
        await _plugin.cancel(id: i);
        final e = t.entries[i];
        if (!e.reminderOn) continue;
        final def = AppConfig.instance.timetableRow(e.id);
        await _scheduleDaily(
          id: i,
          minutesOfDay: e.minutesOfDay - def.leadMinutes,
          title: def.label,
          body: def.leadMinutes == 0
              ? 'Time to wake up'
              : '${def.label} at ${e.time} (in ${def.leadMinutes} min)',
          details: _details,
          exact: exact,
        );
      } catch (err) {
        lastError = '$err';
        debugPrint('Scheduling reminder $i failed: $err');
      }
    }
  }

  // ---- silent sleep / wake prompts (ids 100, 101) ----

  /// [sleepPromptMinutes] / [wakePromptMinutes] are minutes of the day at
  /// which each prompt appears.
  Future<void> scheduleSleepPrompts({
    required int sleepPromptMinutes,
    required int wakePromptMinutes,
  }) async {
    if (!_ready) return;
    final exact = await _canExact();
    try {
      await _scheduleDaily(
        id: _sleepPromptId,
        minutesOfDay: sleepPromptMinutes,
        title: 'Going to sleep?',
        body: 'Tap Yes to record your sleep start time.',
        details: _promptDetails('sleep_yes', 4 * 3600 * 1000),
        exact: exact,
      );
      await _scheduleDaily(
        id: _wakePromptId,
        minutesOfDay: wakePromptMinutes,
        title: 'Good morning, woke up?',
        body: 'Tap Yes to record your wake-up time.',
        details: _promptDetails('wake_yes', 6 * 3600 * 1000),
        exact: exact,
      );
    } catch (e) {
      lastError = '$e';
      debugPrint('Scheduling sleep prompts failed: $e');
    }
  }

  /// Temporary: fires a test reminder in 10 seconds.
  // Future<void> scheduleTest() async {
  //   final exact = await _canExact();
  //   await _plugin.zonedSchedule(
  //     id: _testId,
  //     title: 'FitFam test reminder',
  //     body: 'Reminders are working 🎉',
  //     scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
  //     notificationDetails: _details,
  //     androidScheduleMode: exact
  //         ? AndroidScheduleMode.exactAllowWhileIdle
  //         : AndroidScheduleMode.inexactAllowWhileIdle,
  //   );
  // }
}
