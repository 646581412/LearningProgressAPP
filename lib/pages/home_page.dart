import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/course_type.dart';
import '../services/settings_service.dart';
import '../services/backup_service.dart';
import 'overview_page.dart';
import 'course_detail_page.dart';
import 'course_edit_page.dart';
import 'course_type_overview_page.dart';
import 'settings_page.dart';
import 'global_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // 0 = overview, 1+ = course detail
  int? _selectedCourseId;
  List<Course> _allCourses = [];
  Map<int, Map<String, int>> _progressMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataAndInit();
  }

  Future<void> _loadDataAndInit() async {
    await _loadData();
    // 检查默认启动页设置
    String defaultOpen = await SettingsService.instance.getDefaultOpen();
    if (defaultOpen == 'last_course') {
      Course? lastCourse = await DatabaseHelper.instance.getLastStudiedCourse();
      if (lastCourse != null && lastCourse.id != null) {
        setState(() {
          _selectedCourseId = lastCourse.id;
          _selectedIndex = 1;
        });
      }
    }
    // 自动同步
    _autoSync();
  }

  Future<void> _autoSync() async {
    try {
      final autoSync = await SettingsService.instance.getAutoSync();
      final configured = await SettingsService.instance.isWebdavConfigured();
      if (autoSync && configured) {
        await Future.delayed(const Duration(seconds: 2));
        final success = await BackupService.exportToWebDAV(context);
        if (success) {
          await SettingsService.instance.setLastSyncTime(DateTime.now());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('自动云同步成功')),
            );
          }
        }
      }
    } catch (_) {
      // 自动同步失败不影响主流程
    }
  }

  Future<void> _loadData() async {
    List<Course> courses = await DatabaseHelper.instance.getAllCourses();
    Map<int, Map<String, int>> progressMap = {};
    for (var course in courses) {
      if (course.id != null) {
        progressMap[course.id!] = await DatabaseHelper.instance.getCourseProgress(course.id!);
      }
    }
    setState(() {
      _allCourses = courses;
      _progressMap = progressMap;
      _isLoading = false;
    });
  }

  void _navigateToOverview() {
    setState(() {
      _selectedIndex = 0;
      _selectedCourseId = null;
    });
  }

  void _navigateToCourse(int courseId) {
    setState(() {
      _selectedCourseId = courseId;
      _selectedIndex = 1;
    });
  }

  Future<void> _navigateToSettings() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
    // 返回后刷新数据（课程类型可能变了）
    await context.read<AppProvider>().loadCourseTypes();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // 课程详情页是独立的 Scaffold（有自己的 AppBar、FAB 等）
    if (!_isLoading && _selectedIndex > 0 && _selectedCourseId != null) {
      return CourseDetailPage(
        key: ValueKey('course_$_selectedCourseId'),
        courseId: _selectedCourseId!,
        onChanged: _loadData,
        onBack: _navigateToOverview,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习进度'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GlobalSearchPage()),
              );
              _loadData();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(provider),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : OverviewPage(
              key: const ValueKey('overview'),
              courses: _allCourses,
              progressMap: _progressMap,
              onCourseTap: _navigateToCourse,
              onRefresh: _loadData,
            ),
    );
  }

  Widget _buildDrawer(AppProvider provider) {
    List<CourseType> types = provider.courseTypes;
    final colorScheme = Theme.of(context).colorScheme;

    // 按类型分组课程
    Map<int?, List<Course>> groupedCourses = {};
    for (var course in _allCourses) {
      groupedCourses.putIfAbsent(course.typeId, () => []).add(course);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.school, size: 40, color: colorScheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(
                  '学习进度',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(_selectedIndex == 0 ? Icons.dashboard : Icons.dashboard_outlined),
            title: const Text('总览'),
            selected: _selectedIndex == 0,
            onTap: () {
              _navigateToOverview();
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
          // 课程类型分组（始终显示，确保"添加课程"按钮可用）
          for (var type in types)
            _CourseTypeExpansionTile(
              typeName: type.name,
              courses: groupedCourses[type.id] ?? [],
              progressMap: _progressMap,
              selectedCourseId: _selectedCourseId,
              onCourseTap: (id) {
                _navigateToCourse(id);
                Navigator.of(context).pop();
              },
              onTypeTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CourseTypeOverviewPage(courseType: type),
                  ),
                ).then((_) => _loadData());
              },
              onAddCourse: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CourseEditPage(typeId: type.id),
                  ),
                ).then((_) => _loadData());
              },
            ),
          // 未分类（有未分类课程时才显示）
          if ((groupedCourses[null]?.length ?? 0) > 0)
            _CourseTypeExpansionTile(
              typeName: '未分类',
              courses: groupedCourses[null]!,
            progressMap: _progressMap,
            selectedCourseId: _selectedCourseId,
            onCourseTap: (id) {
              _navigateToCourse(id);
              Navigator.of(context).pop();
            },
            onTypeTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CourseTypeOverviewPage(courseType: null),
                ),
              ).then((_) => _loadData());
            },
            onAddCourse: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CourseEditPage(),
                ),
              ).then((_) => _loadData());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            onTap: () {
              Navigator.of(context).pop();
              _navigateToSettings();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CourseTypeExpansionTile extends StatelessWidget {
  final String typeName;
  final List<Course> courses;
  final Map<int, Map<String, int>> progressMap;
  final int? selectedCourseId;
  final ValueChanged<int> onCourseTap;
  final VoidCallback onTypeTap;
  final VoidCallback onAddCourse;

  const _CourseTypeExpansionTile({
    required this.typeName,
    required this.courses,
    required this.progressMap,
    required this.selectedCourseId,
    required this.onCourseTap,
    required this.onTypeTap,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: GestureDetector(
        onTap: onTypeTap,
        child: Row(
          children: [
            Icon(Icons.category_outlined, size: 18, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                typeName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
      subtitle: Text('${courses.length} 个课程'),
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ...courses.map((course) {
          final progress = progressMap[course.id];
          final completed = progress?['completed'] ?? 0;
          final total = progress?['total'] ?? 0;
          return ListTile(
            selected: course.id == selectedCourseId,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(
              course.courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              total > 0 ? '已完成 $completed/$total' : '暂无章节',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => onCourseTap(course.id!),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddCourse,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加课程'),
            ),
          ),
        ),
      ],
    );
  }
}
