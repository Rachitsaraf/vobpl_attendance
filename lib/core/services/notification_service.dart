import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _checkoutReminderId = 888;

  /// Initialize local notifications plugin
  static Future<void> init() async {
    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification tapped: ${details.payload}');
        },
      );

      // Create Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'vobpl_attendance_reminders',
        'Shift Reminders',
        description: 'Reminders for shift check-out and attendance',
        importance: Importance.max,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(channel);
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Schedule 8-hour checkout reminder notification
  static Future<void> scheduleCheckoutReminder(DateTime checkInTime) async {
    try {
      final scheduledTime = checkInTime.add(const Duration(hours: 8));

      // Don't schedule if 8 hours have already passed
      if (scheduledTime.isBefore(DateTime.now())) {
        debugPrint('Checkout reminder time is in the past. Skipping.');
        return;
      }

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'vobpl_attendance_reminders',
        'Shift Reminders',
        channelDescription: 'Reminders for shift check-out and attendance',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.zonedSchedule(
        _checkoutReminderId,
        'Shift Checkout Reminder 🔔',
        'Please do not forget to check out, otherwise absent will be counted!',
        tzScheduledTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Scheduled checkout reminder for: $tzScheduledTime');
    } catch (e) {
      debugPrint('Error scheduling checkout notification: $e');
    }
  }

  /// Cancel any pending checkout reminder notification
  static Future<void> cancelCheckoutReminder() async {
    try {
      await _notificationsPlugin.cancel(_checkoutReminderId);
      debugPrint('Cancelled pending checkout reminder notification.');
    } catch (e) {
      debugPrint('Error cancelling checkout notification: $e');
    }
  }
}
