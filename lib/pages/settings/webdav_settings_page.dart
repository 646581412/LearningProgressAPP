import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/settings_service.dart';
import '../../services/backup_service.dart';
import '../../services/webdav_service.dart';

class WebDavSettingsPage extends StatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  State<WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends State<WebDavSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController =
      TextEditingController(text: SettingsService.defaultWebdavPath);
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await SettingsService.instance.getWebdavConfig();
    if (mounted) {
      setState(() {
        _urlController.text = config['url'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
        _pathController.text = config['path'] ?? SettingsService.defaultWebdavPath;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    String url = _urlController.text.trim();
    final hadHttp = url.startsWith('http://') && !url.startsWith('https://');
    if (hadHttp) {
      url = 'https://${url.substring(7)}';
      _urlController.text = url;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    await SettingsService.instance.setWebdavConfig(
      url: url,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      path: _pathController.text.trim(),
    );

    final result = await BackupService.testWebDAVConnection();
    if (mounted) {
      setState(() {
        _testing = false;
        _testSuccess = result.success;
        _testResult = result.message;
      });
      final message = hadHttp && result.success
          ? '已自动修正为 HTTPS，连接成功'
          : result.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result.success ? null : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await SettingsService.instance.setWebdavConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      path: _pathController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'https://dav.jianguoyun.com/dav/',
                  prefixIcon: Icon(Icons.cloud),
                  helperText: '需使用 https:// 协议',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入服务器地址';
                  }
                  if (!value.trim().startsWith('https://')) {
                    return '建议使用 https:// 协议（坚果云等必须使用 HTTPS）';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '请输入用户名',
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入用户名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pathController,
                decoration: const InputDecoration(
                  labelText: '存储路径',
                  hintText: '/study_progress/',
                  prefixIcon: Icon(Icons.folder),
                ),
                textInputAction: TextInputAction.done,
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: _testResult!));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('错误信息已复制到剪贴板')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testSuccess == true
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _testSuccess == true
                            ? Colors.green.withOpacity(0.5)
                            : Colors.red.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testSuccess == true
                              ? Icons.check_circle
                              : Icons.error,
                          color: _testSuccess == true ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              color: _testSuccess == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                        if (_testSuccess != true)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.copy, size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_testSuccess != true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Text(
                      '长按错误信息可复制',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      child: _testing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
