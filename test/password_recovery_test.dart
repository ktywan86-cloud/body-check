import 'package:body_check/providers/health_provider.dart';
import 'package:body_check/services/analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage_service.dart';

void main() {
  late HealthProvider provider;

  Future<HealthProvider> buildProvider() async {
    final created = HealthProvider(
      storageService: FakeStorageService(),
      analysisService: MockAnalysisService(),
    );
    await created.loadAllData();
    return created;
  }

  setUp(() async {
    provider = await buildProvider();
  });

  group('비밀번호 찾기 (보안 질문)', () {
    test('가입 시 보안 질문을 등록하면 복구를 사용할 수 있다', () async {
      final registered = await provider.register(
        '아빠',
        '1234',
        securityQuestion: HealthProvider.securityQuestions.first,
        securityAnswer: 'Busan',
      );

      expect(registered, isTrue);
      expect(provider.hasRecovery('아빠'), isTrue);
      expect(provider.getSecurityQuestion('아빠'),
          HealthProvider.securityQuestions.first);
    });

    test('답변 비교는 대소문자와 앞뒤 공백을 무시한다', () async {
      await provider.register(
        '아빠',
        '1234',
        securityQuestion: HealthProvider.securityQuestions.first,
        securityAnswer: 'Busan',
      );

      expect(provider.verifyRecoveryAnswer('아빠', '  busan '), isTrue);
      expect(provider.verifyRecoveryAnswer('아빠', 'BUSAN'), isTrue);
      expect(provider.verifyRecoveryAnswer('아빠', 'seoul'), isFalse);
    });

    test('답변이 틀리면 비밀번호가 바뀌지 않는다', () async {
      await provider.register(
        '아빠',
        '1234',
        securityQuestion: HealthProvider.securityQuestions.first,
        securityAnswer: 'Busan',
      );

      final reset =
          await provider.resetPasswordWithRecovery('아빠', '틀린답', '9999');

      expect(reset, isFalse);
      expect(await provider.login('아빠', '1234'), isTrue);
    });

    test('답변이 맞으면 새 비밀번호로 교체되고 기존 비밀번호는 막힌다', () async {
      await provider.register(
        '아빠',
        '1234',
        securityQuestion: HealthProvider.securityQuestions.first,
        securityAnswer: 'Busan',
      );

      final reset =
          await provider.resetPasswordWithRecovery('아빠', 'busan', '9999');

      expect(reset, isTrue);
      expect(await provider.login('아빠', '1234'), isFalse);
      expect(await provider.login('아빠', '9999'), isTrue);
    });

    test('빈 비밀번호로는 재설정할 수 없다', () async {
      await provider.register(
        '아빠',
        '1234',
        securityQuestion: HealthProvider.securityQuestions.first,
        securityAnswer: 'Busan',
      );

      expect(
        await provider.resetPasswordWithRecovery('아빠', 'busan', '   '),
        isFalse,
      );
      expect(await provider.login('아빠', '1234'), isTrue);
    });

    test('보안 질문이 없는 계정은 복구가 차단된다', () async {
      await provider.register('엄마', '1111');

      expect(provider.hasRecovery('엄마'), isFalse);
      expect(provider.getSecurityQuestion('엄마'), isNull);
      expect(
        await provider.resetPasswordWithRecovery('엄마', '아무답변', '2222'),
        isFalse,
      );
    });

    test('기존 계정도 나중에 보안 질문을 등록하면 복구할 수 있고, 저장 후 다시 불러와도 유지된다', () async {
      await provider.register('엄마', '1111');

      final saved = await provider.setRecovery(
        '엄마',
        HealthProvider.securityQuestions[1],
        'Seoul',
      );
      expect(saved, isTrue);

      // 저장소에서 다시 읽어들여 필드가 유실되지 않았는지 확인합니다.
      await provider.loadAllData();

      expect(provider.hasRecovery('엄마'), isTrue);
      expect(provider.getSecurityQuestion('엄마'),
          HealthProvider.securityQuestions[1]);
      expect(
        await provider.resetPasswordWithRecovery('엄마', 'seoul', '3333'),
        isTrue,
      );
      expect(await provider.login('엄마', '3333'), isTrue);
    });

    test('존재하지 않는 사용자에게는 보안 질문을 설정할 수 없다', () async {
      expect(
        await provider.setRecovery(
            '없는사람', HealthProvider.securityQuestions.first, 'Busan'),
        isFalse,
      );
    });
  });

  group('기기에서 직접 재설정 (보안 질문 없는 기존 계정)', () {
    const q = '가장 좋아하는 음식은?';

    test('프로필 이름이 맞으면 재설정되고 보안 질문이 함께 등록된다', () async {
      await provider.register('아빠', '1234');

      final ok =
          await provider.resetPasswordOnDevice('아빠', '아빠', '5678', q, 'Busan');

      expect(ok, isTrue);
      expect(await provider.login('아빠', '5678'), isTrue);
      expect(provider.hasRecovery('아빠'), isTrue);
      expect(provider.getSecurityQuestion('아빠'), q);
    });

    test('프로필 이름이 틀리면 아무것도 바뀌지 않는다', () async {
      await provider.register('아빠', '1234');

      final ok =
          await provider.resetPasswordOnDevice('아빠', '엄마', '5678', q, 'Busan');

      expect(ok, isFalse);
      expect(provider.hasRecovery('아빠'), isFalse);
      expect(await provider.login('아빠', '1234'), isTrue);
    });

    test('이름 앞뒤 공백은 허용된다', () async {
      await provider.register('아빠', '1234');

      expect(
        await provider.resetPasswordOnDevice('아빠', '  아빠 ', '5678', q, 'Busan'),
        isTrue,
      );
    });

    test('보안 질문이 이미 있으면 이 경로는 차단된다', () async {
      await provider.register('아빠', '1234',
          securityQuestion: q, securityAnswer: 'Busan');

      final ok =
          await provider.resetPasswordOnDevice('아빠', '아빠', '5678', q, 'Seoul');

      expect(ok, isFalse);
      expect(await provider.login('아빠', '1234'), isTrue);
    });

    test('한 번 재설정하면 경로가 스스로 닫힌다', () async {
      await provider.register('아빠', '1234');

      expect(
        await provider.resetPasswordOnDevice('아빠', '아빠', '5678', q, 'Busan'),
        isTrue,
      );
      // 두 번째 시도는 보안 질문이 생겼으므로 거부되어야 합니다.
      expect(
        await provider.resetPasswordOnDevice('아빠', '아빠', '9999', q, 'Seoul'),
        isFalse,
      );
      expect(await provider.login('아빠', '5678'), isTrue);
    });

    test('비밀번호나 보안 질문 답변이 비어 있으면 실패한다', () async {
      await provider.register('아빠', '1234');

      expect(
        await provider.resetPasswordOnDevice('아빠', '아빠', '  ', q, 'Busan'),
        isFalse,
      );
      expect(
        await provider.resetPasswordOnDevice('아빠', '아빠', '5678', q, '   '),
        isFalse,
      );
      expect(provider.hasRecovery('아빠'), isFalse);
      expect(await provider.login('아빠', '1234'), isTrue);
    });

    test('없는 프로필에는 동작하지 않는다', () async {
      expect(
        await provider.resetPasswordOnDevice(
            '없는사람', '없는사람', '5678', q, 'Busan'),
        isFalse,
      );
    });
  });
}
