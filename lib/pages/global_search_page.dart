import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/chapter.dart';
import 'course_detail_page.dart';
import 'chapter_edit_page.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _hasSearched = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = true;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    List<Map<String, dynamic>> results = await DatabaseHelper.instance.globalSearch(keyword.trim());
    setState(() {
      _searchResults = results;
      _hasSearched = true;
      _isSearching = false;
    });
  }

  Color _getStatusColor(int? status, ColorScheme colorScheme) {
    if (status == null) return colorScheme.outline;
    switch (status) {
      case 1:
        return colorScheme.secondary;
      case 2:
        return Colors.green;
      default:
        return colorScheme.outline;
    }
  }

  String _getStatusText(int? status) {
    if (status == null) return '';
    switch (status) {
      case 1:
        return '学习中';
      case 2:
        return '已完成';
      default:
        return '';
    }
  }

  Future<void> _openChapter(int courseId, int chapterId) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CourseDetailPage(
          courseId: courseId,
          highlightChapterId: chapterId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _searchController,
          hintText: '搜索课程、章节、备注...',
          leading: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.search, size: 20),
          ),
          trailing: [
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _hasSearched = false;
                  });
                },
              ),
          ],
          onChanged: (value) {
            if (value.length >= 2) {
              _doSearch(value);
            } else {
              setState(() {
                _searchResults = [];
                _hasSearched = false;
              });
            }
          },
          onSubmitted: _doSearch,
          elevation: WidgetStateProperty.all(0),
          backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHigh),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 72, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        _hasSearched ? '没有找到相关结果' : '输入关键词进行搜索',
                        style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '支持搜索：课程名称、章节标题、备注',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> item = _searchResults[index];
                    bool isChapter = item['result_type'] == 'chapter';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (isChapter && item['chapter_id'] != null) {
                            _openChapter(item['course_id'], item['chapter_id']);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CourseDetailPage(
                                  courseId: item['course_id'],
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isChapter
                                      ? _getStatusColor(
                                          item['chapter_status'] is int
                                              ? item['chapter_status'] as int
                                              : null,
                                          colorScheme,
                                        ).withValues(alpha: 0.15)
                                      : colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isChapter ? Icons.menu_book : Icons.folder,
                                  color: isChapter
                                      ? _getStatusColor(
                                          item['chapter_status'] is int
                                              ? item['chapter_status'] as int
                                              : null,
                                          colorScheme,
                                        )
                                      : colorScheme.primary,
                                  size: 22,
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isChapter ? '章节' : '课程',
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isChapter && item['chapter_status'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                item['chapter_status'] is int
                                                    ? item['chapter_status'] as int
                                                    : null,
                                                colorScheme,
                                              ).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getStatusText(
                                                item['chapter_status'] is int
                                                    ? item['chapter_status'] as int
                                                    : null,
                                              ),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: _getStatusColor(
                                                  item['chapter_status'] is int
                                                      ? item['chapter_status'] as int
                                                      : null,
                                                  colorScheme,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (item['type_name'] != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            item['type_name'] as String,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: colorScheme.tertiary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isChapter
                                          ? (item['chapter_title'] as String? ?? '')
                                          : (item['course_name'] as String? ?? ''),
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '课程：${item['course_name'] ?? ''}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                    if (isChapter && item['chapter_number'] != null)
                                      Text(
                                        '序号：${item['chapter_number']}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      ),
                                    if (isChapter && item['chapter_remark'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '备注：${item['chapter_remark']}',
                                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: colorScheme.outline),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
