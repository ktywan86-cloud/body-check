import 'package:body_check/models/health_record.dart';
import 'package:body_check/models/weight_goal.dart';
import 'package:flutter_test/flutter_test.dart';

HealthRecord _record(DateTime date, double weight) => HealthRecord(
      id: date.toIso8601String(),
      date: date,
      weight: weight,
      mealStatus: 'normal',
    );

/// 80kg → 68kg, 12주 계획 (주당 1kg 균등)
WeightGoal _weekly({Map<int, double>? overrides}) => WeightGoal(
      startWeight: 80,
      startDate: DateTime(2026, 1, 5),
      targetWeight: 68,
      periodUnit: GoalPeriodUnit.week,
      periodCount: 12,
      overrides: overrides,
    );

void main() {
  group('기간별 목표 날짜', () {
    test('주 단위는 7일 간격이고 마지막은 목표일이다', () {
      final goal = _weekly();
      final ms = goal.milestones();

      expect(ms.length, 13); // 시작 + 12주
      expect(ms.first.date, DateTime(2026, 1, 5));
      expect(ms[1].date, DateTime(2026, 1, 12));
      expect(ms.last.date, goal.targetDate);
      expect(goal.targetDate, DateTime(2026, 3, 30));
      expect(goal.totalDays, 84);
    });

    test('월 단위는 말일에 맞추고 날짜가 누적해서 밀리지 않는다', () {
      final goal = WeightGoal(
        startWeight: 80,
        startDate: DateTime(2027, 1, 31),
        targetWeight: 70,
        periodUnit: GoalPeriodUnit.month,
        periodCount: 3,
      );

      expect(goal.milestoneDate(1), DateTime(2027, 2, 28)); // 평년
      expect(goal.milestoneDate(2), DateTime(2027, 3, 31)); // 3/28로 밀리지 않음
      expect(goal.milestoneDate(3), DateTime(2027, 4, 30));
    });

    test('윤년 2월 말일도 맞춘다', () {
      expect(
        WeightGoal.addUnits(DateTime(2028, 1, 31), GoalPeriodUnit.month, 1),
        DateTime(2028, 2, 29),
      );
    });

    test('연도를 넘어가는 월 계산', () {
      expect(
        WeightGoal.addUnits(DateTime(2026, 11, 15), GoalPeriodUnit.month, 3),
        DateTime(2027, 2, 15),
      );
    });

    test('시작일의 시각 성분은 버린다', () {
      final goal = WeightGoal(
        startWeight: 80,
        startDate: DateTime(2026, 1, 5, 23, 59),
        targetWeight: 70,
        periodUnit: GoalPeriodUnit.week,
        periodCount: 1,
      );
      expect(goal.startDate, DateTime(2026, 1, 5));
    });
  });

  group('자동 균등 분배', () {
    test('수정 없이는 시작부터 목표까지 균등하게 나뉜다', () {
      final goal = _weekly();
      expect(goal.plannedWeightFor(0), 80);
      expect(goal.plannedWeightFor(1), closeTo(79, 1e-9));
      expect(goal.plannedWeightFor(6), closeTo(74, 1e-9));
      expect(goal.plannedWeightFor(12), 68);
      expect(goal.averageLossPerPeriod, closeTo(1, 1e-9));
    });
  });

  group('직접 수정과 이후 재분배', () {
    test('수정한 기간 이전은 그대로고, 이후는 남은 감량을 균등하게 나눈다', () {
      // 3주차 계획(77kg)을 적응기로 완만하게 77.8kg으로 수정
      final goal = _weekly().withOverride(3, 77.8);

      // 이전 기간 불변
      expect(goal.plannedWeightFor(1), closeTo(79, 1e-9));
      expect(goal.plannedWeightFor(2), closeTo(78, 1e-9));
      // 수정한 기간
      expect(goal.plannedWeightFor(3), 77.8);
      // 이후: 77.8 → 68 을 9주에 균등 분배
      final step = (77.8 - 68) / 9;
      expect(goal.plannedWeightFor(4), closeTo(77.8 - step, 1e-9));
      expect(goal.plannedWeightFor(11), closeTo(68 + step, 1e-9));
      expect(goal.plannedWeightFor(12), 68);
    });

    test('앞쪽 기간을 수정하면 뒤쪽의 직접 수정 값은 지워진다', () {
      final goal = _weekly().withOverride(3, 77).withOverride(6, 74);
      expect(goal.overrides.keys, [3, 6]);
      expect(goal.overridesAfter(3), 1);

      final edited = goal.withOverride(2, 78.5);
      expect(edited.overrides, {2: 78.5});
    });

    test('뒤쪽 기간을 수정하면 앞쪽 값은 유지된다', () {
      final goal = _weekly().withOverride(3, 77).withOverride(6, 74);
      expect(goal.overrides, {3: 77, 6: 74});
    });

    test('허용 범위는 목표 이상, 직전 기간 이하다', () {
      final goal = _weekly().withOverride(3, 77);
      final range = goal.overrideRange(4)!;
      expect(range.min, 68);
      expect(range.max, 77);
    });

    test('직전 기간과 같은 값(정체기)은 허용된다', () {
      final goal = _weekly();
      expect(() => goal.withOverride(1, 80), returnsNormally);
    });

    test('범위를 벗어난 값은 거부된다', () {
      final goal = _weekly();
      expect(() => goal.withOverride(3, 80.5), throwsArgumentError); // 직전보다 무거움
      expect(() => goal.withOverride(3, 67), throwsArgumentError); // 목표보다 가벼움
    });

    test('시작과 목표 지점은 수정할 수 없다', () {
      final goal = _weekly();
      expect(goal.overrideRange(0), isNull);
      expect(goal.overrideRange(12), isNull);
      expect(() => goal.withOverride(0, 79), throwsArgumentError);
      expect(() => goal.withOverride(12, 69), throwsArgumentError);
    });

    test('되돌리면 그 기간과 이후 직접 수정 값이 지워진다', () {
      final goal =
          _weekly().withOverride(2, 78).withOverride(5, 75).withOverride(8, 72);

      final reverted = goal.withoutOverride(5);
      expect(reverted.overrides, {2: 78});
    });

    test('어떤 순서로 수정해도 계획선은 거꾸로 올라가지 않는다', () {
      var goal = _weekly();
      final edits = <List<num>>[
        [3, 79.5],
        [7, 71],
        [5, 79.5],
        [10, 70],
        [1, 80],
        [11, 68],
      ];
      for (final e in edits) {
        final k = e[0].toInt();
        final range = goal.overrideRange(k)!;
        final w = e[1].toDouble().clamp(range.min, range.max).toDouble();
        goal = goal.withOverride(k, w);

        final ms = goal.milestones();
        for (var i = 1; i < ms.length; i++) {
          expect(ms[i].plannedWeight,
              lessThanOrEqualTo(ms[i - 1].plannedWeight + 1e-9),
              reason: '$i번째가 이전보다 무거움 (수정 $e 후)');
        }
        expect(ms.last.plannedWeight, 68);
      }
    });
  });

  group('날짜별 계획 체중', () {
    test('기간 사이는 날짜 비율로 보간한다', () {
      final goal = _weekly();
      // 1주차(1/12, 79kg)와 2주차(1/19, 78kg)의 중간쯤
      expect(goal.plannedWeightAt(DateTime(2026, 1, 12)), closeTo(79, 1e-9));
      expect(goal.plannedWeightAt(DateTime(2026, 1, 15, 18)),
          closeTo(79 - 3 / 7, 1e-9));
    });

    test('시작 이전은 시작 체중, 목표일 이후는 목표 체중이다', () {
      final goal = _weekly();
      expect(goal.plannedWeightAt(DateTime(2025, 12, 1)), 80);
      expect(goal.plannedWeightAt(DateTime(2026, 6, 1)), 68);
    });
  });

  group('입력 검증', () {
    String? check(double? s, double? t, int? n,
            [GoalPeriodUnit u = GoalPeriodUnit.week]) =>
        WeightGoal.validateBase(
            startWeight: s, targetWeight: t, unit: u, periodCount: n);

    test('정상 입력은 통과한다', () {
      expect(check(80, 72, 12), isNull);
      expect(check(80, 79.9, 1), isNull);
    });

    test('목표가 시작보다 무겁거나 같으면 거부한다 (감량만)', () {
      expect(check(80, 80, 12), isNotNull);
      expect(check(80, 85, 12), isNotNull);
      expect(check(80, 79.95, 12), isNotNull);
    });

    test('기간과 체중 범위를 검사한다', () {
      expect(check(80, 72, 0), isNotNull);
      expect(check(80, 72, null), isNotNull);
      expect(check(80, 72, 105), isNotNull);
      expect(check(80, 72, 104), isNull);
      expect(check(80, 72, 25, GoalPeriodUnit.month), isNotNull);
      expect(check(80, 72, 24, GoalPeriodUnit.month), isNull);
      expect(check(350, 72, 12), isNotNull);
      expect(check(80, 10, 12), isNotNull);
      expect(check(null, 72, 12), isNotNull);
    });
  });

  group('감량 속도 경고', () {
    test('주당 1kg 균등은 80kg 기준(0.8kg)으로 경고된다', () {
      final goal = _weekly();
      expect(goal.safeKgPerWeek, closeTo(0.8, 1e-9));
      expect(goal.aggressiveSegments().length, 12);
    });

    test('완만한 계획은 경고가 없다', () {
      final goal = WeightGoal(
        startWeight: 80,
        startDate: DateTime(2026, 1, 5),
        targetWeight: 74,
        periodUnit: GoalPeriodUnit.week,
        periodCount: 12,
      );
      expect(goal.aggressiveSegments(), isEmpty);
    });

    test('무거운 체중은 1kg 상한이 적용된다', () {
      final goal = WeightGoal(
        startWeight: 150,
        startDate: DateTime(2026, 1, 5),
        targetWeight: 140,
        periodUnit: GoalPeriodUnit.week,
        periodCount: 10,
      );
      expect(goal.safeKgPerWeek, 1.0);
      expect(goal.aggressiveSegments(), isEmpty); // 딱 주 1kg
    });

    test('직접 수정으로 급격해진 구간만 경고된다', () {
      final goal = WeightGoal(
        startWeight: 80,
        startDate: DateTime(2026, 1, 5),
        targetWeight: 74,
        periodUnit: GoalPeriodUnit.week,
        periodCount: 12,
      ).withOverride(1, 78); // 첫 주 -2kg
      expect(goal.aggressiveSegments(), [1]);
    });

    test('월 단위도 주당 속도로 환산한다', () {
      final goal = WeightGoal(
        startWeight: 80,
        startDate: DateTime(2026, 1, 1),
        targetWeight: 72,
        periodUnit: GoalPeriodUnit.month,
        periodCount: 2,
      ); // 월 4kg ≈ 주 0.9kg > 0.8kg
      expect(goal.aggressiveSegments(), [1, 2]);
    });
  });

  group('진행 상태 판정', () {
    final goal = _weekly(); // 1/5 시작, 주 1kg

    test('계획 시작 이후 기록이 없으면 기록 필요', () {
      final p = goal.evaluate(
          [_record(DateTime(2026, 1, 1), 80.5)], DateTime(2026, 1, 20));
      expect(p.status, GoalStatus.noData);
    });

    test('계획과 0.5kg 이내면 순조', () {
      // 1/19 계획 78kg
      final p = goal.evaluate(
          [_record(DateTime(2026, 1, 19), 78.3)], DateTime(2026, 1, 19));
      expect(p.status, GoalStatus.onTrack);
      expect(p.plannedAtLatest, closeTo(78, 1e-9));
      expect(p.diffFromPlan, closeTo(0.3, 1e-9));
    });

    test('계획보다 0.5kg 이상 가벼우면 앞서감, 무거우면 뒤처짐', () {
      expect(
        goal.evaluate([_record(DateTime(2026, 1, 19), 77.4)],
            DateTime(2026, 1, 19)).status,
        GoalStatus.ahead,
      );
      expect(
        goal.evaluate([_record(DateTime(2026, 1, 19), 78.6)],
            DateTime(2026, 1, 19)).status,
        GoalStatus.behind,
      );
    });

    test('오래된 최신 기록은 그 기록 날짜의 계획과 비교한다', () {
      // 1/12 기록(계획 79kg)이 최신이고 오늘은 1/26(계획 76kg)
      final p = goal.evaluate(
          [_record(DateTime(2026, 1, 12), 79.1)], DateTime(2026, 1, 26));
      expect(p.status, GoalStatus.onTrack);
      expect(p.plannedAtLatest, closeTo(79, 1e-9));
    });

    test('목표 체중 이하면 기간과 관계없이 달성', () {
      final p = goal.evaluate(
          [_record(DateTime(2026, 2, 1), 67.9)], DateTime(2026, 2, 1));
      expect(p.status, GoalStatus.achieved);
      expect(p.progressRatio, 1.0);
    });

    test('목표일이 지났는데 미달이면 기간 종료', () {
      final p = goal
          .evaluate([_record(DateTime(2026, 3, 30), 70)], DateTime(2026, 4, 2));
      expect(p.status, GoalStatus.ended);
    });

    test('진행률은 0~1로 제한된다', () {
      final p = goal
          .evaluate([_record(DateTime(2026, 1, 6), 81)], DateTime(2026, 1, 6));
      expect(p.progressRatio, 0.0);

      final half = goal.evaluate(
          [_record(DateTime(2026, 2, 16), 74)], DateTime(2026, 2, 16));
      expect(half.progressRatio, closeTo(0.5, 1e-9));
    });

    test('기록 정렬 순서에 의존하지 않는다', () {
      final records = [
        _record(DateTime(2026, 1, 10), 79.5),
        _record(DateTime(2026, 1, 19), 78.0),
        _record(DateTime(2026, 1, 15), 78.8),
      ];
      final p = goal.evaluate(records, DateTime(2026, 1, 19));
      expect(p.latestWeight, 78.0);
    });

    test('오늘이 속한 기간 순번', () {
      expect(goal.currentMilestoneIndex(DateTime(2026, 1, 5)), 1);
      expect(goal.currentMilestoneIndex(DateTime(2026, 1, 12)), 1);
      expect(goal.currentMilestoneIndex(DateTime(2026, 1, 13)), 2);
      expect(goal.currentMilestoneIndex(DateTime(2026, 9, 1)), 12);
    });
  });

  group('기간별 실제 기록', () {
    final goal = _weekly();

    test('기간 안의 가장 최근 기록을 고른다', () {
      final records = [
        _record(DateTime(2026, 1, 13), 79.2),
        _record(DateTime(2026, 1, 18), 78.4),
        _record(DateTime(2026, 1, 20), 78.0),
      ];
      // 2주차 구간: (1/12, 1/19]
      expect(goal.actualFor(2, records)?.weight, 78.4);
    });

    test('첫 기간은 시작일 당일 기록도 포함한다', () {
      final records = [_record(DateTime(2026, 1, 5, 8), 80)];
      expect(goal.actualFor(1, records)?.weight, 80);
    });

    test('기록이 없으면 null', () {
      expect(goal.actualFor(5, [_record(DateTime(2026, 1, 13), 79)]), isNull);
    });
  });

  group('저장 형식', () {
    test('JSON 왕복 시 직접 수정 값(정수 순번)까지 보존된다', () {
      final goal = _weekly().withOverride(3, 77.5).withOverride(6, 74);
      final restored = WeightGoal.fromJson(goal.toJson());

      expect(restored.startWeight, 80);
      expect(restored.startDate, DateTime(2026, 1, 5));
      expect(restored.targetWeight, 68);
      expect(restored.periodUnit, GoalPeriodUnit.week);
      expect(restored.periodCount, 12);
      expect(restored.overrides, {3: 77.5, 6: 74});
    });

    test('월 단위도 보존된다', () {
      final goal = WeightGoal(
        startWeight: 90,
        startDate: DateTime(2026, 3, 1),
        targetWeight: 80,
        periodUnit: GoalPeriodUnit.month,
        periodCount: 6,
      );
      expect(
          WeightGoal.fromJson(goal.toJson()).periodUnit, GoalPeriodUnit.month);
    });

    test('잘못된 순번과 규칙 위반 값은 버린다', () {
      final map = _weekly().toMap();
      map['overrides'] = {
        'abc': 70, // 숫자 아님
        '0': 79, // 시작 지점
        '12': 69, // 목표 지점
        '20': 70, // 범위 밖
        '3': 77, // 정상
        '5': 79, // 3주차(77)보다 무거움 → 위반
      };
      expect(WeightGoal.fromMap(map).overrides, {3: 77});
    });

    test('필수 값이 없으면 FormatException', () {
      expect(
          () => WeightGoal.fromMap({'startWeight': 80}), throwsFormatException);
    });

    test('알 수 없는 단위는 주 단위로 처리한다', () {
      final map = _weekly().toMap()..['periodUnit'] = 'year';
      expect(WeightGoal.fromMap(map).periodUnit, GoalPeriodUnit.week);
    });
  });
}
