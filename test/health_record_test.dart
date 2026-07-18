import 'package:body_check/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthRecord', () {
    test('JSON round-trip preserves health data', () {
      final record = HealthRecord(
        id: 'record-1',
        date: DateTime.utc(2026, 7, 18),
        weight: 72.4,
        bodyFat: 18.2,
        waist: 82.0,
        exercise: '걷기 40분',
        sleepHours: 7.5,
        mealStatus: 'good',
        memo: '컨디션 양호',
        photoBase64: 'data:image/jpeg;base64,ZmFrZQ==',
      );

      final restored = HealthRecord.fromJson(record.toJson());

      expect(restored.id, record.id);
      expect(restored.date, record.date);
      expect(restored.weight, record.weight);
      expect(restored.bodyFat, record.bodyFat);
      expect(restored.waist, record.waist);
      expect(restored.exercise, record.exercise);
      expect(restored.sleepHours, record.sleepHours);
      expect(restored.mealStatus, record.mealStatus);
      expect(restored.memo, record.memo);
      expect(restored.photoBase64, record.photoBase64);
    });

    test('copyWith can explicitly remove a photo', () {
      final record = HealthRecord(
        id: 'record-2',
        date: DateTime.utc(2026, 7, 18),
        weight: 72.4,
        mealStatus: 'normal',
        photoBase64: 'data:image/jpeg;base64,ZmFrZQ==',
      );

      expect(record.copyWith(clearPhoto: true).photoBase64, isNull);
    });
  });
}
