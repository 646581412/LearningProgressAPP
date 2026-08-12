import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/chapter.dart';
import 'chapter_edit_page.dart';
import 'course_edit_page.dart';
import 'global_search_page.dart';

enum ChapterSortMode {
  manual,     // 手动排序（使用 sort_order）
  byNumber,   // 按章节序号
  byCreateTime, // 按添加时间
}

class CourseDetailPage extends StatefulWidget {
  final int courseId;
  final int? highlightChapterId;
  final VoidCallback? onChanged;
  final VoidCallback? onBack;

  const CourseDetailPage({
    super.key,
    required this.courseId,
    this.highlightChapterId,
    this.onChanged,
    this.onBack,
  });

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  Course? _course;
  List<Chapter> _chapters = [];
  Map<String, int> _progress = {};
  int? _filterStatus; // null = 全部, 1 = 学习中, 2 = 已完成
  bool _isEditMode = false;
  bool _isSortMode = false;
  ChapterSortMode _sortMode = ChapterSortMode.manual;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int? _highlightedChapterIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final course = await DatabaseHelper.instance.getCourseById(widget.courseId);
    List<Chapter> chapters;
    switch (_sortMode) {
      case ChapterSortMode.manual:
        chapters = await DatabaseHelper.instance.getChaptersByCourseId(widget.courseId);
        break;
      case ChapterSortMode.byNumber:
        chapters = await DatabaseHelper.instance.getChaptersOrderedByNumber(widget.courseId);
        break;
      case ChapterSortMode.byCreateTime:
        chapters = await DatabaseHelper.instance.getChaptersOrderedByCreateTime(widget.courseId);
        break;
    }
    final progress = await DatabaseHelper.instance.getCourseProgress(widget.courseId);
    if (!mounted) return;

    // 查找需要高亮的章节索引
    int? highlightIndex;
    if (widget.highlightChapterId != null) {
      highlightIndex = chapters.indexWhere((c) => c.id == widget.highlightChapterId);
    }

    setState(() {
      _course = course;
      _chapters = chapters;
      _progress = progress;
      _isLoading = false;
      _highlightedChapterIndex = highlightIndex;
    });

    // 如果有需要高亮的章节，滚动到该位置
    if (highlightIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToChapter(highlightIndex!);
      });
    }
  }

  void _scrollToChapter(int index) {
    if (!_scrollController.hasClients) return;
    // 计算目标位置（每个章节卡片大约 80 像素高，加上课程卡片等）
    // 简化处理：直接滚动到大概位置
    double offset = 0;
    // 顶部 AppBar + 课程信息卡片 + 筛选 chips + 一些 padding
    offset = 250.0 + index * 80.0;
    // 限制在最大滚动范围内
    double maxScroll = _scrollController.position.maxScrollExtent;
    if (offset > maxScroll) offset = maxScroll;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    // 3秒后取消高亮
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedChapterIndex = null;
        });
      }
    });
  }

  void _notifyChanged() {
    _loadData();
    widget.onChanged?.call();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  List<Chapter> get _filteredChapters {
    if (_filterStatus == null) return _chapters;
    return _chapters.where((c) => c.status == _filterStatus).toList();
  }

  Color _statusColor(int status, ColorScheme colorScheme) {
    switch (status) {
      case Chapter.statusStudying:
        return colorScheme.secondary;
      case Chapter.statusCompleted:
        return Colors.green;
      default:
        return colorScheme.outline;
    }
  }

  String _statusText(int status) {
    switch (status) {
      case Chapter.statusStudying:
        return '学习中';
      case Chapter.statusCompleted:
        return '已完成';
      default:
        return '学习中';
    }
  }

  Future<void> _jumpToLastStudy() async {
    final lastChapter = await DatabaseHelper.instance.getLastStudyChapter(widget.courseId);
    if (!mounted) return;
    if (lastChapter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有章节记录')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterEditPage(
          courseId: widget.courseId,
          chapter: lastChapter,
        ),
      ),
    );
    _notifyChanged();
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除章节'),
        content: Text('确认删除《${chapter.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteChapter(chapter.id!);
      _notifyChanged();
    }
  }

  Future<void> _deleteCourse() async {
    if (_course == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确认删除课程《${_course!.courseName}》及其所有章节吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteCourse(_course!.id!);
      if (!mounted) return;
      widget.onChanged?.call();
      _handleBack();
    }
  }

  Future<void> _editCourseInfo() async {
    if (_course == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CourseEditPage(course: _course),
      ),
    );
    if (result == true) {
      _notifyChanged();
    }
  }

  Future<void> _addChapter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterEditPage(courseId: widget.courseId),
      ),
    );
    _notifyChanged();
  }

  Future<void> _editChapter(Chapter chapter) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterEditPage(
          courseId: widget.courseId,
          chapter: chapter,
        ),
      ),
    );
    _notifyChanged();
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const GlobalSearchPage()),
    );
    _notifyChanged();
  }

  Future<void> _applySort(ChapterSortMode mode) async {
    setState(() {
      _sortMode = mode;
      _isLoading = true;
    });

    if (mode == ChapterSortMode.byNumber || mode == ChapterSortMode.byCreateTime) {
      // 切换到非手动排序时，也要把当前顺序保存为 sort_order
      List<Chapter> chapters;
      if (mode == ChapterSortMode.byNumber) {
        chapters = await DatabaseHelper.instance.getChaptersOrderedByNumber(widget.courseId);
      } else {
        chapters = await DatabaseHelper.instance.getChaptersOrderedByCreateTime(widget.courseId);
      }
      await DatabaseHelper.instance.reorderChapters(widget.courseId, chapters);
    }

    if (!mounted) return;
    await _loadData();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Chapter item = _chapters.removeAt(oldIndex);
    _chapters.insert(newIndex, item);
    // 立即更新 UI
    setState(() {});
    // 保存到数据库
    await DatabaseHelper.instance.reorderChapters(widget.courseId, _chapters);
    // 重置为手动排序模式
    if (_sortMode != ChapterSortMode.manual) {
      _sortMode = ChapterSortMode.manual;
    }
  }

  void _toggleSortMode() {
    setState(() {
      _isSortMode = !_isSortMode;
      if (_isSortMode) {
        _isEditMode = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (_isLoading) {
      return PopScope(
        canPop: widget.onBack == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBack,
            ),
            title: const Text('课程详情'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_course == null) {
      return PopScope(
        canPop: widget.onBack == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBack,
            ),
            title: const Text('课程详情'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text('课程不存在或已删除', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _handleBack,
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
          tooltip: '返回',
        ),
        title: Text(
          _course!.courseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: _openSearch,
          ),
          if (_isSortMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '退出排序',
              onPressed: _toggleSortMode,
            )
          else
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: '排序章节',
              onPressed: _toggleSortMode,
            ),
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            tooltip: _isEditMode ? '完成' : '修改',
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
                if (_isEditMode) _isSortMode = false;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'jump') {
                _jumpToLastStudy();
              } else if (value == 'edit_course') {
                _editCourseInfo();
              } else if (value == 'sort_manual') {
                _applySort(ChapterSortMode.manual);
              } else if (value == 'sort_number') {
                _applySort(ChapterSortMode.byNumber);
              } else if (value == 'sort_create') {
                _applySort(ChapterSortMode.byCreateTime);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'jump',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('跳到最近学习'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_course',
                child: Row(
                  children: [
                    Icon(Icons.edit_note),
                    SizedBox(width: 8),
                    Text('编辑课程信息'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('章节排序', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'sort_manual',
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_vert,
                      color: _sortMode == ChapterSortMode.manual ? colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '手动排序',
                      style: TextStyle(
                        color: _sortMode == ChapterSortMode.manual ? colorScheme.primary : null,
                        fontWeight: _sortMode == ChapterSortMode.manual ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort_number',
                child: Row(
                  children: [
                    Icon(
                      Icons.format_list_numbered,
                      color: _sortMode == ChapterSortMode.byNumber ? colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '按章节序号排序',
                      style: TextStyle(
                        color: _sortMode == ChapterSortMode.byNumber ? colorScheme.primary : null,
                        fontWeight: _sortMode == ChapterSortMode.byNumber ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort_create',
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: _sortMode == ChapterSortMode.byCreateTime ? colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '按添加时间排序',
                      style: TextStyle(
                        color: _sortMode == ChapterSortMode.byCreateTime ? colorScheme.primary : null,
                        fontWeight: _sortMode == ChapterSortMode.byCreateTime ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 课程信息卡片
          _buildCourseInfoCard(theme, colorScheme),
          // 排序模式提示
          if (_isSortMode) _buildSortBanner(theme, colorScheme),
          // 筛选 chips
          if (!_isSortMode) _buildFilterChips(theme, colorScheme),
          // 章节列表
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSortMode
                  ? _buildChapterListReorder(theme, colorScheme)
                  : _isEditMode
                      ? _buildChapterListEdit(theme, colorScheme)
                      : _buildChapterListView(theme, colorScheme),
            ),
          ),
          // 编辑模式下的删除课程按钮
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isEditMode
                ? _buildDeleteCourseButton(theme, colorScheme)
                : const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: _isEditMode || _isSortMode
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                key: const ValueKey('add_chapter_fab'),
                onPressed: _addChapter,
                icon: const Icon(Icons.add),
                label: const Text('新增章节'),
              ),
      ),
      ),
    );
  }

  Widget _buildSortBanner(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '排序模式：长按并拖动右侧手柄调整顺序',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _toggleSortMode,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfoCard(ThemeData theme, ColorScheme colorScheme) {
    final int actualTotal = _progress['total'] ?? 0;
    final int displayTotal = _progress['display_total'] ?? actualTotal;
    final int completed = _progress['completed'] ?? 0;
    final int studying = _progress['studying'] ?? 0;
    final double percent = displayTotal > 0 ? completed / displayTotal : 0;
    final percentClamped = percent > 1.0 ? 1.0 : percent;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _course!.courseName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_course!.typeName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _course!.typeName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '学习中 $studying',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已完成 $completed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ),
                if ((_course!.expectedChapters ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '共 ${_course!.expectedChapters} 课',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (_course!.desc != null && _course!.desc!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _course!.desc!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 进度条
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentClamped,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completed / $displayTotal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(percentClamped * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _FilterChipWidget(
              label: '全部',
              isSelected: _filterStatus == null,
              color: colorScheme.primary,
              onSelected: () => setState(() => _filterStatus = null),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChipWidget(
              label: '学习中',
              isSelected: _filterStatus == Chapter.statusStudying,
              color: colorScheme.secondary,
              onSelected: () => setState(() => _filterStatus = Chapter.statusStudying),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChipWidget(
              label: '已完成',
              isSelected: _filterStatus == Chapter.statusCompleted,
              color: Colors.green,
              onSelected: () => setState(() => _filterStatus = Chapter.statusCompleted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterListView(ThemeData theme, ColorScheme colorScheme) {
    if (_filteredChapters.isEmpty) {
      return Center(
        key: const ValueKey('empty_view'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              _chapters.isEmpty ? '还没有章节，点击右下角添加' : '没有符合条件的章节',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('chapter_list'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredChapters.length,
      itemBuilder: (context, index) {
        final chapter = _filteredChapters[index];
        final isHighlighted = _highlightedChapterIndex != null && 
                              _highlightedChapterIndex == index;
        return _buildChapterCard(chapter, theme, colorScheme, 
            isEditMode: false, isHighlighted: isHighlighted);
      },
    );
  }

  Widget _buildChapterListEdit(ThemeData theme, ColorScheme colorScheme) {
    if (_filteredChapters.isEmpty) {
      return Center(
        key: const ValueKey('empty_edit'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              _chapters.isEmpty ? '还没有章节' : '没有符合条件的章节',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('chapter_list_edit'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredChapters.length,
      itemBuilder: (context, index) {
        final chapter = _filteredChapters[index];
        return Dismissible(
          key: ValueKey('dismiss_${chapter.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDeleteChapter(chapter),
          child: _buildChapterCard(chapter, theme, colorScheme, isEditMode: true),
        );
      },
    );
  }

  Widget _buildChapterListReorder(ThemeData theme, ColorScheme colorScheme) {
    // 排序模式下不过滤，显示全部章节
    final chapters = _chapters;
    if (chapters.isEmpty) {
      return Center(
        key: const ValueKey('empty_reorder'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '还没有章节可排序',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      key: const ValueKey('chapter_list_reorder'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chapters.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return _buildReorderableCard(chapter, theme, colorScheme, index);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surface,
          child: child,
        );
      },
    );
  }

  Widget _buildReorderableCard(
    Chapter chapter,
    ThemeData theme,
    ColorScheme colorScheme,
    int index,
  ) {
    final statusColor = _statusColor(chapter.status, colorScheme);
    final key = ValueKey('reorder_${chapter.id}');

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Icon(
                  Icons.drag_indicator,
                  color: colorScheme.outline,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 状态色条
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusText(chapter.status),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (chapter.number != null && chapter.number!.isNotEmpty)
                        Text(
                          chapter.number!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chapter.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteChapter(Chapter chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除章节'),
        content: Text('确认删除《${chapter.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteChapter(chapter.id!);
      _notifyChanged();
    }
    return confirm;
  }

  Widget _buildChapterCard(
    Chapter chapter,
    ThemeData theme,
    ColorScheme colorScheme, {
    required bool isEditMode,
    bool isHighlighted = false,
  }) {
    final statusColor = _statusColor(chapter.status, colorScheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(color: colorScheme.primary, width: 3)
            : null,
        color: isHighlighted
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: isEditMode ? null : () => _editChapter(chapter),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 状态色条
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isHighlighted ? colorScheme.primary : statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isHighlighted ? colorScheme.primary : statusColor).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusText(chapter.status),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isHighlighted ? colorScheme.primary : statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (chapter.number != null && chapter.number!.isNotEmpty)
                            Text(
                              chapter.number!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          if (isHighlighted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '搜索结果',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chapter.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          if (chapter.studyDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('yyyy-MM-dd').format(chapter.studyDate!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (chapter.remark != null && chapter.remark!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            chapter.remark!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isEditMode)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: colorScheme.error,
                    tooltip: '删除',
                    onPressed: () => _deleteChapter(chapter),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: colorScheme.outline,
                    onPressed: () => _editChapter(chapter),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteCourseButton(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        key: const ValueKey('delete_course_btn'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _deleteCourse,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.delete_forever),
          label: const Text(
            '删除课程',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onSelected;

  const _FilterChipWidget({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Center(child: Text(label)),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
