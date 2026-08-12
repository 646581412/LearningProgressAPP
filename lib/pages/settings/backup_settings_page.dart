import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/backup_service.dart';
import '../../services/settings_service.dart';
import 'webdav_settings_page.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool _webdavConfigured = false;
  bool _autoSync = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final configured = await SettingsService.instance.isWebdavConfigured();
    final autoSync = await SettingsService.instance.getAutoSync();
    final lastSync = await SettingsService.instance.getLastSyncTime();
    if (mounted) {
      setState(() {
        _webdavConfigured = configured;
        _autoSync = autoSync;
        _lastSyncTime = lastSync;
      });
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    await SettingsService.instance.setAutoSync(value);
    if (mounted) {
      setState(() {
        _autoSync = value;
      });
      if (value && _webdavConfigured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已开启自动同步')),
        );
      }
    }
  }

  String _formatLastSyncTime(DateTime? time) {
    if (time == null) return '从未同步';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份与恢复'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, '本地备份'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file, color: colorScheme.primary),
                  title: const Text('导出到本地'),
                  subtitle: const Text('将数据导出为 JSON 文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => BackupService.exportToLocal(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.file_download, color: colorScheme.tertiary),
                  title: const Text('从本地导入'),
                  subtitle: const Text('从 JSON 文件恢复数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await BackupService.importFromLocal(context);
                    if (mounted) _loadStatus();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, '云同步 (WebDAV)'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _webdavConfigured ? Icons.cloud_done : Icons.cloud_off,
                    color:
                        _webdavConfigured ? Colors.green : colorScheme.outline,
                  ),
                  title: const Text('云同步状态'),
                  subtitle: Text(_webdavConfigured ? '已配置' : '未配置'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.sync, color: colorScheme.primary),
                  title: const Text('自动同步'),
                  subtitle: const Text('每次启动 APP 时自动同步数据'),
                  trailing: Switch(
                    value: _autoSync,
                    onChanged: _webdavConfigured ? _toggleAutoSync : null,
                  ),
                  enabled: _webdavConfigured,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.schedule, color: colorScheme.tertiary),
                  title: const Text('最近同步时间'),
                  subtitle: Text(_formatLastSyncTime(_lastSyncTime)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.settings, color: colorScheme.secondary),
                  title: const Text('WebDAV 设置'),
                  subtitle: const Text('配置 WebDAV 服务器'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WebDavSettingsPage(),
                      ),
                    );
                    if (mounted) _loadStatus();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.cloud_upload, color: colorScheme.primary),
                  title: const Text('立即备份到云'),
                  subtitle: const Text('上传数据到 WebDAV 服务器'),
                  enabled: _webdavConfigured,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _webdavConfigured
                      ? () async {
                          final success = await BackupService.exportToWebDAV(context);
                          if (success && mounted) {
                            await SettingsService.instance.setLastSyncTime(DateTime.now());
                            _loadStatus();
                          }
                        }
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.cloud_download, color: colorScheme.tertiary),
                  title: const Text('从云恢复'),
                  subtitle: const Text('从 WebDAV 服务器恢复数据'),
                  enabled: _webdavConfigured,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _webdavConfigured
                      ? () async {
                          await BackupService.importFromWebDAV(context);
                          if (mounted) _loadStatus();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
