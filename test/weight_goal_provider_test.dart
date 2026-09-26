import 'package:body_check/models/health_record.dart';
import 'package:body_check/models/weight_goal.dart';
import 'package:body_check/providers/health_provider.dart';
import 'package:body_check/services/analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage_service.dart';

WeightGoal _goal({double target = 72, int count = 12}) => WeightGoal(
      startWeight: 80,
      startDate: DateTime.now(),
      targetWeight: target,
      periodUnit: GoalPeriodUnit.week,
      periodCount: count,
    );

HealthProvider _provider(FakeStorageService storage) => HealthProvider(
      storageService: storage,
      analysisService: MockAnalysisService(),
    );

/// 저장소를 공유하는 provider를 만들고 사용자로 로그인합니다.
Future<HealthProvider> _loggedIn(FakeStorageService storage,
    [String user = '아빠']) async {
  final p = _provider(storage);
  await p.loadAllData();
  if (!p.registeredUsers.contains(user)) {
    await p.register(user, '1234');
  }
  expect(await p.login(user, '1234'), isTrue);
  return p;
}

void main() {
  group('목표 계획 저장', () {
    test('계획을 저장하면 목표 체중도 계획 값으로 맞춰진다', () async {
      final p = await _loggedIn(FakeStorageService());
      await p.updateTargetWeight(75);

      final error = await p.updateWeightGoal(_goal(target: 72));

      expect(error, isNull);
      expect(p.weightGoal?.targetWeight, 72);
      expect(p.targetWeight, 72);
    });

    test('다시 로그인해도 계획이 복원된다', () async {
      final storage = FakeStorageService();
      final first = await _loggedIn(storage);
      await first.updateWeightGoal(_goal().withOverride(3, 77));

      final second = await _loggedIn(storage);

      expect(second.weightGoal, isNotNull);
      expect(second.weightGoal!.overrides, {3: 77});
      expect(second.targetWeight, 72);
    });

    test('잘못된 계획은 저장되지 않고 오류 문구를 돌려준다', () async {
      final p = await _loggedIn(FakeStorageService());

      final error = await p.updateWeightGoal(WeightGoal(
        startWeight: 80,
        startDate: DateTime.now(),
        targetWeight: 85, // 증량
        periodUnit: GoalPeriodUnit.week,
        periodCount: 12,
      ));

      expect(error, isNotNull);
      expect(p.weightGoal, isNull);
    });

    test('계획을 삭제해도 목표 체중은 남는다', () async {
      final p = await _loggedIn(FakeStorageService());
      await p.updateWeightGoal(_goal(target: 72));

      await p.clearWeightGoal();

      expect(p.weightGoal, isNull);
      expect(p.targetWeight, 72);
    });

    test('저장된 목표 체중이 계획과 어긋나 있으면 로드 시 계획 값으로 보정한다', () async {
      final storage = FakeStorageService();
      final p = await _loggedIn(storage);
      await p.updateWeightGoal(_goal(target: 72));
      await storage.saveTargetWeight(90); // 외부 요인으로 어긋난 상황

      await p.loadAllData();

      expect(p.targetWeight, 72);
      expect(await storage.loadTargetWeight(), 72);
    });

    test('로그아웃하면 계획이 메모리에서 비워진다', () async {
      final p = await _loggedIn(FakeStorageService());
      await p.updateWeightGoal(_goal());

      await p.logout();

      expect(p.weightGoal, isNull);
      expect(p.goalProgress, isNull);
    });

    test('계획은 사용자별로 분리된다', () async {
      final storage = FakeStorageService();
      final dad = await _loggedIn(storage, '아빠');
      await dad.updateWeightGoal(_goal(target: 72));
      await dad.logout();

      final mom = await _loggedIn(storage, '엄마');
      expect(mom.weightGoal, isNull);

      await mom.logout();
      final dadAgain = await _loggedIn(storage, '아빠');
      expect(dadAgain.weightGoal?.targetWeight, 72);
    });
  });

  group('진행 상태', () {
    test('계획이 없으면 null', () async {
      final p = await _loggedIn(FakeStorageService());
      expect(p.goalProgress, isNull);
    });

    test('오늘 기록을 남기면 계획과 비교된다', () async {
      final p = await _loggedIn(FakeStorageService());
      await p.updateWeightGoal(_goal());

      await p.saveRecord(HealthRecord(
        id: 'today',
        date: DateTime.now(),
        weight: 80,
        mealStatus: 'normal',
      ));

      final progress = p.goalProgress!;
      expect(progress.status, GoalStatus.onTrack);
      expect(progress.currentMilestoneIndex, 1);
    });
  });
}
