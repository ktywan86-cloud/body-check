import 'package:body_check/models/health_record.dart';
import 'package:body_check/models/weight_goal.dart';
import 'package:body_check/widgets/health_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HealthRecord _r(DateTime d, double w) => HealthRecord(
    id: d.toIso8601String(), date: d, weight: w, mealStatus: 'normal');

List<HealthRecord> _daily(DateTime start, int days, double from, double step) =>
    List.generate(
        days, (i) => _r(start.add(Duration(days: i)), from - step * i));

Future<void> _pump(WidgetTester tester, HealthChart chart,
    {Brightness brightness = Brightness.light}) {
  return tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, height: 300, child: chart)),
    ),
  ));
}

/// 차트를 그린 뒤 LineChart가 예외 없이 화면에 올라왔는지 확인합니다.
void _expectChart(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(LineChart), findsOneWidget);
}

void main() {
  final start = DateTime(2026, 1, 5);
  final goal = WeightGoal(
    startWeight: 80,
    startDate: start,
    targetWeight: 72,
    periodUnit: GoalPeriodUnit.week,
    periodCount: 12,
  );

  testWidgets('기록이 1개 이하이고 계획이 없으면 안내 문구를 보여준다', (tester) async {
    await _pump(tester, HealthChart(records: [_r(start, 80)]));
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('2개 이상'), findsOneWidget);
  });

  testWidgets('계획 없이 기존처럼 그린다', (tester) async {
    await _pump(
      tester,
      HealthChart(records: _daily(start, 10, 80, 0.2), targetWeight: 75),
    );
    _expectChart(tester);
  });

  testWidgets('최근 범위에서 계획선을 함께 그린다', (tester) async {
    await _pump(
      tester,
      HealthChart(
        records: _daily(start, 20, 80, 0.1),
        targetWeight: 72,
        goal: goal.withOverride(2, 79),
      ),
    );
    _expectChart(tester);
  });

  testWidgets('계획 전체 보기는 기록이 없어도 계획선만 그린다', (tester) async {
    await _pump(
      tester,
      HealthChart(records: const [], goal: goal, range: ChartRange.plan),
    );
    _expectChart(tester);
  });

  testWidgets('계획 전체 보기: 계획 이전 기록과 긴 월 단위 계획', (tester) async {
    final longGoal = WeightGoal(
      startWeight: 95,
      startDate: start,
      targetWeight: 80,
      periodUnit: GoalPeriodUnit.month,
      periodCount: 24,
    );
    await _pump(
      tester,
      HealthChart(
        records: _daily(start.subtract(const Duration(days: 30)), 60, 96, 0.05),
        goal: longGoal,
        range: ChartRange.plan,
      ),
      brightness: Brightness.dark,
    );
    _expectChart(tester);
  });

  testWidgets('같은 날 여러 기록과 기록 1개 + 계획', (tester) async {
    await _pump(
      tester,
      HealthChart(records: [
        _r(DateTime(2026, 1, 6, 7), 80),
        _r(DateTime(2026, 1, 6, 21), 80.4),
        _r(DateTime(2026, 1, 7, 7), 79.8),
      ]),
    );
    _expectChart(tester);

    await _pump(tester, HealthChart(records: [_r(start, 80)], goal: goal));
    _expectChart(tester);
  });

  testWidgets('목표일이 이미 지난 계획도 그린다', (tester) async {
    await _pump(
      tester,
      HealthChart(
        records: _daily(DateTime(2026, 6, 1), 10, 74, 0.1),
        goal: goal, // 3/30 종료
      ),
    );
    _expectChart(tester);
  });

  testWidgets('차트를 눌러도 툴팁이 오류 없이 뜬다', (tester) async {
    await _pump(
      tester,
      HealthChart(
        records: _daily(start, 14, 80, 0.15),
        targetWeight: 72,
        goal: goal,
        range: ChartRange.plan,
      ),
    );
    final chart = find.byType(LineChart);
    final box = tester.getRect(chart);
    // 여러 위치를 눌러 체중/평균/계획선 툴팁 경로를 모두 지나가게 합니다.
    for (final fx in [0.1, 0.3, 0.5, 0.7, 0.95]) {
      final gesture = await tester.startGesture(
          Offset(box.left + box.width * fx, box.top + box.height * 0.5));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
