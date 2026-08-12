import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/chapter.dart';
import '../models/course_type.dart';
import 'webdav_service.dart';
import 'settings_service.dart';

class BackupService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      int sdkInt = androidInfo.version.sdkInt;
      if (sdkInt >= 33) {
        var status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;
        if (!status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return (await Permission.manageExternalStorage.status).isGranted;
      } else if (sdkInt >= 30) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          await Permission.manageExternalStorage.request();
        }
        status = await Permission.storage.status;
        if (status.isGranted) return true;
        if (!status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return (await Permission.storage.status).isGranted;
      } else {
        var status = await Permission.storage.request();
        if (status.isGranted) return true;
        if (!status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return (await Permission.storage.status).isGranted;
      }
    }
    return true;
  }

  static Future<String> _getLocalExportPath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${directory!.path}/study_progress_backup_$timestamp.json';
  }

  static Future<Map<String, dynamic>> exportDataToJson() async {
    List<Course> courses = await DatabaseHelper.instance.getAllCourses();
    List<Chapter> allChapters = [];
    for (var course in courses) {
      List<Chapter> chapters = await DatabaseHelper.instance.getChaptersByCourseId(course.id!);
      allChapters.addAll(chapters);
    }
    List<CourseType> types = await DatabaseHelper.instance.getAllCourseTypes();
    return {
      'version': '2.0',
      'exportTime': DateTime.now().toIso8601String(),
      'courseTypes': types.map((t) => t.toJson()).toList(),
      'courses': courses.map((c) => c.toJson()).toList(),
      'chapters': allChapters.map((c) => c.toJson()).toList(),
    };
  }

  // ==================== 本地备份恢复 ====================

  static Future<String?> exportToLocal(BuildContext context) async {
    try {
      Map<String, dynamic> data = await exportDataToJson();
      String jsonData = const JsonEncoder.withIndent('  ').convert(data);
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonData));

      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String defaultName = 'study_progress_backup_$timestamp.bak';

      String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '选择备份保存位置',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['bak'],
        bytes: bytes,
      );

      if (savedPath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已取消导出')),
          );
        }
        return null;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出成功：$savedPath')),
        );
      }
      return savedPath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
      return null;
    }
  }

  static Future<bool> importFromLocal(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bak', 'json'],
      );

      if (result == null) return false;

      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      if (!context.mounted) return false;
      return await _importFromJson(context, content);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
      return false;
    }
  }

  // ==================== WebDAV 备份恢复 ====================

  static Future<bool> exportToWebDAV(BuildContext context) async {
    try {
      final config = await SettingsService.instance.getWebdavConfig();
      if (config['url']!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先配置 WebDAV')),
          );
        }
        return false;
      }

      final webdav = WebDavService(
        baseUrl: config['url']!,
        username: config['username']!,
        password: config['password']!,
        basePath: config['path']!,
      );

      Map<String, dynamic> data = await exportDataToJson();
      String jsonData = const JsonEncoder.withIndent('  ').convert(data);
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonData));

      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String filename = 'study_progress_backup_$timestamp.bak';

      bool success = await webdav.uploadFile(filename, bytes);
      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('WebDAV备份成功：$filename')),
          );
        }
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebDAV备份失败，请检查配置')),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WebDAV备份失败：$e')),
        );
      }
      return false;
    }
  }

  static Future<bool> importFromWebDAV(BuildContext context) async {
    try {
      final config = await SettingsService.instance.getWebdavConfig();
      if (config['url']!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先配置 WebDAV')),
          );
        }
        return false;
      }

      final webdav = WebDavService(
        baseUrl: config['url']!,
        username: config['username']!,
        password: config['password']!,
        basePath: config['path']!,
      );

      String? filename = await webdav.getLatestBackupFilename();
      if (filename == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebDAV上没有找到备份文件')),
          );
        }
        return false;
      }

      Uint8List? bytes = await webdav.downloadFile(filename);
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('下载备份文件失败')),
          );
        }
        return false;
      }

      String content = utf8.decode(bytes);
      if (!context.mounted) return false;
      return await _importFromJson(context, content);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WebDAV恢复失败：$e')),
        );
      }
      return false;
    }
  }

  static Future<ConnectionResult> testWebDAVConnection() async {
    final config = await SettingsService.instance.getWebdavConfig();
    if (config['url']!.isEmpty) {
      return ConnectionResult(false, '请先填写服务器地址');
    }

    final webdav = WebDavService(
      baseUrl: config['url']!,
      username: config['username']!,
      password: config['password']!,
      basePath: config['path']!,
    );
    return await webdav.testConnection();
  }

  // ==================== 内部方法 ====================

  static Future<bool> _importFromJson(BuildContext context, String content) async {
    try {
      Map<String, dynamic> jsonData = json.decode(content);

      if (!jsonData.containsKey('courses') || !jsonData.containsKey('chapters')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份文件格式不正确')),
          );
        }
        return false;
      }

      bool? shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复数据'),
          content: const Text('导入将清空现有所有数据后再导入，是否继续？\n\n提示：建议先导出备份以防数据丢失。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );

      if (shouldClear != true) return false;

      List<dynamic> coursesJson = jsonData['courses'];
      List<dynamic> chaptersJson = jsonData['chapters'];
      List<dynamic> typesJson = jsonData.containsKey('courseTypes') ? jsonData['courseTypes'] : [];

      List<Course> courses = coursesJson.map((c) => Course.fromJson(c)).toList();
      List<Chapter> chapters = chaptersJson.map((c) => Chapter.fromJson(c)).toList();
      List<CourseType> types = typesJson.map((t) => CourseType.fromJson(t)).toList();

      await DatabaseHelper.instance.clearAllData();
      await DatabaseHelper.instance.batchInsertData(courses, chapters, types);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入成功：${courses.length}门课程，${chapters.length}个章节')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
      return false;
    }
  }
}
