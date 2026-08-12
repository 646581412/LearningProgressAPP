import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/course.dart';
import '../models/chapter.dart';
import '../models/course_type.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'study_progress.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE course_type (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER DEFAULT 0,
        create_time TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE course (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_name TEXT NOT NULL,
        desc TEXT,
        type_id INTEGER,
        expected_chapters INTEGER,
        create_time TEXT NOT NULL,
        last_study_time TEXT,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (type_id) REFERENCES course_type (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chapter (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        number TEXT,
        status INTEGER DEFAULT 1,
        study_date TEXT,
        remark TEXT,
        sort_order INTEGER DEFAULT 0,
        create_time TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES course (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_chapter_course_id ON chapter(course_id)');
    await db.execute('CREATE INDEX idx_chapter_title ON chapter(title)');
    await db.execute('CREATE INDEX idx_course_type_id ON course(type_id)');

    // 插入默认课程类型
    DateTime now = DateTime.now();
    await db.insert('course_type', {
      'name': '网课',
      'sort_order': 0,
      'create_time': now.toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 创建 course_type 表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS course_type (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER DEFAULT 0,
          create_time TEXT NOT NULL
        )
      ''');

      // 迁移旧的 type 文本数据到 course_type 表
      DateTime now = DateTime.now();
      List<Map<String, dynamic>> oldTypes = await db.rawQuery(
        'SELECT DISTINCT type FROM course WHERE type IS NOT NULL AND type != ""',
      );
      int order = 0;
      Map<String, int> typeNameToId = {};
      for (var row in oldTypes) {
        String typeName = row['type'] as String;
        int id = await db.insert('course_type', {
          'name': typeName,
          'sort_order': order++,
          'create_time': now.toIso8601String(),
        });
        typeNameToId[typeName] = id;
      }

      // 如果没有旧类型，插入默认类型
      if (typeNameToId.isEmpty) {
        List<String> defaultTypes = ['网课', '考证', '系列课'];
        for (int i = 0; i < defaultTypes.length; i++) {
          int id = await db.insert('course_type', {
            'name': defaultTypes[i],
            'sort_order': i,
            'create_time': now.toIso8601String(),
          });
          typeNameToId[defaultTypes[i]] = id;
        }
      }

      // 添加 type_id 列到 course 表
      await db.execute('ALTER TABLE course ADD COLUMN type_id INTEGER');

      // 更新课程的 type_id
      for (var entry in typeNameToId.entries) {
        await db.update(
          'course',
          {'type_id': entry.value},
          where: 'type = ?',
          whereArgs: [entry.key],
        );
      }

      // 创建索引
      await db.execute('CREATE INDEX IF NOT EXISTS idx_course_type_id ON course(type_id)');

      // 将 status=0 的章节更新为 status=1 (移除"待学习"状态)
      await db.update('chapter', {'status': 1}, where: 'status = 0');
    }

    if (oldVersion < 3) {
      // 添加 expected_chapters 列到 course 表
      await db.execute('ALTER TABLE course ADD COLUMN expected_chapters INTEGER');
      // 添加 sort_order 列到 chapter 表
      await db.execute('ALTER TABLE chapter ADD COLUMN sort_order INTEGER DEFAULT 0');
      // 为现有章节设置初始 sort_order（按 id 排序）
      List<Map<String, dynamic>> courses = await db.query('course', columns: ['id']);
      for (var c in courses) {
        int courseId = c['id'] as int;
        List<Map<String, dynamic>> chapters = await db.query(
          'chapter',
          columns: ['id'],
          where: 'course_id = ?',
          whereArgs: [courseId],
          orderBy: 'id ASC',
        );
        for (int i = 0; i < chapters.length; i++) {
          await db.update(
            'chapter',
            {'sort_order': i},
            where: 'id = ?',
            whereArgs: [chapters[i]['id']],
          );
        }
      }
    }
    if (oldVersion < 4) {
      // 添加 sort_order 列到 course 表
      await db.execute('ALTER TABLE course ADD COLUMN sort_order INTEGER DEFAULT 0');
      // 为现有课程设置初始 sort_order（按 id 排序）
      List<Map<String, dynamic>> courses = await db.query('course', columns: ['id'], orderBy: 'id ASC');
      for (int i = 0; i < courses.length; i++) {
        await db.update(
          'course',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [courses[i]['id']],
        );
      }
    }
  }

  Future<int> insertCourseType(CourseType type) async {
    Database db = await instance.database;
    return await db.insert('course_type', type.toMap());
  }

  Future<int> updateCourseType(CourseType type) async {
    Database db = await instance.database;
    return await db.update(
      'course_type',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<int> deleteCourseType(int id) async {
    Database db = await instance.database;
    // 将该类型下的课程的 type_id 设为 null
    await db.update(
      'course',
      {'type_id': null},
      where: 'type_id = ?',
      whereArgs: [id],
    );
    return await db.delete('course_type', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCourseCountByType(int typeId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM course WHERE type_id = ?',
      [typeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<CourseType>> getAllCourseTypes() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      'course_type',
      orderBy: 'sort_order ASC, id ASC',
    );
    return List.generate(maps.length, (i) => CourseType.fromMap(maps[i]));
  }

  Future<void> reorderCourseTypes(List<CourseType> types) async {
    Database db = await instance.database;
    for (int i = 0; i < types.length; i++) {
      await db.update(
        'course_type',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [types[i].id],
      );
    }
  }

  // ==================== Course CRUD ====================

  Future<int> insertCourse(Course course) async {
    Database db = await instance.database;
    if (course.id == null) {
      List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM course WHERE type_id IS ?',
        [course.typeId],
      );
      course.sortOrder = Sqflite.firstIntValue(result) ?? 0;
    }
    return await db.insert('course', course.toMap());
  }

  Future<int> updateCourse(Course course) async {
    Database db = await instance.database;
    return await db.update(
      'course',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
  }

  Future<int> deleteCourse(int id) async {
    Database db = await instance.database;
    await db.delete('chapter', where: 'course_id = ?', whereArgs: [id]);
    return await db.delete('course', where: 'id = ?', whereArgs: [id]);
  }

  Future<Course?> getCourseById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, ct.name as type_name
      FROM course c
      LEFT JOIN course_type ct ON c.type_id = ct.id
      WHERE c.id = ?
    ''', [id]);
    if (maps.isNotEmpty) {
      return Course.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Course>> getAllCourses() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, ct.name as type_name
      FROM course c
      LEFT JOIN course_type ct ON c.type_id = ct.id
      ORDER BY c.last_study_time DESC, c.create_time DESC
    ''');
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }

  Future<List<Course>> getCoursesByTypeId(int? typeId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps;
    if (typeId == null) {
      maps = await db.rawQuery('''
        SELECT c.*, NULL as type_name
        FROM course c
        WHERE c.type_id IS NULL
        ORDER BY c.sort_order ASC, c.create_time DESC
      ''');
    } else {
      maps = await db.rawQuery('''
        SELECT c.*, ct.name as type_name
        FROM course c
        LEFT JOIN course_type ct ON c.type_id = ct.id
        WHERE c.type_id = ?
        ORDER BY c.sort_order ASC, c.create_time DESC
      ''', [typeId]);
    }
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }

  Future<Course?> getLastStudiedCourse() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, ct.name as type_name
      FROM course c
      LEFT JOIN course_type ct ON c.type_id = ct.id
      WHERE c.last_study_time IS NOT NULL
      ORDER BY c.last_study_time DESC
      LIMIT 1
    ''');
    if (maps.isNotEmpty) {
      return Course.fromMap(maps.first);
    }
    return null;
  }

  // ==================== Chapter CRUD ====================

  Future<int> insertChapter(Chapter chapter) async {
    Database db = await instance.database;
    // 对于新增章节（id为null），自动设置 sortOrder 为当前课程章节数
    if (chapter.id == null) {
      List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM chapter WHERE course_id = ?',
        [chapter.courseId],
      );
      int count = Sqflite.firstIntValue(result) ?? 0;
      chapter.sortOrder = count;
    }
    return await db.insert('chapter', chapter.toMap());
  }

  Future<int> updateChapter(Chapter chapter) async {
    Database db = await instance.database;
    return await db.update(
      'chapter',
      chapter.toMap(),
      where: 'id = ?',
      whereArgs: [chapter.id],
    );
  }

  Future<int> deleteChapter(int id) async {
    Database db = await instance.database;
    return await db.delete('chapter', where: 'id = ?', whereArgs: [id]);
  }

  Future<Chapter?> getChapterById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      'chapter',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Chapter.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Chapter>> getChaptersByCourseId(int courseId, {String? orderBy}) async {
    Database db = await instance.database;
    String order = orderBy ?? 'sort_order ASC, id ASC';
    List<Map<String, dynamic>> maps = await db.query(
      'chapter',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: order,
    );
    return List.generate(maps.length, (i) => Chapter.fromMap(maps[i]));
  }

  /// 按章节序号(number)排序
  Future<List<Chapter>> getChaptersOrderedByNumber(int courseId) async {
    return getChaptersByCourseId(courseId, orderBy: "number ASC, id ASC");
  }

  /// 按添加时间排序
  Future<List<Chapter>> getChaptersOrderedByCreateTime(int courseId) async {
    return getChaptersByCourseId(courseId, orderBy: "create_time ASC, id ASC");
  }

  /// 手动重新排序后保存
  Future<void> reorderChapters(int courseId, List<Chapter> chapters) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < chapters.length; i++) {
        await txn.update(
          'chapter',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [chapters[i].id],
        );
      }
    });
  }

  Future<Chapter?> getLastStudyChapter(int courseId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      'chapter',
      where: 'course_id = ? AND status IN (1, 2)',
      whereArgs: [courseId],
      orderBy: 'study_date DESC, id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Chapter.fromMap(maps.first);
    }
    maps = await db.query(
      'chapter',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Chapter.fromMap(maps.first);
    }
    return null;
  }

  Future<Map<String, int>> getCourseProgress(int courseId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter WHERE course_id = ?',
      [courseId],
    );
    List<Map<String, dynamic>> completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter WHERE course_id = ? AND status = 2',
      [courseId],
    );
    List<Map<String, dynamic>> studyingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter WHERE course_id = ? AND status = 1',
      [courseId],
    );
    List<Map<String, dynamic>> expectedResult = await db.rawQuery(
      'SELECT expected_chapters FROM course WHERE id = ?',
      [courseId],
    );
    int actualTotal = Sqflite.firstIntValue(totalResult) ?? 0;
    int completed = Sqflite.firstIntValue(completedResult) ?? 0;
    int studying = Sqflite.firstIntValue(studyingResult) ?? 0;
    int? expectedChapters = expectedResult.isNotEmpty
        ? expectedResult.first['expected_chapters'] as int?
        : null;
    // 总章节数：如果设置了预期章节数就用预期值，否则用实际章节数（已完成+学习中作为堆叠总数）
    int displayTotal;
    if (expectedChapters != null && expectedChapters > 0) {
      displayTotal = expectedChapters;
    } else {
      displayTotal = completed + studying;
      if (displayTotal < actualTotal) displayTotal = actualTotal;
    }
    return {
      'total': actualTotal,
      'display_total': displayTotal,
      'completed': completed,
      'studying': studying,
      'expected': expectedChapters ?? 0,
    };
  }

  // ==================== Search ====================

  Future<List<Map<String, dynamic>>> globalSearch(String keyword) async {
    Database db = await instance.database;
    String likeKeyword = '%$keyword%';

    List<Map<String, dynamic>> courseResults = await db.rawQuery('''
      SELECT 
        c.id as course_id,
        c.course_name,
        c.desc as course_desc,
        ct.name as type_name,
        NULL as chapter_id,
        NULL as chapter_title,
        NULL as chapter_number,
        NULL as chapter_status,
        NULL as chapter_remark,
        'course' as result_type
      FROM course c
      LEFT JOIN course_type ct ON c.type_id = ct.id
      WHERE c.course_name LIKE ? OR c.desc LIKE ?
    ''', [likeKeyword, likeKeyword]);

    List<Map<String, dynamic>> chapterResults = await db.rawQuery('''
      SELECT 
        c.id as course_id,
        c.course_name,
        c.desc as course_desc,
        ct.name as type_name,
        ch.id as chapter_id,
        ch.title as chapter_title,
        ch.number as chapter_number,
        ch.status as chapter_status,
        ch.remark as chapter_remark,
        'chapter' as result_type
      FROM chapter ch
      JOIN course c ON ch.course_id = c.id
      LEFT JOIN course_type ct ON c.type_id = ct.id
      WHERE ch.title LIKE ? OR ch.remark LIKE ?
    ''', [likeKeyword, likeKeyword]);

    return [...courseResults, ...chapterResults];
  }

  // ==================== Statistics ====================

  Future<Map<String, int>> getOverallStatistics() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> courseCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM course',
    );
    List<Map<String, dynamic>> chapterTotal = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter',
    );
    List<Map<String, dynamic>> chapterCompleted = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter WHERE status = 2',
    );
    List<Map<String, dynamic>> chapterStudying = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter WHERE status = 1',
    );
    return {
      'courses': Sqflite.firstIntValue(courseCount) ?? 0,
      'chapters': Sqflite.firstIntValue(chapterTotal) ?? 0,
      'completed': Sqflite.firstIntValue(chapterCompleted) ?? 0,
      'studying': Sqflite.firstIntValue(chapterStudying) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getWeeklyStudyStats() async {
    Database db = await instance.database;
    DateTime now = DateTime.now();
    DateTime sevenDaysAgo = now.subtract(const Duration(days: 6));
    String startDate = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day).toIso8601String();

    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT study_date as date, COUNT(*) as count
      FROM chapter
      WHERE study_date IS NOT NULL AND study_date >= ?
      GROUP BY study_date
      ORDER BY study_date ASC
    ''', [startDate]);

    // 填充7天的数据
    List<Map<String, dynamic>> weeklyData = [];
    for (int i = 0; i < 7; i++) {
      DateTime date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      String dateStr = date.toIso8601String();
      int count = 0;
      for (var row in result) {
        if (row['date'] != null && (row['date'] as String).startsWith(dateStr.substring(0, 10))) {
          count = (row['count'] as int?) ?? 0;
          break;
        }
      }
      weeklyData.add({
        'date': dateStr.substring(0, 10),
        'weekday': ['一', '二', '三', '四', '五', '六', '日'][(date.weekday - 1) % 7],
        'count': count,
      });
    }
    return weeklyData;
  }

  Future<List<Map<String, dynamic>>> getMonthlyStudyStats() async {
    Database db = await instance.database;
    DateTime now = DateTime.now();
    DateTime thirtyDaysAgo = now.subtract(const Duration(days: 29));
    String startDate = DateTime(thirtyDaysAgo.year, thirtyDaysAgo.month, thirtyDaysAgo.day).toIso8601String();

    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT study_date as date, COUNT(*) as count
      FROM chapter
      WHERE study_date IS NOT NULL AND study_date >= ?
      GROUP BY study_date
      ORDER BY study_date ASC
    ''', [startDate]);

    // 填充30天的数据，分成4周显示
    List<Map<String, dynamic>> monthlyData = [];
    for (int week = 0; week < 4; week++) {
      int weekStart = week * 7;
      int weekEnd = weekStart + 7;
      if (weekEnd > 30) weekEnd = 30;
      
      int weekCount = 0;
      for (int i = weekStart; i < weekEnd; i++) {
        DateTime date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - i));
        String dateStr = date.toIso8601String();
        for (var row in result) {
          if (row['date'] != null && (row['date'] as String).startsWith(dateStr.substring(0, 10))) {
            weekCount += (row['count'] as int?) ?? 0;
            break;
          }
        }
      }
      monthlyData.add({
        'weekday': '第${week + 1}周',
        'count': weekCount,
      });
    }
    return monthlyData;
  }

  Future<int> getStudyStreak() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT DATE(study_date) as date
      FROM chapter
      WHERE study_date IS NOT NULL
      ORDER BY date DESC
    ''');

    if (result.isEmpty) return 0;

    int streak = 0;
    DateTime today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    for (var row in result) {
      String? dateStr = row['date'] as String?;
      if (dateStr == null) continue;
      DateTime studyDate = DateTime.parse(dateStr);
      DateTime studyDateOnly = DateTime(studyDate.year, studyDate.month, studyDate.day);

      if (studyDateOnly == checkDate || studyDateOnly == checkDate.subtract(const Duration(days: 1))) {
        streak++;
        checkDate = studyDateOnly.subtract(const Duration(days: 1));
      } else if (studyDateOnly.isBefore(checkDate)) {
        break;
      }
    }
    return streak;
  }

  Future<List<Map<String, dynamic>>> getRecentStudyRecords({int limit = 5}) async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        ch.id as chapter_id,
        ch.title as chapter_title,
        ch.number as chapter_number,
        ch.status as chapter_status,
        ch.study_date as study_date,
        ch.remark as remark,
        c.id as course_id,
        c.course_name as course_name,
        ct.name as type_name
      FROM chapter ch
      JOIN course c ON ch.course_id = c.id
      LEFT JOIN course_type ct ON c.type_id = ct.id
      WHERE ch.study_date IS NOT NULL
      ORDER BY ch.study_date DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<void> updateLastStudyTime(int courseId) async {
    Database db = await instance.database;
    await db.update(
      'course',
      {'last_study_time': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [courseId],
    );
  }

  // ==================== Batch Operations ====================

  Future<void> batchInsertData(List<Course> courses, List<Chapter> chapters, List<CourseType> types) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      // 插入课程类型
      Map<String, int> typeNameToId = {};
      for (var type in types) {
        int id = await txn.insert('course_type', type.toMap()..remove('id'));
        typeNameToId[type.name] = id;
      }

      // 插入课程
      Map<int, int> courseIdMap = {};
      for (var course in courses) {
        // 尝试通过 typeName 匹配 typeId
        if (course.typeName != null && typeNameToId.containsKey(course.typeName)) {
          course.typeId = typeNameToId[course.typeName];
        }
        int newId = await txn.insert('course', course.toMap()..remove('id'));
        if (course.id != null) {
          courseIdMap[course.id!] = newId;
        }
      }

      // 插入章节
      for (var chapter in chapters) {
        if (chapter.courseId != 0 && courseIdMap.containsKey(chapter.courseId)) {
          chapter.courseId = courseIdMap[chapter.courseId]!;
        }
        await txn.insert('chapter', chapter.toMap()..remove('id'));
      }
    });
  }

  Future<void> clearAllData() async {
    Database db = await instance.database;
    await db.delete('chapter');
    await db.delete('course');
    await db.delete('course_type');
  }

  Future<void> updateCourseSortOrders(List<int> courseIds) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < courseIds.length; i++) {
        await txn.update(
          'course',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [courseIds[i]],
        );
      }
    });
  }
}
