import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/database_helper.dart';
import '../../models/course_type.dart';
import '../../providers/app_provider.dart';

class CourseTypeSettingsPage extends StatefulWidget {
  const CourseTypeSettingsPage({super.key});

  @override
  State<CourseTypeSettingsPage> createState() => _CourseTypeSettingsPageState();
}

class _CourseTypeSettingsPageState extends State<CourseTypeSettingsPage> {
  final Map<int, int> _countMap = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final provider = context.read<AppProvider>();
    final Map<int, int> counts = {};
    for (var type in provider.courseTypes) {
      if (type.id != null) {
        counts[type.id!] =
            await DatabaseHelper.instance.getCourseCountByType(type.id!);
      }
    }
    if (mounted) {
      setState(() {
        _countMap.clear();
        _countMap.addAll(counts);
      });
    }
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增课程类型'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '类型名称',
            hintText: '请输入类型名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      final success = await context.read<AppProvider>().addCourseType(result);
      if (mounted) {
        if (success) {
          _loadCounts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加失败，类型名称可能已存在')),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(CourseType type) async {
    final controller = TextEditingController(text: type.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑课程类型'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '类型名称',
            hintText: '请输入类型名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != type.name) {
      if (!mounted) return;
      final success =
          await context.read<AppProvider>().updateCourseType(type.id!, result);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改成功')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改失败，类型名称可能已存在')),
          );
        }
      }
    }
  }

  Future<void> _deleteType(CourseType type) async {
    final count = _countMap[type.id] ?? 0;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该类型下还有课程，无法删除')),
      );
      return;
    }
    final success = await context.read<AppProvider>().deleteCourseType(type.id!);
    if (mounted) {
      if (success) {
        setState(() {
          _countMap.remove(type.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final types = provider.courseTypes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程类型管理'),
      ),
      body: types.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    '暂无课程类型',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加类型',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: types.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final List<CourseType> reordered = List.from(types);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                context.read<AppProvider>().reorderCourseTypes(reordered);
              },
              itemBuilder: (context, index) {
                final type = types[index];
                final count = _countMap[type.id] ?? 0;
                return Card(
                  key: ValueKey(type.id),
                  child: ListTile(
                    leading: Icon(Icons.drag_indicator,
                        color: colorScheme.outline),
                    title: Text(type.name),
                    subtitle: Text('$count 个课程'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteType(type),
                    ),
                    onTap: () => _showEditDialog(type),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
