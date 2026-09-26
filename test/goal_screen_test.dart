import 'package:body_check/models/weight_goal.dart';
import 'package:body_check/providers/health_provider.dart';
import 'package:body_check/screens/goal_screen.dart';
import 'package:body_check/services/analysis_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_storage_service.dart';

Future<HealthProvider> _providerWithGoal() async {
  final provider = HealthProvider(
    storageService: FakeStorageService(),
    analysisService: MockAnalysisService(),
  );
  await provider.loadAllData();
  await provider.register('테스터', '1234');
  await provider.login('테스터', '1234');
  await provider.updateWeightGoal(WeightGoal(
    startWeight: 80,
    startDate: DateTime.now(),
    targetWeight: 72,
    periodUnit: GoalPeriodUnit.week,
    periodCount: 12,
  ));
  return provider;
}

Future<void> _pumpScreen(WidgetTester tester, HealthProvider provider) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ChangeNotifierProvider<HealthProvider>.value(
    value: provider,
    child: const MaterialApp(home: GoalScreen()),
  ));
  await tester.pumpAndSettle();
}

/// 마우스를 올려 툴팁을 띄운 뒤 클릭합니다. (브라우저에서 오류가 났던 조작 순서)
Future<void> _hoverAndTap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(seconds: 2)); // 툴팁 표시 대기
  await mouse.down(tester.getCenter(target));
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.removePointer(); // 같은 테스트에서 다시 호버할 수 있도록 정리
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('기간별 목표를 수정하고 되돌려도 오류가 나지 않는다', (tester) async {
    final provider = await _providerWithGoal();
    await _pumpScreen(tester, provider);

    // 3주차(세 번째 행)의 수정 버튼
    final editButtons = find.byKey(const ValueKey('edit'));
    expect(editButtons, findsNWidgets(11)); // 1~11주차 (목표 지점은 수정 불가)
    await _hoverAndTap(tester, editButtons.at(2));

    expect(find.text('3주차 목표 수정'), findsOneWidget);

    // 범위 밖 값은 거부되고 다이얼로그가 남아 있어야 합니다.
    await tester.enterText(find.byType(TextFormField).last, '85');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(find.text('3주차 목표 수정'), findsOneWidget);

    // 올바른 값을 적용하면 저장되고 되돌리기 버튼이 생깁니다.
    await tester.enterText(find.byType(TextFormField).last, '78.5');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3주차 목표 수정'), findsNothing);
    expect(provider.weightGoal!.overrides, {3: 78.5});
    expect(find.byKey(const ValueKey('undo')), findsOneWidget);
    expect(find.text('수동'), findsOneWidget);

    // 되돌리기
    await _hoverAndTap(tester, find.byKey(const ValueKey('undo')));
    expect(tester.takeException(), isNull);
    expect(provider.weightGoal!.overrides, isEmpty);
    expect(find.byKey(const ValueKey('undo')), findsNothing);
  });

  testWidgets('뒤쪽 수정 값이 있을 때 앞쪽을 수정하면 안내 문구가 나온다', (tester) async {
    final provider = await _providerWithGoal();
    await provider.updateWeightGoal(provider.weightGoal!.withOverride(6, 76));
    await _pumpScreen(tester, provider);

    await _hoverAndTap(tester, find.byKey(const ValueKey('edit')).at(1));
    expect(find.textContaining('이후 직접 수정한 1개 기간'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '79');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(provider.weightGoal!.overrides, {2: 79});
  });

  testWidgets('오늘이 기간 마지막 날이면 다음 기간은 아직 오지 않은 기간으로 표시한다', (tester) async {
    final provider = HealthProvider(
      storageService: FakeStorageService(),
      analysisService: MockAnalysisService(),
    );
    await provider.loadAllData();
    await provider.register('테스터', '1234');
    await provider.login('테스터', '1234');
    // 오늘이 정확히 2주차 종료일이 되도록 14일 전에 시작
    await provider.updateWeightGoal(WeightGoal(
      startWeight: 80,
      startDate: DateTime.now().subtract(const Duration(days: 14)),
      targetWeight: 72,
      periodUnit: GoalPeriodUnit.week,
      periodCount: 12,
    ));
    await _pumpScreen(tester, provider);

    // 기록이 없으므로 지난 기간(1·2주차)만 '기록 없음', 3주차부터는 '-'
    expect(find.text('기록 없음'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장하지 않은 입력이 있으면 뒤로 가기 전에 확인한다', (tester) async {
    final provider = HealthProvider(
      storageService: FakeStorageService(),
      analysisService: MockAnalysisService(),
    );
    await provider.loadAllData();
    await provider.register('테스터', '1234');
    await provider.login('테스터', '1234');

    await tester.pumpWidget(ChangeNotifierProvider<HealthProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const GoalScreen())),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '72');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);

    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
