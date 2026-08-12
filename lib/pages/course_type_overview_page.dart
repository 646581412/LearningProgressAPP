import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/course_type.dart';
import 'course_detail_page.dart';
import 'course_edit_page.dart';

class CourseTypeOverviewPage extends StatefulWidget {
  final CourseType? courseType;

  const CourseTypeOverviewPage({super.key, this.courseType});

  @override
  State<CourseTypeOverviewPage> createState() => _CourseTypeOverviewPageState();
}

class _CourseTypeOverviewPageState extends State<CourseTypeOverviewPage> {
  List<Course> _courses = [];
  Map<int, Map<String, int>> _progressMap = {};
  bool _isLoading = true;
  bool _isSortMode = false;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  int? get _typeId => widget.courseType?.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Course> courses =
        await DatabaseHelper.instance.getCoursesByTypeId(_typeId);
    Map<int, Map<String, int>> progressMap = {};
    for (var course in courses) {
      if (course.id != null) {
        progressMap[course.id!] =
            await DatabaseHelper.instance.getCourseProgress(course.id!);
      }
    }
    if (mounted) {
      setState(() {
        _courses = courses;
        _progressMap = progressMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSortOrder() async {
    List<int> orderedIds = _courses.map((c) => c.id!).toList();
    await DatabaseHelper.instance.updateCourseSortOrders(orderedIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('排序已保存')),
      );
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Course item = _courses.removeAt(oldIndex);
      _courses.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typeName = widget.courseType?.name ?? '未分类';

    return Scaffold(
      appBar: AppBar(
        title: Text(typeName),
        actions: [
          if (!_isLoading && _courses.isNotEmpty)
            IconButton(
              icon: Icon(_isSortMode ? Icons.check : Icons.sort),
              tooltip: _isSortMode ? '完成排序' : '编辑排序',
              onPressed: () {
                if (_isSortMode) {
                  _saveSortOrder();
                }
                setState(() {
                  _isSortMode = !_isSortMode;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? _buildEmpty(colorScheme)
              : _isSortMode
                  ? _buildSortView(theme, colorScheme)
                  : _buildNormalView(theme, colorScheme),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CourseEditPage(typeId: _typeId),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无课程',
            style: TextStyle(color: colorScheme.outline),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CourseEditPage(typeId: _typeId),
                ),
              );
              _loadData();
            },
            icon: const Icon(Icons.add),
            label: const Text('添加课程'),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalView(ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final progress = _progressMap[course.id] ?? {'completed': 0, 'studying': 0, 'total': 0};
        final completed = progress['completed'] ?? 0;
        final studying = progress['studying'] ?? 0;
        final total = progress['total'] ?? 0;
        final percent = total > 0 ? (completed / total) : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => CourseDetailPage(
                    courseId: course.id!,
                    onChanged: _loadData,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.courseName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (course.expectedChapters != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${course.expectedChapters}章',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (course.desc != null && course.desc!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      course.desc!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$completed/$total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.play_circle_outline, size: 14, color: colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(
                        '学习中 $studying',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '已完成 $completed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortView(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: colorScheme.primaryContainer.withOpacity(0.3),
          child: Row(
            children: [
              Icon(Icons.drag_indicator, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '长按拖动课程卡片进行排序',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _courses.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final course = _courses[index];
              return Card(
                key: ValueKey(course.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.drag_indicator, color: colorScheme.outline),
                  title: Text(
                    course.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '排序：${index + 1}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
