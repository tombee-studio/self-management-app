import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationGatewayProvider = Provider<LocalNotificationGateway>(
  (ref) => LocalNotificationGateway(),
);

abstract class NotificationGateway {
  Future<bool> show(int id, String title, String body, {String? payload});
}

class LocalNotificationGateway implements NotificationGateway {
  final FlutterLocalNotificationsPlugin plugin;
  bool _ready = false;
  void Function(String)? onSelect;
  LocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();
  Future<bool> initialize() async {
    if (_ready) return true;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final id = response.payload;
          if (id != null) onSelect?.call(id);
        },
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && payload != null) {
        onSelect?.call(payload);
      }
      _ready = true;
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> show(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    if (!await initialize()) return false;
    try {
      final ios =
          plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      final android =
          plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final allowed =
          ios != null
              ? await ios.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              )
              : await android?.requestNotificationsPermission();
      if (allowed == false) return false;
      await plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'iris_expenses',
            '支出と予算',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
