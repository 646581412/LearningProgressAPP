import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/course_type.dart';
import '../providers/app_provider.dart';

class CourseEditPage extends StatefulWidget {
  final Course? course;
  final int? typeId;

  const CourseEditPage({
    super.key,
    this.course,
    this.typeId,
  });

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameController = TextEditingController();
  final _descController = TextEditingController();
  final _expectedChaptersController = TextEditingController();
  int? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      _courseNameController.text = widget.course!.courseName;
      _descController.text = widget.course!.desc ?? '';
      _selectedTypeId = widget.course!.typeId;
      if (widget.course!.expectedChapters != null &&
          widget.course!.expectedChapters! > 0) {
        _expectedChaptersController.text =
            widget.course!.expectedChapters.toString();
      }
    } else if (widget.typeId != null) {
      _selectedTypeId = widget.typeId;
    }
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _descController.dispose();
    _expectedChaptersController.dispose();
    super.dispose();
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _courseNameController.text.trim();
    final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();
    final expectedText = _expectedChaptersController.text.trim();
    int? expectedChapters;
    if (expectedText.isNotEmpty) {
      expectedChapters = int.tryParse(expectedText);
      if (expectedChapters != null && expectedChapters <= 0) {
        expectedChapters = null;
      }
    }

    if (widget.course == null) {
      final newCourse = Course(
        courseName: name,
        desc: desc,
        typeId: _selectedTypeId,
        expectedChapters: expectedChapters,
        createTime: DateTime.now(),
      );
      await DatabaseHelper.instance.insertCourse(newCourse);
    } else {
      final updatedCourse = Course(
        id: widget.course!.id,
        courseName: name,
        desc: desc,
        typeId: _selectedTypeId,
        expectedChapters: expectedChapters,
        createTime: widget.course!.createTime,
        lastStudyTime: widget.course!.lastStudyTime,
      );
      await DatabaseHelper.instance.updateCourse(updatedCourse);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.course != null;
    final provider = context.watch<AppProvider>();
    final List<CourseType> courseTypes = provider.courseTypes;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑课程' : '新增课程'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _courseNameController,
                decoration: const InputDecoration(
                  labelText: '课程名称',
                  hintText: '请输入课程名称',
                  prefixIcon: Icon(Icons.book),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入课程名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '课程简介（可选）',
                  hintText: '请输入课程简介',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expectedChaptersController,
                decoration: const InputDecoration(
                  labelText: '总课程数（可选）',
                  hintText: '如：24，留空则以实际进度为准',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  helperText: '用于概览显示课程进度，不填则默认已完成+学习中为总数',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final n = int.tryParse(value.trim());
                  if (n == null || n <= 0) {
                    return '请输入正整数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                '课程类型',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildTypeSelector(courseTypes, theme, colorScheme),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saveCourse,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  isEditing ? '保存修改' : '创建课程',
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

  Widget _buildTypeSelector(
    List<CourseType> courseTypes,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (courseTypes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.outline),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '暂无课程类型，可在设置中添加',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...courseTypes.map((type) {
          final isSelected = _selectedTypeId == type.id;
          return _TypeChip(
            label: type.name,
            isSelected: isSelected,
            color: colorScheme.primary,
            onTap: () {
              setState(() {
                _selectedTypeId = isSelected ? null : type.id;
              });
            },
          );
        }),
        // 未分类选项
        _TypeChip(
          label: '未分类',
          isSelected: _selectedTypeId == null,
          color: colorScheme.outline,
          onTap: () {
            setState(() {
              _selectedTypeId = null;
            });
          },
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
