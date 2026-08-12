import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/chapter.dart';

class ChapterEditPage extends StatefulWidget {
  final int courseId;
  final Chapter? chapter;

  const ChapterEditPage({
    super.key,
    required this.courseId,
    this.chapter,
  });

  @override
  State<ChapterEditPage> createState() => _ChapterEditPageState();
}

class _ChapterEditPageState extends State<ChapterEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final _remarkController = TextEditingController();
  int _selectedStatus = Chapter.statusStudying;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.chapter != null) {
      _titleController.text = widget.chapter!.title;
      _numberController.text = widget.chapter!.number ?? '';
      _remarkController.text = widget.chapter!.remark ?? '';
      _selectedStatus = widget.chapter!.status;
      _selectedDate = widget.chapter!.studyDate;
    } else {
      _selectedStatus = Chapter.statusStudying;
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveChapter() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final number = _numberController.text.trim().isEmpty ? null : _numberController.text.trim();
    final remark = _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim();

    if (widget.chapter == null) {
      final newChapter = Chapter(
        courseId: widget.courseId,
        title: title,
        number: number,
        status: _selectedStatus,
        studyDate: _selectedDate,
        remark: remark,
        createTime: DateTime.now(),
      );
      await DatabaseHelper.instance.insertChapter(newChapter);
    } else {
      final updatedChapter = Chapter(
        id: widget.chapter!.id,
        courseId: widget.courseId,
        title: title,
        number: number,
        status: _selectedStatus,
        studyDate: _selectedDate,
        remark: remark,
        createTime: widget.chapter!.createTime,
      );
      await DatabaseHelper.instance.updateChapter(updatedChapter);
    }

    // 状态为 学习中 或 已完成 时更新课程的最近学习时间
    if (_selectedStatus == Chapter.statusStudying || _selectedStatus == Chapter.statusCompleted) {
      await DatabaseHelper.instance.updateLastStudyTime(widget.courseId);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Color _statusColor(int status, ColorScheme colorScheme) {
    switch (status) {
      case Chapter.statusStudying:
        return colorScheme.secondary;
      case Chapter.statusCompleted:
        return Colors.green;
      default:
        return colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.chapter != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑章节' : '新增章节'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '章节标题',
                  hintText: '请输入章节标题（用于搜索定位）',
                  prefixIcon: Icon(Icons.title),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入章节标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: '章节序号（可选）',
                  hintText: '如：1.1、2.3、第五讲',
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '学习状态',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusSelector(theme, colorScheme),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '学习日期',
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _selectedDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            iconSize: 20,
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                          )
                        : null,
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                        : '请选择日期',
                    style: TextStyle(
                      color: _selectedDate != null ? colorScheme.onSurface : colorScheme.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saveChapter,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  isEditing ? '保存修改' : '添加章节',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSelector(ThemeData theme, ColorScheme colorScheme) {
    final options = [
      {'value': Chapter.statusStudying, 'label': '学习中'},
      {'value': Chapter.statusCompleted, 'label': '已完成'},
    ];

    return Row(
      children: options.map((option) {
        final value = option['value'] as int;
        final label = option['label'] as String;
        final isSelected = _selectedStatus == value;
        final color = _statusColor(value, colorScheme);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option != options.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStatus = value;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      value == Chapter.statusCompleted
                          ? Icons.check_circle
                          : Icons.play_circle,
                      size: 18,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
