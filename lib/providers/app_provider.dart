import 'package:flutter/material.dart';
import '../models/course_type.dart';
import '../db/database_helper.dart';
import '../services/settings_service.dart';

class AppProvider extends ChangeNotifier {
  // 主题色
  String _themeColorKey = SettingsService.defaultThemeColor;
  String _themeMode = SettingsService.defaultThemeMode;
  String _defaultOpen = SettingsService.defaultOpen;

  // 课程类型
  List<CourseType> _courseTypes = [];
  bool _isLoading = false;

  String get themeColorKey => _themeColorKey;
  String get themeModeKey => _themeMode;
  String get defaultOpen => _defaultOpen;
  List<CourseType> get courseTypes => _courseTypes;
  bool get isLoading => _isLoading;

  ThemeMode get themeMode {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 预设主题色列表
  static const List<Map<String, dynamic>> themeColorPresets = [
    {'key': 'blue', 'name': '蓝色', 'color': Colors.blue, 'seed': 0xFF2196F3},
    {'key': 'green', 'name': '绿色', 'color': Colors.green, 'seed': 0xFF4CAF50},
    {'key': 'purple', 'name': '紫色', 'color': Colors.purple, 'seed': 0xFF9C27B0},
    {'key': 'orange', 'name': '橙色', 'color': Colors.orange, 'seed': 0xFFFF9800},
    {'key': 'red', 'name': '红色', 'color': Colors.red, 'seed': 0xFFF44336},
    {'key': 'teal', 'name': '青色', 'color': Colors.teal, 'seed': 0xFF009688},
    {'key': 'indigo', 'name': '靛蓝', 'color': Colors.indigo, 'seed': 0xFF3F51B5},
    {'key': 'pink', 'name': '粉色', 'color': Colors.pink, 'seed': 0xFFE91E63},
  ];

  static Color getSeedColor(String key) {
    for (var preset in themeColorPresets) {
      if (preset['key'] == key) {
        return Color(preset['seed'] as int);
      }
    }
    return Colors.blue;
  }

  static String getColorName(String key) {
    for (var preset in themeColorPresets) {
      if (preset['key'] == key) {
        return preset['name'] as String;
      }
    }
    return '蓝色';
  }

  ColorScheme get colorScheme {
    return ColorScheme.fromSeed(
      seedColor: getSeedColor(_themeColorKey),
      brightness: _themeMode == 'dark' ? Brightness.dark : Brightness.light,
    );
  }

  ColorScheme get darkColorScheme {
    return ColorScheme.fromSeed(
      seedColor: getSeedColor(_themeColorKey),
      brightness: Brightness.dark,
    );
  }

  ColorScheme get lightColorScheme {
    return ColorScheme.fromSeed(
      seedColor: getSeedColor(_themeColorKey),
      brightness: Brightness.light,
    );
  }

  /// 初始化
  Future<void> init() async {
    _themeColorKey = await SettingsService.instance.getThemeColor();
    _themeMode = await SettingsService.instance.getThemeMode();
    _defaultOpen = await SettingsService.instance.getDefaultOpen();
    await loadCourseTypes();
  }

  Future<void> loadCourseTypes() async {
    _isLoading = true;
    notifyListeners();
    _courseTypes = await DatabaseHelper.instance.getAllCourseTypes();
    _isLoading = false;
    notifyListeners();
  }

  // 主题色设置
  Future<void> setThemeColor(String key) async {
    _themeColorKey = key;
    await SettingsService.instance.setThemeColor(key);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await SettingsService.instance.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setDefaultOpen(String value) async {
    _defaultOpen = value;
    await SettingsService.instance.setDefaultOpen(value);
    notifyListeners();
  }

  // 课程类型 CRUD
  Future<bool> addCourseType(String name) async {
    try {
      await DatabaseHelper.instance.insertCourseType(CourseType(
        name: name,
        sortOrder: _courseTypes.length,
        createTime: DateTime.now(),
      ));
      await loadCourseTypes();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCourseType(int id, String name) async {
    try {
      CourseType? type = _courseTypes.firstWhere((t) => t.id == id);
      type.name = name;
      await DatabaseHelper.instance.updateCourseType(type);
      await loadCourseTypes();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCourseType(int id) async {
    int count = await DatabaseHelper.instance.getCourseCountByType(id);
    if (count > 0) return false;
    await DatabaseHelper.instance.deleteCourseType(id);
    await loadCourseTypes();
    return true;
  }

  Future<void> reorderCourseTypes(List<CourseType> types) async {
    await DatabaseHelper.instance.reorderCourseTypes(types);
    _courseTypes = List.from(types);
    notifyListeners();
  }
}
