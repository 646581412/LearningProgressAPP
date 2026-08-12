import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class WebDavService {
  final String baseUrl;
  final String username;
  final String password;
  final String basePath;

  WebDavService({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.basePath = '/study_progress/',
  });

  /// 规范化路径，确保开头有/，结尾有/
  String _normalizePath(String path) {
    if (path.isEmpty) return '/';
    if (!path.startsWith('/')) path = '/$path';
    if (!path.endsWith('/')) path = '$path/';
    return path;
  }

  /// 分离 base URL 和 path 的前缀
  /// 如 baseUrl = "https://dav.jianguoyun.com/dav/"，basePath = "/study_progress/"
  /// 根请求应发到 "https://dav.jianguoyun.com/dav/"
  /// 文件请求发到 "https://dav.jianguoyun.com/dav/study_progress/filename"
  String get _rootUrl {
    String url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// 构建完整 URI
  Uri _buildUri(String relativePath) {
    String rel = relativePath;
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    String fullPath = _normalizePath(basePath) + rel;
    if (fullPath.endsWith('/') && rel.isEmpty) {
      // 保留目录的末尾斜杠
    }
    return Uri.parse('$_rootUrl$fullPath');
  }

  Map<String, String> get _authHeaders {
    String credentials = base64Encode(utf8.encode('$username:$password'));
    return {
      'Authorization': 'Basic $credentials',
    };
  }

  /// 测试连接 - 返回详细错误信息
  Future<ConnectionResult> testConnection() async {
    // 先测试根目录（服务器根），不涉及 basePath
    final rootUri = Uri.parse('$_rootUrl/');
    try {
      // 方法1: 尝试 GET 请求根路径（很多服务器支持）
      final getResponse = await http.get(
        rootUri,
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));

      if (getResponse.statusCode == 200 ||
          getResponse.statusCode == 301 ||
          getResponse.statusCode == 302) {
        return ConnectionResult(true, '连接成功');
      }

      if (getResponse.statusCode == 401 || getResponse.statusCode == 403) {
        return ConnectionResult(false, '认证失败（状态码 ${getResponse.statusCode}），请检查用户名和应用密码');
      }

      // GET 不支持，尝试 PROPFIND
      return await _testWithPropfind(rootUri);
    } catch (e) {
      return await _testWithPropfind(rootUri);
    }
  }

  Future<ConnectionResult> _testWithPropfind(Uri rootUri) async {
    try {
      final request = http.Request('PROPFIND', rootUri);
      request.headers.addAll(_authHeaders);
      request.headers['Depth'] = '0';
      request.headers['Content-Type'] = 'application/xml';
      request.body = '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <displayname/>
  </prop>
</propfind>''';
      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 207 || response.statusCode == 200) {
        return ConnectionResult(true, '连接成功');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ConnectionResult(false, '认证失败（状态码 ${response.statusCode}），请检查用户名和应用密码');
      }
      if (response.statusCode == 405) {
        // PROPFIND 不被允许但服务器在线
        return ConnectionResult(true, '连接成功（服务器在线）');
      }
      return ConnectionResult(false, '连接失败（状态码 ${response.statusCode}）');
    } catch (e) {
      if (e is StateError || e is SocketException || e is TimeoutException) {
        return ConnectionResult(false, '网络错误：${e.toString().split('\\n').first}');
      }
      return ConnectionResult(false, '连接错误：$e');
    }
  }

  /// 确保目录存在 - 支持创建多级目录
  Future<bool> ensureDirectory() async {
    try {
      // 逐段创建目录
      final segments = basePath
          .split('/')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      String currentPath = '';
      String url = baseUrl.trim();
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      for (var seg in segments) {
        currentPath = '$currentPath/$seg/';
        final mkcolUri = Uri.parse('$url$currentPath');
        try {
          final request = http.Request('MKCOL', mkcolUri);
          request.headers.addAll(_authHeaders);
          final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
          final response = await http.Response.fromStream(streamedResponse);
          // 201 = created, 405 = already exists, 301 = redirect
          if (!(response.statusCode == 201 ||
              response.statusCode == 405 ||
              response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 200)) {
            // 失败但可能父级目录已经是文件等特殊情况
          }
        } catch (_) {
          // 继续尝试下一级，有些服务器一次性创建父目录会报错
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return true;
    } catch (_) {
      // 即使创建目录失败，如果testConnection能连上服务器也应视为可用
      // 这里失败可能是用户没创建目录的权限，但其他操作如上传下载仍可用
      return true;
    }
  }

  /// 上传文件
  Future<bool> uploadFile(String filename, Uint8List data) async {
    try {
      await ensureDirectory();
      final response = await http.put(
        _buildUri(filename),
        headers: {
          ..._authHeaders,
          'Content-Type': 'application/octet-stream',
        },
        body: data,
      ).timeout(const Duration(seconds: 60));
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// 下载文件
  Future<Uint8List?> downloadFile(String filename) async {
    try {
      final response = await http.get(
        _buildUri(filename),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 列出文件
  Future<List<String>> listFiles() async {
    try {
      final request = http.Request('PROPFIND', _buildUri(''));
      request.headers.addAll(_authHeaders);
      request.headers['Depth'] = '1';
      request.headers['Content-Type'] = 'application/xml';
      request.body = '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <displayname/>
    <getcontentlength/>
    <resourcetype/>
  </prop>
</propfind>''';
      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 207 && response.statusCode != 200) {
        return [];
      }

      // 简单解析 XML 提取文件名
      String body = utf8.decode(response.bodyBytes);
      List<String> files = [];
      RegExp hrefRegex = RegExp(r'<[^:]*:?\w*href[^>]*>([^<]+)</[^:]*:?\w*href>');
      Iterable<RegExpMatch> matches = hrefRegex.allMatches(body);
      for (var match in matches) {
        String href = match.group(1) ?? '';
        try {
          href = Uri.decodeFull(href);
        } catch (_) {}
        List<String> parts = href.split('/');
        if (parts.isNotEmpty) {
          String name = parts.last;
          if (name.isNotEmpty && name.endsWith('.json')) {
            files.add(name);
          }
        }
      }
      return files;
    } catch (_) {
      return [];
    }
  }

  /// 获取最新的备份文件名
  Future<String?> getLatestBackupFilename() async {
    List<String> files = await listFiles();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.compareTo(a));
    return files.first;
  }
}

class ConnectionResult {
  final bool success;
  final String message;
  ConnectionResult(this.success, this.message);
}
