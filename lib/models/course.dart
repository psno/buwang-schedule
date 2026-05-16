class Course {
  final int? id;
  final String name;       // 班级名 e.g. '高一1班'
  final String? subject;   // 科目 e.g. '数学'
  final int dayOfWeek;     // 1-6 (Mon-Sat)
  final int period;        // 0-12
  final String? location;  // 地点
  final String? teacher;   // 教师
  final int color;         // color index
  final int round;         // 周六轮次 (0=非周六, 1/2/3...=轮次)

  Course({
    this.id,
    required this.name,
    this.subject,
    required this.dayOfWeek,
    required this.period,
    this.location,
    this.teacher,
    this.color = 0,
    this.round = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'subject': subject,
      'dayOfWeek': dayOfWeek,
      'period': period,
      'location': location,
      'teacher': teacher,
      'color': color,
      'round': round,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int?,
      name: map['name'] as String,
      subject: map['subject'] as String?,
      dayOfWeek: map['dayOfWeek'] as int,
      period: map['period'] as int,
      location: map['location'] as String?,
      teacher: map['teacher'] as String?,
      color: map['color'] as int? ?? 0,
      round: map['round'] as int? ?? 0,
    );
  }

  Course copyWith({
    int? id,
    String? name,
    String? subject,
    int? dayOfWeek,
    int? period,
    String? location,
    String? teacher,
    int? color,
    int? round,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      period: period ?? this.period,
      location: location ?? this.location,
      teacher: teacher ?? this.teacher,
      color: color ?? this.color,
      round: round ?? this.round,
    );
  }

  @override
  String toString() {
    return 'Course(id: $id, name: $name, subject: $subject, dayOfWeek: $dayOfWeek, period: $period, round: $round, location: $location, teacher: $teacher, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course &&
        other.id == id &&
        other.name == name &&
        other.subject == subject &&
        other.dayOfWeek == dayOfWeek &&
        other.period == period &&
        other.round == round &&
        other.location == location &&
        other.teacher == teacher &&
        other.color == color;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, subject, dayOfWeek, period, round, location, teacher, color);
  }
}
