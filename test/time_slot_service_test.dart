import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buwang_schedule/models/app_mode.dart';
import 'package:buwang_schedule/services/time_slot_service.dart';
import 'package:buwang_schedule/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TimeSlotService.instance.load();
  });

  group('TimeSlotService', () {
    test('applyCustom persists, changes getSlots and bumps version', () async {
      final svc = TimeSlotService.instance;
      final before = svc.getSlots(SchoolType.highSchool).length;
      final v0 = TimeSlotService.timeSlotVersion.value;

      final edited = svc.getSlots(SchoolType.highSchool).toList();
      edited[0] = TimeSlot(
        period: edited[0].period,
        startTime: const TimeOfDay(hour: 6, minute: 30),
        endTime: const TimeOfDay(hour: 7, minute: 15),
        label: edited[0].label,
      );
      await svc.applyCustom(SchoolType.highSchool, edited);

      expect(svc.hasCustom(SchoolType.highSchool), isTrue);
      expect(svc.getSlots(SchoolType.highSchool).first.startTime.hour, 6);
      expect(svc.getSlots(SchoolType.highSchool).length, before);
      expect(TimeSlotService.timeSlotVersion.value, greaterThan(v0));
      // 重新 load 后仍然生效（已落盘）
      SharedPreferences.setMockInitialValues(<String, Object>{
        TimeSlotService.keyHighSchool: svc.exportRaw()['highSchool'] as String,
      });
      await svc.load();
      expect(svc.getSlots(SchoolType.highSchool).first.startTime.hour, 6);
    });

    test('resetToDefault removes override', () async {
      final svc = TimeSlotService.instance;
      await svc.applyCustom(
          SchoolType.university, svc.getSlots(SchoolType.university).toList());
      expect(svc.hasCustom(SchoolType.university), isTrue);
      await svc.resetToDefault(SchoolType.university);
      expect(svc.hasCustom(SchoolType.university), isFalse);
      expect(svc.getSlots(SchoolType.university).first.period, 0);
    });

    test('importRaw restores from backup payload', () async {
      final svc = TimeSlotService.instance;
      const raw = '0|6:0|6:45|早读;1|8:0|8:45|第1节';
      await svc.importRaw(<String, dynamic>{'highSchool': raw});
      expect(svc.getSlots(SchoolType.highSchool).first.startTime.hour, 6);
      expect(svc.getSlots(SchoolType.highSchool).length, 2);
    });
  });

  group('getTimeSlot out-of-range', () {
    test('clamps to last real slot instead of period 0', () {
      // 高中默认 0-12，越界 99 应落到第13节而非早自习
      final slot = getTimeSlot(99, schoolType: SchoolType.highSchool);
      expect(slot.period, greaterThan(0));
      expect(slot.period, defaultTimeSlots.last.period);
      // 大学模式 period 10/11/12 现在有真实时段
      final u = getTimeSlot(12, schoolType: SchoolType.university);
      expect(u.period, 12);
    });
  });
}
