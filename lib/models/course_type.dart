class CourseType {
  int? id;
  String name;
  int sortOrder;
  DateTime createTime;

  CourseType({
    this.id,
    required this.name,
    this.sortOrder = 0,
    required this.createTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'create_time': createTime.toIso8601String(),
    };
  }

  factory CourseType.fromMap(Map<String, dynamic> map) {
    return CourseType(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      createTime: DateTime.parse(map['create_time'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sortOrder': sortOrder,
    'createTime': createTime.toIso8601String(),
  };

  factory CourseType.fromJson(Map<String, dynamic> json) => CourseType(
    id: json['id'] as int?,
    name: json['name'] as String,
    sortOrder: json['sortOrder'] as int? ?? 0,
    createTime: DateTime.parse(json['createTime'] as String),
  );
}
