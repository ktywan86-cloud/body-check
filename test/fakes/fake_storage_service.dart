import 'dart:convert';

import 'package:body_check/models/health_record.dart';
import 'package:body_check/models/weight_goal.dart';
import 'package:body_check/services/storage_service.dart';

/// 테스트용 인메모리 저장소입니다.
///
/// 실제 구현과 같이 JSON 직렬화를 거치도록 해서, 저장/로드 과정에서 필드가
/// 유실되지 않는지까지 함께 검증합니다. 목표 체중과 목표 계획은 실제 구현처럼
/// 활성 사용자별로 분리해 저장합니다.
class FakeStorageService implements StorageService {
  Map<String, dynamic> _credentials = {};
  final List<HealthRecord> _records = [];
  final Map<String?, double> _targetWeights = {};
  final Map<String?, String> _weightGoals = {};
  String? _activeUser;
  String? _lastActiveUser;
  bool _autoLogin = false;

  @override
  Future<void> init() async {}

  @override
  Future<List<HealthRecord>> loadRecords() async {
    final list = List.of(_records);
    list.sort((a, b) => b.date.compareTo(a.date)); // 실제 구현과 같은 최신순
    return list;
  }

  @override
  Future<void> saveRecord(HealthRecord record) async {
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
  }

  @override
  Future<void> deleteRecord(String id) async =>
      _records.removeWhere((r) => r.id == id);

  @override
  Future<double?> loadTargetWeight() async => _targetWeights[_activeUser];

  @override
  Future<void> saveTargetWeight(double weight) async =>
      _targetWeights[_activeUser] = weight;

  @override
  Future<WeightGoal?> loadWeightGoal() async {
    final raw = _weightGoals[_activeUser];
    return raw == null ? null : WeightGoal.fromJson(raw);
  }

  @override
  Future<void> saveWeightGoal(WeightGoal? goal) async {
    if (goal == null) {
      _weightGoals.remove(_activeUser);
    } else {
      _weightGoals[_activeUser] = goal.toJson();
    }
  }

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
  Future<void> wipeUserScopedData(String username) async {
    _targetWeights.remove(username);
    _weightGoals.remove(username);
  }
}
