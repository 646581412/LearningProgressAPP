import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import 'settings/theme_settings_page.dart';
import 'settings/course_type_settings_page.dart';
import 'settings/backup_settings_page.dart';
import 'settings/web_management_settings_page.dart';
import 'settings/password_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  String _getThemeModeName(String mode) {
    switch (mode) {
      case 'light':
        return '浅色模式';
      case 'dark':
        return '深色模式';
      default:
        return '跟随系统';
    }
  }

  void _showAboutDialog(BuildContext context) {
    const githubUrl = 'https://github.com/646581412/LearningProgressAPP';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school),
            SizedBox(width: 8),
            Text('关于'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '学习进度',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('版本：1.0.0'),
            const SizedBox(height: 8),
            const Text(
              '本地记录网课学习进度工具',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '项目地址',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onLongPress: () async {
                await Clipboard.setData(const ClipboardData(text: githubUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接已复制到剪贴板')),
                  );
                }
              },
              onTap: () async {
                final uri = Uri.parse(githubUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await Clipboard.setData(const ClipboardData(text: githubUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('链接已复制到剪贴板')),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.code, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        githubUrl,
                        style: TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.copy, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '点击打开 / 长按复制',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.palette, color: colorScheme.primary),
              title: const Text('外观设置'),
              subtitle: Text(
                '${AppProvider.getColorName(provider.themeColorKey)} · ${_getThemeModeName(provider.themeModeKey)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ThemeSettingsPage(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.category, color: colorScheme.tertiary),
              title: const Text('课程类型管理'),
              subtitle: Text('共 ${provider.courseTypes.length} 个类型'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CourseTypeSettingsPage(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.backup, color: colorScheme.secondary),
              title: const Text('数据备份与恢复'),
              subtitle: const Text('本地备份 / WebDAV 备份'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BackupSettingsPage(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.language, color: colorScheme.primary),
              title: const Text('网页管理'),
              subtitle: const Text('局域网内通过浏览器管理课程'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const WebManagementSettingsPage(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline, color: colorScheme.tertiary),
              title: const Text('密码管理'),
              subtitle: const Text('设置应用启动密码'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PasswordSettingsPage(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: colorScheme.outline),
              title: const Text('关于'),
              subtitle: const Text('版本信息'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}
