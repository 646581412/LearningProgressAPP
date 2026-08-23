import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/course.dart';
import 'stat_detail_sheet.dart';

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
  int _streak = 0;
  int _totalDays = 0;
  List<Map<String, dynamic>>? _recentRecords;
  bool _loading = true;

  // 月历状态
  static final int _kBaseYear = 2000;
  late final PageController _monthController;
  late final int _initialPage;
  late DateTime _currentMonth; // 当前显示的月份（first day）
  int _currentMonthDayCount = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _initialPage = (now.year - _kBaseYear) * 12 + (now.month - 1);
    _monthController = PageController(initialPage: _initialPage);
    _loadStats();
    _loadMonthDayCount();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getOverallStatistics();
    final streak = await DatabaseHelper.instance.getStudyStreak();
    final totalDays = await DatabaseHelper.instance.getTotalStudyDays();
    final recent = await DatabaseHelper.instance.getRecentStudyRecords(limit: 5);
    if (mounted) {
      setState(() {
        _stats = stats;
        _streak = streak;
        _totalDays = totalDays;
        _recentRecords = recent;
        _loading = false;
      });
    }
  }

  Future<void> _loadMonthDayCount() async {
    final count = await DatabaseHelper.instance.getStudyDatesInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    if (mounted) {
      setState(() {
        _currentMonthDayCount = count.length;
      });
    }
  }

  DateTime _monthForPage(int page) {
    int year = _kBaseYear + page ~/ 12;
    int month = (page % 12) + 1;
    return DateTime(year, month, 1);
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
        await _loadMonthDayCount();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCards(),
          const SizedBox(height: 16),
          _buildMonthCheckinCard(),
          const SizedBox(height: 16),
          _buildMedalProgress(),
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
              onTap: () => StatDetailSheet.show(context,
                  type: StatDetailType.courses, onCourseTap: widget.onCourseTap),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.menu_book,
              label: '章节',
              value: '$chapters',
              color: colorScheme.tertiary,
              onTap: () => StatDetailSheet.show(context,
                  type: StatDetailType.chapters, onCourseTap: widget.onCourseTap),
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
              onTap: () => StatDetailSheet.show(context,
                  type: StatDetailType.studying, onCourseTap: widget.onCourseTap),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.check_circle,
              label: '已完成',
              value: '$completed',
              color: Colors.green,
              onTap: () => StatDetailSheet.show(context,
                  type: StatDetailType.completed, onCourseTap: widget.onCourseTap),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthCheckinCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text('本月打卡', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  DateFormat('yyyy年M月').format(_currentMonth),
                  style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '上一月',
                  onPressed: () => _monthController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '下一月',
                  onPressed: () => _monthController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 360,
              child: PageView.builder(
                controller: _monthController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentMonth = _monthForPage(page);
                  });
                  _loadMonthDayCount();
                },
                itemBuilder: (context, page) {
                  final month = _monthForPage(page);
                  return _MonthCalendarGrid(year: month.year, month: month.month);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalProgress() {
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
                Icon(Icons.emoji_events, color: Colors.amber[700], size: 22),
                const SizedBox(width: 8),
                Text('奖牌进度', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MedalItem(
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                    value: '$_streak',
                    label: '连续学习',
                    unit: '天',
                  ),
                ),
                _verticalDivider(colorScheme),
                Expanded(
                  child: _MedalItem(
                    icon: Icons.calendar_today,
                    color: colorScheme.primary,
                    value: '$_currentMonthDayCount',
                    label: '本月学习',
                    unit: '天',
                  ),
                ),
                _verticalDivider(colorScheme),
                Expanded(
                  child: _MedalItem(
                    icon: Icons.emoji_events,
                    color: Colors.amber[700]!,
                    value: '$_totalDays',
                    label: '总学习',
                    unit: '天',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colorScheme.outlineVariant,
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

/// 单个月历网格（自带数据加载，用于 PageView）
class _MonthCalendarGrid extends StatefulWidget {
  final int year;
  final int month;
  const _MonthCalendarGrid({required this.year, required this.month});

  @override
  State<_MonthCalendarGrid> createState() => _MonthCalendarGridState();
}

class _MonthCalendarGridState extends State<_MonthCalendarGrid> {
  Set<int> _studyDays = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final days = await DatabaseHelper.instance.getStudyDatesInMonth(widget.year, widget.month);
    if (mounted) {
      setState(() {
        _studyDays = days;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final firstOfMonth = DateTime(widget.year, widget.month, 1);
    final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
    int firstWeekday = firstOfMonth.weekday; // 1=Mon..7=Sun
    int leadingBlanks = firstWeekday - 1;

    // 构建单元格列表（null = 空白）
    List<int?> cells = [];
    for (int i = 0; i < leadingBlanks; i++) cells.add(null);
    for (int day = 1; day <= daysInMonth; day++) cells.add(day);
    while (cells.length % 7 != 0) cells.add(null);

    return Column(
      children: [
        // 星期表头
        Row(
          children: weekdays.map((w) {
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          ..._buildWeekRows(cells, today, theme, colorScheme),
      ],
    );
  }

  List<Widget> _buildWeekRows(
      List<int?> cells, DateTime today, ThemeData theme, ColorScheme colorScheme) {
    List<Widget> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < 7; j++) {
        int? day = cells[i + j];
        bool hasStudy = day != null && _studyDays.contains(day);
        bool isToday = day != null &&
            widget.year == today.year &&
            widget.month == today.month &&
            day == today.day;
        rowChildren.add(Expanded(
          child: _DayCell(
            day: day,
            hasStudy: hasStudy,
            isToday: isToday,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: rowChildren),
      ));
    }
    return rows;
  }
}

class _DayCell extends StatelessWidget {
  final int? day;
  final bool hasStudy;
  final bool isToday;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _DayCell({
    required this.day,
    required this.hasStudy,
    required this.isToday,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      height: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? colorScheme.primary : Colors.transparent,
              border: isToday
                  ? null
                  : Border.all(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Text(
              '$day',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          if (hasStudy)
            Icon(Icons.emoji_events, size: 16, color: Colors.amber[700])
          else
            const SizedBox(height: 16, width: 16),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedalItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String unit;

  const _MedalItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
