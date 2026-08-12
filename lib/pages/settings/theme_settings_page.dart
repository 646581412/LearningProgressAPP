import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, '主题色'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: AppProvider.themeColorPresets.length,
                itemBuilder: (context, index) {
                  final preset = AppProvider.themeColorPresets[index];
                  final color = preset['color'] as Color;
                  final name = preset['name'] as String;
                  final key = preset['key'] as String;
                  final isSelected = provider.themeColorKey == key;
                  return GestureDetector(
                    onTap: () {
                      context.read<AppProvider>().setThemeColor(key);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.outline
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, '深色模式'),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'system',
                  groupValue: provider.themeModeKey,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const Icon(Icons.brightness_auto),
                  title: const Text('跟随系统'),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<AppProvider>().setThemeMode(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'light',
                  groupValue: provider.themeModeKey,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const Icon(Icons.light_mode),
                  title: const Text('浅色模式'),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<AppProvider>().setThemeMode(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'dark',
                  groupValue: provider.themeModeKey,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const Icon(Icons.dark_mode),
                  title: const Text('深色模式'),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<AppProvider>().setThemeMode(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, '默认启动页'),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'overview',
                  groupValue: provider.defaultOpen,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const Icon(Icons.dashboard),
                  title: const Text('总览页面'),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<AppProvider>().setDefaultOpen(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'last_course',
                  groupValue: provider.defaultOpen,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const Icon(Icons.history),
                  title: const Text('上次学习的课程'),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<AppProvider>().setDefaultOpen(value);
                    }
                  },
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
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
