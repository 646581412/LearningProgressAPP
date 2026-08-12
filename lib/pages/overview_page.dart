import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/course.dart';

class OverviewPage extends StatefulWidget {
  final List<Course> courses;
  final Map<int, Map<String, int>> progressMap;
  final ValueChanged<int> onCourseTap;
  final VoidCallback onRefresh;

  const OverviewPage({
    super.key,
    required this.courses,
    required this.progressMap,
    required this.onCourseTap,
    required this.onRefresh,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Map<String, int>? _stats;
  List<Map<String, dynamic>>? _weeklyStats;
  List<Map<String, dynamic>>? _monthlyStats;
  int _streak = 0;
  List<Map<String, dynamic>>? _recentRecords;
  bool _loading = true;
  bool _showMonthly = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getOverallStatistics();
    final weekly = await DatabaseHelper.instance.getWeeklyStudyStats();
    final monthly = await DatabaseHelper.instance.getMonthlyStudyStats();
    final streak = await DatabaseHelper.instance.getStudyStreak();
    final recent = await DatabaseHelper.instance.getRecentStudyRecords(limit: 5);
    setState(() {
      _stats = stats;
      _weeklyStats = weekly;
      _monthlyStats = monthly;
      _streak = streak;
      _recentRecords = recent;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCards(),
          const SizedBox(height: 16),
          _buildChartSection(),
          const SizedBox(height: 16),
          _buildStreakCard(),
          const SizedBox(height: 16),
          _buildRecentRecords(),
          const SizedBox(height: 16),
          _buildCourseProgressList(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    int courses = _stats?['courses'] ?? 0;
    int chapters = _stats?['chapters'] ?? 0;
    int completed = _stats?['completed'] ?? 0;
    int studying = _stats?['studying'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('学习概览', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.library_books,
              label: '课程',
              value: '$courses',
              color: colorScheme.primary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.menu_book,
              label: '章节',
              value: '$chapters',
              color: colorScheme.tertiary,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.play_circle,
              label: '学习中',
              value: '$studying',
              color: colorScheme.secondary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.check_circle,
              label: '已完成',
              value: '$completed',
              color: Colors.green,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _showMonthly ? '本月学习' : '本周学习',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showMonthly = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: !_showMonthly ? colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '本周',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: !_showMonthly ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                              fontWeight: !_showMonthly ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showMonthly = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _showMonthly ? colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '本月',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _showMonthly ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                              fontWeight: _showMonthly ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _showMonthly ? _buildMonthlyChart(theme, colorScheme) : _buildWeeklyChart(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(ThemeData theme, ColorScheme colorScheme) {
    if (_weeklyStats == null || _weeklyStats!.isEmpty) {
      return const SizedBox(height: 120);
    }

    double maxY = 0;
    for (var item in _weeklyStats!) {
      double count = (item['count'] as num).toDouble();
      if (count > maxY) maxY = count;
    }
    maxY = maxY < 3 ? 3 : maxY + 1;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()}',
                  TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _weeklyStats!.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _weeklyStats![index]['weekday'] as String,
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _weeklyStats!.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['count'] as num).toDouble(),
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  width: 20,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(ThemeData theme, ColorScheme colorScheme) {
    if (_monthlyStats == null || _monthlyStats!.isEmpty) {
      return const SizedBox(height: 120);
    }

    double maxY = 0;
    for (var item in _monthlyStats!) {
      double count = (item['count'] as num).toDouble();
      if (count > maxY) maxY = count;
    }
    maxY = maxY < 3 ? 3 : maxY + 1;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} 章',
                  TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _monthlyStats!.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _monthlyStats![index]['weekday'] as String,
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _monthlyStats!.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['count'] as num).toDouble(),
                  color: colorScheme.tertiary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  width: 24,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连续学习', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  Text('$_streak 天', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (_streak > 0)
              Text('加油！', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecords() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_recentRecords == null || _recentRecords!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近学习', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._recentRecords!.map((record) {
              DateTime? studyDate;
              if (record['study_date'] != null) {
                studyDate = DateTime.tryParse(record['study_date'] as String);
              }
              String courseName = record['course_name'] as String? ?? '';
              String? typeName = record['type_name'] as String?;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  record['chapter_status'] == 2 ? Icons.check_circle : Icons.play_circle,
                  color: record['chapter_status'] == 2 ? Colors.green : theme.colorScheme.secondary,
                  size: 28,
                ),
                title: Text(
                  record['chapter_title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  typeName != null && typeName.isNotEmpty
                      ? '$courseName · $typeName · ${studyDate != null ? DateFormat('MM-dd').format(studyDate) : ''}'
                      : '$courseName · ${studyDate != null ? DateFormat('MM-dd').format(studyDate) : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  int courseId = record['course_id'] as int;
                  widget.onCourseTap(courseId);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseProgressList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (widget.courses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.library_books, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('还没有课程', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              Text('从左侧菜单添加课程', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('课程进度', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...widget.courses.map((course) {
              Map<String, int> progress = widget.progressMap[course.id] ?? {};
              int displayTotal = progress['display_total'] ?? progress['total'] ?? 0;
              int completed = progress['completed'] ?? 0;
              double percent = displayTotal > 0 ? completed / displayTotal : 0;
              if (percent > 1.0) percent = 1.0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (course.typeName != null && course.typeName!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          course.typeName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 6,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$completed/$displayTotal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () => widget.onCourseTap(course.id!),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
