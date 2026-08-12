import 'package:flutter/material.dart';
import '../../services/web_server_service.dart';

class WebManagementSettingsPage extends StatefulWidget {
  const WebManagementSettingsPage({super.key});

  @override
  State<WebManagementSettingsPage> createState() =>
      _WebManagementSettingsPageState();
}

class _WebManagementSettingsPageState extends State<WebManagementSettingsPage> {
  final _portController = TextEditingController(text: '8080');
  bool _running = false;
  String? _ipAddress;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final running = WebServerService.instance.isRunning;
    final ip = await WebServerService.instance.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _running = running;
        _ipAddress = ip;
      });
    }
  }

  Future<void> _toggleServer() async {
    if (_running) {
      await WebServerService.instance.stop();
      if (mounted) {
        setState(() {
          _running = false;
          _errorMsg = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网页管理已关闭')),
        );
      }
    } else {
      final port = int.tryParse(_portController.text.trim()) ?? 8080;
      if (port < 1024 || port > 65535) {
        setState(() => _errorMsg = '端口范围：1024-65535');
        return;
      }
      final success = await WebServerService.instance.start(port: port);
      if (mounted) {
        if (success) {
          setState(() {
            _running = true;
            _errorMsg = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网页管理已启动')),
          );
        } else {
          setState(() {
            _errorMsg = '启动失败，端口可能被占用，请更换端口';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('网页管理'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _running ? Icons.wifi : Icons.wifi_off,
                        color: _running ? Colors.green : colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _running ? '服务运行中' : '服务未启动',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _running ? Colors.green : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '使用说明',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 启动服务后，在同一局域网内的设备浏览器中输入下方地址即可访问\n'
                    '2. 可以查看、添加、编辑、删除课程和章节\n'
                    '3. 建议在使用完毕后关闭服务',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('端口号', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '8080',
                      prefixIcon: Icon(Icons.router),
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_running,
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  if (_running && _ipAddress != null) ...[
                    const SizedBox(height: 16),
                    const Text('访问地址', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.language, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'http://$_ipAddress:${_portController.text.trim()}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _toggleServer,
            icon: Icon(_running ? Icons.stop : Icons.play_arrow),
            label: Text(_running ? '关闭服务' : '启动服务'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: _running ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
