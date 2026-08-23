import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

/// 统计卡片点击后弹出的悬浮列表
enum StatDetailType {
  courses,    // 课程
  chapters,   // 章节
  studying,   // 学习中
  completed,  // 已完成
}

class StatDetailSheet extends StatefulWidget {
  final StatDetailType type;
  final ValueChanged<int> onCourseTap;

  const StatDetailSheet({
    super.key,
    required this.type,
    required this.onCourseTap,
  });

  static Future<void> show(
    BuildContext context, {
    required StatDetailType type,
    required ValueChanged<int> onCourseTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatDetailSheet(type: type, onCourseTap: onCourseTap),
    );
  }

  @override
  State<StatDetailSheet> createState() => _StatDetailSheetState();
}

class _StatDetailSheetState extends State<StatDetailSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Map<String, dynamic>> items = [];
    switch (widget.type) {
      case StatDetailType.courses:
        final courses = await DatabaseHelper.instance.getAllCourses();
        for (var c in courses) {
          if (c.id == null) continue;
          final p = await DatabaseHelper.instance.getCourseProgress(c.id!);
          items.add({
            'course_id': c.id,
            'title': c.courseName,
            'subtitle': c.typeName,
            'extra': '已完成 ${p['completed'] ?? 0} / ${p['display_total'] ?? p['total'] ?? 0}',
            'sort_time': c.lastStudyTime?.toIso8601String() ?? c.createTime.toIso8601String(),
          });
        }
        items.sort((a, b) => (b['sort_time'] as String).compareTo(a['sort_time'] as String));
        break;
      case StatDetailType.chapters:
        items = await DatabaseHelper.instance.getAllChaptersWithCourse(status: null);
        break;
      case StatDetailType.studying:
        items = await DatabaseHelper.instance.getAllChaptersWithCourse(status: 1);
        break;
      case StatDetailType.completed:
        items = await DatabaseHelper.instance.getAllChaptersWithCourse(status: 2);
        break;
    }
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  String get _title {
    switch (widget.type) {
      case StatDetailType.courses:
        return '所有课程';
      case StatDetailType.chapters:
        return '所有章节';
      case StatDetailType.studying:
        return '学习中';
      case StatDetailType.completed:
        return '已完成';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case StatDetailType.courses:
        return Icons.library_books;
      case StatDetailType.chapters:
        return Icons.menu_book;
      case StatDetailType.studying:
        return Icons.play_circle;
      case StatDetailType.completed:
        return Icons.check_circle;
    }
  }

  Color get _accent {
    final cs = Theme.of(context).colorScheme;
    switch (widget.type) {
      case StatDetailType.courses:
        return cs.primary;
      case StatDetailType.chapters:
        return cs.tertiary;
      case StatDetailType.studying:
        return cs.secondary;
      case StatDetailType.completed:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _accent;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖拽条 + 标题
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(_icon, color: accent),
                      const SizedBox(width: 8),
                      Text(_title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        '${_items.length} 项',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 列表内容
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _buildEmpty(theme, colorScheme)
                      : widget.type == StatDetailType.courses
                          ? _buildCourseList(scrollController, theme, colorScheme, accent)
                          : _buildChapterList(scrollController, theme, colorScheme, accent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text('暂无数据', style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildCourseList(ScrollController c, ThemeData theme, ColorScheme colorScheme, Color accent) {
    return ListView.separated(
      controller: c,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final item = _items[index];
        final courseId = item['course_id'] as int;
        return ListTile(
          leading: Icon(Icons.menu_book_outlined, color: accent),
          title: Text(
            item['title'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (item['subtitle'] != null) item['subtitle'] as String,
              item['extra'] as String? ?? '',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            Navigator.of(context).pop();
            widget.onCourseTap(courseId);
          },
        );
      },
    );
  }

  Widget _buildChapterList(ScrollController c, ThemeData theme, ColorScheme colorScheme, Color accent) {
    return ListView.separated(
      controller: c,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final item = _items[index];
        final status = item['chapter_status'] as int? ?? 1;
        final isCompleted = status == 2;
        DateTime? studyDate;
        if (item['study_date'] != null) {
          studyDate = DateTime.tryParse(item['study_date'] as String);
        }
        return ListTile(
          leading: Icon(
            isCompleted ? Icons.check_circle : Icons.play_circle,
            color: isCompleted ? Colors.green : accent,
          ),
          title: Text(
            item['chapter_title'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              item['course_name'] as String? ?? '',
              if (item['type_name'] != null) item['type_name'] as String,
              if (studyDate != null) DateFormat('MM-dd').format(studyDate),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            final courseId = item['course_id'] as int;
            Navigator.of(context).pop();
            widget.onCourseTap(courseId);
          },
        );
      },
    );
  }
}
