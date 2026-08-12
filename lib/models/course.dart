class Course {
  int? id;
  String courseName;
  String? desc;
  int? typeId;
  String? typeName;
  int? expectedChapters;
  DateTime createTime;
  DateTime? lastStudyTime;
  int sortOrder;

  Course({
    this.id,
    required this.courseName,
    this.desc,
    this.typeId,
    this.typeName,
    this.expectedChapters,
    required this.createTime,
    this.lastStudyTime,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_name': courseName,
      'desc': desc,
      'type_id': typeId,
      'expected_chapters': expectedChapters,
      'create_time': createTime.toIso8601String(),
      'last_study_time': lastStudyTime?.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int?,
      courseName: map['course_name'] as String,
      desc: map['desc'] as String?,
      typeId: map['type_id'] as int?,
      typeName: map['type_name'] as String?,
      expectedChapters: map['expected_chapters'] as int?,
      createTime: DateTime.parse(map['create_time'] as String),
      lastStudyTime: map['last_study_time'] != null
          ? DateTime.parse(map['last_study_time'] as String)
          : null,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'desc': desc,
    'typeId': typeId,
    'typeName': typeName,
    'expectedChapters': expectedChapters,
    'createTime': createTime.toIso8601String(),
    'lastStudyTime': lastStudyTime?.toIso8601String(),
    'sortOrder': sortOrder,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as int?,
    courseName: json['courseName'] as String,
    desc: json['desc'] as String?,
    typeId: json['typeId'] as int?,
    typeName: json['typeName'] as String?,
    expectedChapters: json['expectedChapters'] as int?,
    createTime: DateTime.parse(json['createTime'] as String),
    lastStudyTime: json['lastStudyTime'] != null
        ? DateTime.parse(json['lastStudyTime'] as String)
        : null,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}
