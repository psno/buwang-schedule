class TimeSlot {
  final int period;
  final String startTime;  // '07:05'
  final String endTime;    // '07:45'
  final String label;      // '早自习', '第1节', etc.
  final bool isSaturday;

  TimeSlot({
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.label,
    this.isSaturday = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'startTime': startTime,
      'endTime': endTime,
      'label': label,
      'isSaturday': isSaturday ? 1 : 0,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      period: map['period'] as int,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      label: map['label'] as String,
      isSaturday: (map['isSaturday'] as int?) == 1,
    );
  }

  TimeSlot copyWith({
    int? period,
    String? startTime,
    String? endTime,
    String? label,
    bool? isSaturday,
  }) {
    return TimeSlot(
      period: period ?? this.period,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      label: label ?? this.label,
      isSaturday: isSaturday ?? this.isSaturday,
    );
  }

  @override
  String toString() {
    return 'TimeSlot(period: $period, startTime: $startTime, endTime: $endTime, label: $label, isSaturday: $isSaturday)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlot &&
        other.period == period &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.label == label &&
        other.isSaturday == isSaturday;
  }

  @override
  int get hashCode {
    return Object.hash(period, startTime, endTime, label, isSaturday);
  }
}

/// Default time slots for database initialization (string-based times)
final List<TimeSlot> defaultModelTimeSlots = [
  TimeSlot(period: 0, startTime: '07:05', endTime: '07:45', label: '早自习'),
  TimeSlot(period: 1, startTime: '08:25', endTime: '09:05', label: '第1节'),
  TimeSlot(period: 2, startTime: '09:15', endTime: '09:55', label: '第2节'),
  TimeSlot(period: 3, startTime: '10:25', endTime: '11:05', label: '第3节'),
  TimeSlot(period: 4, startTime: '11:20', endTime: '12:00', label: '第4节'),
  TimeSlot(period: 5, startTime: '14:00', endTime: '14:40', label: '第5节'),
  TimeSlot(period: 6, startTime: '14:50', endTime: '15:30', label: '第6节'),
  TimeSlot(period: 7, startTime: '15:45', endTime: '16:25', label: '第7节'),
  TimeSlot(period: 8, startTime: '16:35', endTime: '17:15', label: '第8节'),
  TimeSlot(period: 9, startTime: '18:10', endTime: '18:50', label: '第9节'),
  TimeSlot(period: 10, startTime: '19:00', endTime: '19:40', label: '第10节'),
  TimeSlot(period: 11, startTime: '19:50', endTime: '20:30', label: '第11节'),
  TimeSlot(period: 12, startTime: '20:40', endTime: '21:20', label: '第12节'),
];

/// University time slots for database initialization (string-based times)
final List<TimeSlot> universityModelTimeSlots = [
  TimeSlot(period: 0, startTime: '08:00', endTime: '08:45', label: '第1节'),
  TimeSlot(period: 1, startTime: '08:55', endTime: '09:40', label: '第2节'),
  TimeSlot(period: 2, startTime: '10:00', endTime: '10:45', label: '第3节'),
  TimeSlot(period: 3, startTime: '10:55', endTime: '11:40', label: '第4节'),
  TimeSlot(period: 4, startTime: '14:00', endTime: '14:45', label: '第5节'),
  TimeSlot(period: 5, startTime: '14:55', endTime: '15:40', label: '第6节'),
  TimeSlot(period: 6, startTime: '16:00', endTime: '16:45', label: '第7节'),
  TimeSlot(period: 7, startTime: '16:55', endTime: '17:40', label: '第8节'),
  TimeSlot(period: 8, startTime: '19:00', endTime: '19:45', label: '第9节'),
  TimeSlot(period: 9, startTime: '19:55', endTime: '20:40', label: '第10节'),
];
