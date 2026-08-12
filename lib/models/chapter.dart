class Chapter {
  int? id;
  int courseId;
  String title;
  String? number;
  int status;
  DateTime? studyDate;
  String? remark;
  int sortOrder;
  DateTime createTime;

  // status: 1 = 学习中, 2 = 已完成
  static const int statusStudying = 1;
  static const int statusCompleted = 2;

  Chapter({
    this.id,
    required this.courseId,
    required this.title,
    this.number,
    this.status = statusStudying,
    this.studyDate,
    this.remark,
    this.sortOrder = 0,
    required this.createTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'number': number,
      'status': status,
      'study_date': studyDate?.toIso8601String(),
      'remark': remark,
      'sort_order': sortOrder,
      'create_time': createTime.toIso8601String(),
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as int?,
      courseId: map['course_id'] as int,
      title: map['title'] as String,
      number: map['number'] as String?,
      status: map['status'] as int? ?? 1,
      studyDate: map['study_date'] != null
          ? DateTime.parse(map['study_date'] as String)
          : null,
      remark: map['remark'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createTime: DateTime.parse(map['create_time'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'title': title,
    'number': number,
    'status': status,
    'studyDate': studyDate?.toIso8601String(),
    'remark': remark,
    'sortOrder': sortOrder,
    'createTime': createTime.toIso8601String(),
  };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json['id'] as int?,
    courseId: json['courseId'] as int,
    title: json['title'] as String,
    number: json['number'] as String?,
    status: json['status'] as int? ?? 1,
    studyDate: json['studyDate'] != null
        ? DateTime.parse(json['studyDate'] as String)
        : null,
    remark: json['remark'] as String?,
    sortOrder: json['sortOrder'] as int? ?? 0,
    createTime: DateTime.parse(json['createTime'] as String),
  );
}
