import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // 主题色 key
  static const String keyThemeColor = 'theme_color';
  // 主题模式: 'light', 'dark', 'system'
  static const String keyThemeMode = 'theme_mode';
  // 默认启动页: 'overview' 或 'last_course'
  static const String keyDefaultOpen = 'default_open';
  // WebDAV 配置
  static const String keyWebdavUrl = 'webdav_url';
  static const String keyWebdavUsername = 'webdav_username';
  static const String keyWebdavPassword = 'webdav_password';
  static const String keyWebdavPath = 'webdav_path';
  // 自动同步
  static const String keyAutoSync = 'auto_sync';
  static const String keyLastSyncTime = 'last_sync_time';
  // 密码保护
  static const String keyPassword = 'app_password';

  // 默认值
  static const String defaultThemeColor = 'blue';
  static const String defaultThemeMode = 'system';
  static const String defaultOpen = 'overview';
  static const String defaultWebdavPath = '/study_progress/';

  Future<String> getThemeColor() async {
    final p = await prefs;
    return p.getString(keyThemeColor) ?? defaultThemeColor;
  }

  Future<void> setThemeColor(String color) async {
    final p = await prefs;
    await p.setString(keyThemeColor, color);
  }

  Future<String> getThemeMode() async {
    final p = await prefs;
    return p.getString(keyThemeMode) ?? defaultThemeMode;
  }

  Future<void> setThemeMode(String mode) async {
    final p = await prefs;
    await p.setString(keyThemeMode, mode);
  }

  Future<String> getDefaultOpen() async {
    final p = await prefs;
    return p.getString(keyDefaultOpen) ?? defaultOpen;
  }

  Future<void> setDefaultOpen(String value) async {
    final p = await prefs;
    await p.setString(keyDefaultOpen, value);
  }

  Future<Map<String, String>> getWebdavConfig() async {
    final p = await prefs;
    return {
      'url': p.getString(keyWebdavUrl) ?? '',
      'username': p.getString(keyWebdavUsername) ?? '',
      'password': p.getString(keyWebdavPassword) ?? '',
      'path': p.getString(keyWebdavPath) ?? defaultWebdavPath,
    };
  }

  Future<void> setWebdavConfig({
    required String url,
    required String username,
    required String password,
    String? path,
  }) async {
    final p = await prefs;
    await p.setString(keyWebdavUrl, url);
    await p.setString(keyWebdavUsername, username);
    await p.setString(keyWebdavPassword, password);
    if (path != null) {
      await p.setString(keyWebdavPath, path);
    }
  }

  Future<bool> isWebdavConfigured() async {
    final config = await getWebdavConfig();
    return config['url']!.isNotEmpty && config['username']!.isNotEmpty;
  }

  Future<bool> getAutoSync() async {
    final p = await prefs;
    return p.getBool(keyAutoSync) ?? false;
  }

  Future<void> setAutoSync(bool value) async {
    final p = await prefs;
    await p.setBool(keyAutoSync, value);
  }

  Future<DateTime?> getLastSyncTime() async {
    final p = await prefs;
    final str = p.getString(keyLastSyncTime);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    final p = await prefs;
    await p.setString(keyLastSyncTime, time.toIso8601String());
  }

  Future<bool> hasPassword() async {
    final p = await prefs;
    return p.getString(keyPassword) != null;
  }

  Future<void> setPassword(String password) async {
    final p = await prefs;
    await p.setString(keyPassword, password);
  }

  Future<void> removePassword() async {
    final p = await prefs;
    await p.remove(keyPassword);
  }

  Future<bool> verifyPassword(String password) async {
    final p = await prefs;
    final stored = p.getString(keyPassword);
    if (stored == null) return true;
    return stored == password;
  }
}
