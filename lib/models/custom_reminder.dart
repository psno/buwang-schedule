enum RepeatType { daily, weekdays, weekly, once }

enum ReminderMethod { alarm, calendar }

class CustomReminder {
  final int? id;
  final String name;
  final int hour;
  final int minute;
  final RepeatType repeatType;
  final List<int> repeatDays; // 1=Mon..7=Sun, for weekly
  final ReminderMethod method;
  final bool enabled;
  final String? note;

  CustomReminder({
    this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.repeatType = RepeatType.daily,
    this.repeatDays = const [],
    this.method = ReminderMethod.alarm,
    this.enabled = true,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'hour': hour,
      'minute': minute,
      'repeatType': repeatType.index,
      'repeatDays': repeatDays.join(','),
      'method': method.index,
      'enabled': enabled ? 1 : 0,
      'note': note,
    };
  }

  factory CustomReminder.fromMap(Map<String, dynamic> map) {
    return CustomReminder(
      id: map['id'] as int?,
      name: map['name'] as String,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      repeatType: RepeatType.values[map['repeatType'] as int? ?? 0],
      repeatDays: (map['repeatDays'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toList(),
      method: ReminderMethod.values[map['method'] as int? ?? 0],
      enabled: (map['enabled'] as int?) == 1,
      note: map['note'] as String?,
    );
  }

  CustomReminder copyWith({
    int? id,
    String? name,
    int? hour,
    int? minute,
    RepeatType? repeatType,
    List<int>? repeatDays,
    ReminderMethod? method,
    bool? enabled,
    String? note,
  }) {
    return CustomReminder(
      id: id ?? this.id,
      name: name ?? this.name,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      method: method ?? this.method,
      enabled: enabled ?? this.enabled,
      note: note ?? this.note,
    );
  }

  @override
  String toString() {
    return 'CustomReminder(id: $id, name: $name, hour: $hour, minute: $minute, repeatType: $repeatType, repeatDays: $repeatDays, method: $method, enabled: $enabled, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomReminder &&
        other.id == id &&
        other.name == name &&
        other.hour == hour &&
        other.minute == minute &&
        other.repeatType == repeatType &&
        _listEquals(other.repeatDays, repeatDays) &&
        other.method == method &&
        other.enabled == enabled &&
        other.note == note;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, hour, minute, repeatType, Object.hashAll(repeatDays), method, enabled, note);
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
