import 'dart:convert';

import 'package:body_check/models/health_record.dart';
import 'package:body_check/providers/health_provider.dart';
import 'package:body_check/services/analysis_service.dart';
import 'package:body_check/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트용 인메모리 저장소입니다.
/// 실제 구현과 동일하게 JSON 직렬화를 거치도록 해서, 저장/로드 과정에서
/// 보안 질문 필드가 유실되지 않는지까지 함께 검증합니다.
class FakeStorageService implements StorageService {
  Map<String, dynamic> _credentials = {};
  final List<HealthRecord> _records = [];
  String? _activeUser;
  String? _lastActiveUser;
  bool _autoLogin = false;

  @override
  Future<void> init() async {}

  @override
  Future<List<HealthRecord>> loadRecords() async => List.of(_records);

  @override
  Future<void> saveRecord(HealthRecord record) async => _records.add(record);

  @override
  Future<void> deleteRecord(String id) async =>
      _records.removeWhere((r) => r.id == id);

  @override
  Future<double?> loadTargetWeight() async => null;

  @override
  Future<void> saveTargetWeight(double weight) async {}

  @override
  Future<double?> loadHeight() async => null;

  @override
  Future<void> saveHeight(double height) async {}

  @override
  Future<bool> loadDarkMode() async => false;

  @override
  Future<void> saveDarkMode(bool isDark) async {}

  @override
  Future<String> loadAiEngine() async => 'local';

  @override
  Future<void> saveAiEngine(String engine) async {}

  @override
  Future<String> loadOllamaBaseUrl() async => 'http://localhost:11434';

  @override
  Future<void> saveOllamaBaseUrl(String url) async {}

  @override
  Future<String> loadOllamaModel() async => 'llama3';

  @override
  Future<void> saveOllamaModel(String model) async {}

  @override
  void setActiveUser(String? userId) => _activeUser = userId;

  @override
  String? get activeUser => _activeUser;

  @override
  Future<Map<String, dynamic>> loadUserCredentials() async =>
      json.decode(json.encode(_credentials)) as Map<String, dynamic>;

  @override
  Future<void> saveUserCredentials(Map<String, dynamic> credentials) async {
    _credentials =
        json.decode(json.encode(credentials)) as Map<String, dynamic>;
  }

  @override
  Future<String?> loadLastActiveUser() async => _lastActiveUser;

  @override
  Future<void> saveLastActiveUser(String? userId) async =>
      _lastActiveUser = userId;

  @override
  Future<bool> loadAutoLoginEnabled() async => _autoLogin;

  @override
  Future<void> saveAutoLoginEnabled(bool enabled) async => _autoLogin = enabled;

  @override
  Future<void> wipeUserScopedData(String username) async {}
}

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

    test('기존 계정도 나중에 보안 질문을 등록하면 복구할 수 있고, 저장 후 다시 불러와도 유지된다',
        () async {
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
}
