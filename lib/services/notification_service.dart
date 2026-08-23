import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知栏通知服务（单例）
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _webServerNotificationId = 1001;
  static const String _channelId = 'web_server_channel';
  static const String _channelName = '网页管理服务';
  static const String _channelDesc = '网页管理运行中通知';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 显示网页管理运行中通知
  Future<void> showWebServerRunning(String url) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      _webServerNotificationId,
      '网页管理运行中',
      '访问地址：$url（长按网址可复制）',
      details,
    );
  }

  /// 取消网页管理通知
  Future<void> cancelWebServerNotification() async {
    await init();
    await _plugin.cancel(_webServerNotificationId);
  }
}
