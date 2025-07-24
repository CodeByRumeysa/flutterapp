import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showProgressNotification({
    required String goalName,
    required double progressPercent,
    required double remainingAmount,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'progress_channel',
      'Progress Notifications',
      channelDescription: 'Notifications about goal progress',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      'Your goal progress has been updated!',
      'You have reached ${ (progressPercent * 100).toStringAsFixed(0) }% of your "$goalName" goal, only \$${ remainingAmount.toStringAsFixed(2) } left!',
      notificationDetails,
    );
  }
}
