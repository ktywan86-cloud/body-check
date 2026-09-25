import 'package:flutter/material.dart';
import '../models/health_record.dart';
import '../services/storage_service.dart';
import '../services/analysis_service.dart';

/// 어플리케이션의 상태(State)를 관리하고 비즈니스 로직을 처리하는 프로바이더입니다.
/// 화면(UI)은 이 프로바이더를 구독하여 데이터 변경 시 자동으로 화면을 갱신합니다.
class HealthProvider extends ChangeNotifier {
  final StorageService _storageService;
  final AnalysisService _analysisService;

  List<HealthRecord> _records = [];
  double? _targetWeight;
  double? _height;
  bool _isDarkMode = false;
  String _aiFeedback = '분석 데이터가 아직 부족합니다.';
  bool _isLoading = false;

  // AI 엔진 및 Ollama 상태값
  String _aiEngine = 'local';
  String _ollamaBaseUrl = 'http://localhost:11434';
  String _ollamaModel = 'llama3';

  // 다중 사용자 상태값
  String? _currentUserId;
  String? _currentUserRole; // 현재 로그인된 사용자 권한 ('admin' or 'user')
  Map<String, Map<String, dynamic>> _userCredentials = {};
  bool _autoLoginEnabled = false;

  HealthProvider({
    required StorageService storageService,
    required AnalysisService analysisService,
  })  : _storageService = storageService,
        _analysisService = analysisService;

  // --- Getters (화면에서 가져다 쓸 데이터 필드들) ---
  List<HealthRecord> get records => _records;
  double? get targetWeight => _targetWeight;
  double? get height => _height;
  bool get isDarkMode => _isDarkMode;
  String get aiFeedback => _aiFeedback;
  bool get isLoading => _isLoading;

  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;
  bool get isLoggedIn => _currentUserId != null;
  bool get isAdmin => _currentUserRole == 'admin';
  List<String> get registeredUsers => _userCredentials.keys.toList();
  String get aiEngine => _aiEngine;
  String get ollamaBaseUrl => _ollamaBaseUrl;
  String get ollamaModel => _ollamaModel;
  bool get autoLoginEnabled => _autoLoginEnabled;

  String getUserRole(String username) =>
      _userCredentials[username]?['role'] as String? ?? 'user';

  /// 비밀번호 복구에 사용할 보안 질문 프리셋입니다.
  static const List<String> securityQuestions = [
    '가장 좋아하는 음식은?',
    '어릴 적 살던 동네 이름은?',
    '처음 키운 반려동물의 이름은?',
    '기억에 남는 여행지는?',
    '초등학교 담임 선생님 성함은?',
  ];

  /// 복구 답변은 앞뒤 공백과 대소문자 차이를 무시하고 비교합니다.
  String _normalizeAnswer(String answer) => answer.trim().toLowerCase();

  /// 해당 사용자에게 설정된 보안 질문을 반환합니다. (미설정 시 null)
  String? getSecurityQuestion(String username) {
    final question = _userCredentials[username]?['securityQuestion'];
    if (question is String && question.trim().isNotEmpty) return question;
    return null;
  }

  /// 해당 사용자가 비밀번호 복구를 사용할 수 있는 상태인지 확인합니다.
  bool hasRecovery(String username) {
    final answer = _userCredentials[username]?['securityAnswer'];
    return getSecurityQuestion(username) != null &&
        answer is String &&
        answer.isNotEmpty;
  }

  /// 복구 질문과 답변을 저장하거나 갱신합니다.
  Future<bool> setRecovery(
      String username, String question, String answer) async {
    final cred = _userCredentials[username];
    if (cred == null) return false;
    if (question.trim().isEmpty || answer.trim().isEmpty) return false;

    cred['securityQuestion'] = question.trim();
    cred['securityAnswer'] = _normalizeAnswer(answer);
    await _storageService.saveUserCredentials(_userCredentials);
    notifyListeners();
    return true;
  }

  /// 입력한 복구 답변이 저장된 답변과 일치하는지 확인합니다.
  bool verifyRecoveryAnswer(String username, String answer) {
    if (!hasRecovery(username)) return false;
    final saved = _userCredentials[username]?['securityAnswer'] as String;
    return saved == _normalizeAnswer(answer);
  }

  /// 보안 질문이 없는 기존 프로필을 이 기기에서 직접 인계받습니다.
  ///
  /// 기기별 localStorage에만 계정이 있는 구조라, 보안 질문이 도입되기 전에
  /// 만들어진 프로필은 비밀번호를 잊으면 되살릴 방법이 없습니다. 이 경로는
  /// 그런 프로필을 옮기기 위한 일회성 통로입니다.
  ///
  /// 재설정과 동시에 보안 질문 등록을 강제하며, 보안 질문이 이미 있는
  /// 프로필에는 동작하지 않습니다. 따라서 한 번 정리되면 경로가 스스로 닫힙니다.
  Future<bool> resetPasswordOnDevice(
    String username,
    String typedUsername,
    String newPassword,
    String question,
    String answer,
  ) async {
    final cred = _userCredentials[username];
    if (cred == null) return false;

    // 보안 질문이 이미 있으면 정상 복구 경로를 쓰도록 막습니다.
    if (hasRecovery(username)) return false;

    // 프로필 이름을 정확히 입력했을 때만 진행합니다.
    if (typedUsername.trim() != username) return false;

    final cleanPassword = newPassword.trim();
    if (cleanPassword.isEmpty) return false;
    if (question.trim().isEmpty || answer.trim().isEmpty) return false;

    cred['password'] = cleanPassword;
    cred['securityQuestion'] = question.trim();
    cred['securityAnswer'] = _normalizeAnswer(answer);
    await _storageService.saveUserCredentials(_userCredentials);
    notifyListeners();
    return true;
  }

  /// 보안 질문 답변이 일치할 때만 비밀번호를 새로 설정합니다.
  Future<bool> resetPasswordWithRecovery(
      String username, String answer, String newPassword) async {
    final cleanPassword = newPassword.trim();
    if (cleanPassword.isEmpty) return false;
    if (!verifyRecoveryAnswer(username, answer)) return false;

    _userCredentials[username]?['password'] = cleanPassword;
    await _storageService.saveUserCredentials(_userCredentials);
    notifyListeners();
    return true;
  }

  /// 가장 최근에 입력한 체중을 반환합니다.
  double? get currentWeight {
    if (_records.isEmpty) return null;
    return _records.first.weight;
  }

  /// 가장 최근에 입력한 체지방률을 반환합니다.
  double? get currentBodyFat {
    if (_records.isEmpty) return null;
    return _records.first.bodyFat;
  }

  /// 가장 최근에 입력한 허리둘레를 반환합니다.
  double? get currentWaist {
    if (_records.isEmpty) return null;
    return _records.first.waist;
  }

  /// 목표 체중까지 남은 무게(kg)를 계산합니다.
  double? get remainingWeight {
    final cur = currentWeight;
    final tar = _targetWeight;
    if (cur == null || tar == null) return null;
    return cur - tar; // 양수이면 더 빼야 함, 음수이면 목표 달성 및 추가 감량됨
  }

  /// 최근 7일 동안 기록된 체중 데이터의 평균을 계산합니다. (최대 최근 7개 기록 대상)
  double? get sevenDayAverage {
    if (_records.isEmpty) return null;

    // 최대 최근 7개의 데이터를 추출합니다.
    final limit = _records.length < 7 ? _records.length : 7;
    double sum = 0;
    for (int i = 0; i < limit; i++) {
      sum += _records[i].weight;
    }
    return sum / limit;
  }

  /// 최근 30일 체중 변화량을 계산합니다.
  /// 가장 최근 기록과 약 30일 전 기록의 차이를 보여줍니다.
  double? get thirtyDayChange {
    if (_records.isEmpty) return null;
    if (_records.length < 2) return 0.0; // 기록이 1개뿐이면 변화량은 0

    final latestRecord = _records.first;

    // 최신 날짜 기준 30일 이전 시점의 기록을 탐색합니다.
    final targetDate = latestRecord.date.subtract(const Duration(days: 30));

    // 30일 전 날짜와 가장 가까운 기록을 찾습니다.
    HealthRecord? baseRecord;
    for (var record in _records) {
      if (record.date.isBefore(targetDate) ||
          record.date.isAtSameMomentAs(targetDate)) {
        baseRecord = record;
        break;
      }
    }

    // 30일 이전 기록이 없다면, 저장된 가장 오래된 기록을 기준으로 삼습니다.
    baseRecord ??= _records.last;

    // (가장 최신 체중) - (기준 체중)
    return latestRecord.weight - baseRecord.weight;
  }

  /// BMI 지수를 계산합니다. 공식: 체중(kg) / (신장(m) * 신장(m))
  double? get bmi {
    final curWeight = currentWeight;
    final curHeight = _height;
    if (curWeight == null || curHeight == null || curHeight <= 0) return null;

    final heightInMeters = curHeight / 100.0;
    return curWeight / (heightInMeters * heightInMeters);
  }

  /// BMI 지수에 따른 상태 문자열을 한글로 반환합니다.
  String get bmiStatus {
    final val = bmi;
    if (val == null) return '키와 몸무게를 입력해주세요.';
    if (val < 18.5) return '저체중';
    if (val < 23) return '정상';
    if (val < 25) return '과체중';
    if (val < 30) return '경도비만';
    return '고도비만';
  }

  /// BMI 상태에 해당하는 색상을 반환합니다. (테마용)
  Color get bmiStatusColor {
    final val = bmi;
    if (val == null) return Colors.grey;
    if (val < 18.5) return Colors.blue; // 저체중
    if (val < 23) return Colors.green; // 정상
    if (val < 25) return Colors.orange; // 과체중
    return Colors.red; // 비만
  }

  // --- 비즈니스 Logic 및 데이터 조작 메서드들 ---

  /// 앱이 시작될 때 로컬 저장소로부터 데이터를 불러와 상태를 초기화합니다.
  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    await _storageService.init();

    // 로드 및 마이그레이션 처리
    final rawCredentials = await _storageService.loadUserCredentials();
    _userCredentials = {};

    bool hasAdmin = false;
    rawCredentials.forEach((username, value) {
      if (value is String) {
        // 기존 단순 패스워드 문자열 마이그레이션 (첫 계정을 Admin으로 승격)
        _userCredentials[username] = {
          'password': value,
          'role': !hasAdmin ? 'admin' : 'user',
        };
        hasAdmin = true;
      } else if (value is Map) {
        _userCredentials[username] = Map<String, dynamic>.from(value);
        if (_userCredentials[username]?['role'] == 'admin') {
          hasAdmin = true;
        }
      }
    });

    // 계정들이 존재하는데 관리자가 지정되지 않은 특수 상황 보정
    if (_userCredentials.isNotEmpty && !hasAdmin) {
      final firstKey = _userCredentials.keys.first;
      _userCredentials[firstKey]?['role'] = 'admin';
    }

    // 마이그레이션이 반영된 자격증명 정보 재저장
    await _storageService.saveUserCredentials(_userCredentials);

    // 앱 시작 시 자동 로그인 체크
    if (_currentUserId == null) {
      _autoLoginEnabled = await _storageService.loadAutoLoginEnabled();
      if (_autoLoginEnabled) {
        final lastUser = await _storageService.loadLastActiveUser();
        // 마지막 로그인 유저가 여전히 존재할 때만 자동 로그인 처리
        if (lastUser != null && _userCredentials.containsKey(lastUser)) {
          _currentUserId = lastUser;
          _currentUserRole =
              _userCredentials[lastUser]?['role'] as String? ?? 'user';
          _storageService.setActiveUser(lastUser);
        }
      }
    }

    if (_currentUserId != null) {
      _records = await _storageService.loadRecords();
      _targetWeight = await _storageService.loadTargetWeight();
      _height = await _storageService.loadHeight();
      _isDarkMode = await _storageService.loadDarkMode();

      // AI 엔진 및 Ollama 설정 로드
      final savedAiEngine = await _storageService.loadAiEngine();
      // 이전 버전의 클라이언트 Gemini 선택값은 로컬 규칙으로 마이그레이션합니다.
      _aiEngine = (savedAiEngine == 'local' || savedAiEngine == 'ollama')
          ? savedAiEngine
          : 'local';
      _ollamaBaseUrl = await _storageService.loadOllamaBaseUrl();
      _ollamaModel = await _storageService.loadOllamaModel();

      // 불러온 데이터를 기반으로 AI 분석 코멘트를 즉시 생성합니다.
      await updateAiFeedback();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 사용자 로그인 처리
  Future<bool> login(String username, String password,
      {bool autoLogin = false}) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return false;

    final cred = _userCredentials[cleanUsername];
    if (cred != null && cred['password'] == password) {
      _currentUserId = cleanUsername;
      _currentUserRole = cred['role'] as String? ?? 'user';
      _storageService.setActiveUser(cleanUsername);

      // 자동 로그인 설정 보존
      _autoLoginEnabled = autoLogin;
      await _storageService.saveAutoLoginEnabled(autoLogin);
      await _storageService.saveLastActiveUser(cleanUsername);

      await loadAllData();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 신규 사용자 등록 (프로필 생성)
  Future<bool> register(String username, String password,
      {String role = 'user',
      String? securityQuestion,
      String? securityAnswer}) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.isEmpty) return false;

    if (_userCredentials.containsKey(cleanUsername)) {
      return false; // 이미 존재하는 유저
    }

    // 첫 가입 유저인 경우 강제로 관리자 권한을 부여합니다.
    final isFirstUser = _userCredentials.isEmpty;
    final assignedRole = isFirstUser ? 'admin' : role;

    _userCredentials[cleanUsername] = {
      'password': password,
      'role': assignedRole,
      if (securityQuestion != null && securityQuestion.trim().isNotEmpty)
        'securityQuestion': securityQuestion.trim(),
      if (securityAnswer != null && securityAnswer.trim().isNotEmpty)
        'securityAnswer': _normalizeAnswer(securityAnswer),
    };
    await _storageService.saveUserCredentials(_userCredentials);
    notifyListeners();
    return true;
  }

  /// 로그아웃 처리
  Future<void> logout() async {
    _currentUserId = null;
    _currentUserRole = null;
    _storageService.setActiveUser(null);

    // 자동 로그인 설정 초기화
    _autoLoginEnabled = false;
    await _storageService.saveAutoLoginEnabled(false);
    await _storageService.saveLastActiveUser(null);

    // 상태 초기화
    _records = [];
    _targetWeight = null;
    _height = null;
    _isDarkMode = false;
    _aiFeedback = '분석 데이터가 아직 부족합니다.';
    _aiEngine = 'local';
    _ollamaBaseUrl = 'http://localhost:11434';
    _ollamaModel = 'llama3';

    notifyListeners();
  }

  /// 관리자 전용: 사용자 계정 강제 삭제 및 관련 데이터 정리
  Future<void> adminDeleteUser(String username) async {
    if (!isAdmin || username == _currentUserId)
      return; // 자신을 삭제하거나 관리자가 아닐 때 리턴
    if (_userCredentials.containsKey(username)) {
      _userCredentials.remove(username);
      await _storageService.saveUserCredentials(_userCredentials);
      await _storageService.wipeUserScopedData(username);
      notifyListeners();
    }
  }

  /// 관리자 전용: 사용자 비밀번호 강제 변경
  Future<void> adminResetUserPassword(
      String username, String newPassword) async {
    if (!isAdmin) return;
    if (_userCredentials.containsKey(username)) {
      _userCredentials[username]?['password'] = newPassword;
      await _storageService.saveUserCredentials(_userCredentials);
      notifyListeners();
    }
  }

  /// 새로운 건강 기록을 등록하거나, 기존 기록을 수정합니다.
  Future<void> saveRecord(HealthRecord record) async {
    await _storageService.saveRecord(record);
    _records = await _storageService.loadRecords(); // 갱신된 리스트 불러오기

    await updateAiFeedback(); // 기록 변화에 따른 AI 분석 피드백 갱신
    notifyListeners();
  }

  /// 기존 건강 기록을 삭제합니다.
  Future<void> deleteRecord(String id) async {
    await _storageService.deleteRecord(id);
    _records = await _storageService.loadRecords();

    await updateAiFeedback();
    notifyListeners();
  }

  /// 사용자의 목표 체중을 업데이트하고 로컬에 저장합니다.
  Future<void> updateTargetWeight(double weight) async {
    _targetWeight = weight;
    await _storageService.saveTargetWeight(weight);

    await updateAiFeedback();
    notifyListeners();
  }

  /// 사용자의 키(신장)를 업데이트하고 로컬에 저장합니다.
  Future<void> updateHeight(double height) async {
    _height = height;
    await _storageService.saveHeight(height);

    await updateAiFeedback();
    notifyListeners();
  }

  /// 테마(다크모드) 설정을 전환하고 상태를 저장합니다.
  Future<void> toggleDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _storageService.saveDarkMode(isDark);
    notifyListeners();
  }

  /// AI 엔진 종류를 업데이트하고 상태를 저장합니다.
  Future<void> updateAiEngine(String engine) async {
    _aiEngine = (engine == 'ollama') ? 'ollama' : 'local';
    await _storageService.saveAiEngine(_aiEngine);
    await updateAiFeedback();
    notifyListeners();
  }

  /// Ollama API Base URL을 업데이트하고 상태를 저장합니다.
  Future<void> updateOllamaBaseUrl(String url) async {
    _ollamaBaseUrl = url;
    await _storageService.saveOllamaBaseUrl(url);
    await updateAiFeedback();
    notifyListeners();
  }

  /// Ollama 모델을 업데이트하고 상태를 저장합니다.
  Future<void> updateOllamaModel(String model) async {
    _ollamaModel = model;
    await _storageService.saveOllamaModel(model);
    await updateAiFeedback();
    notifyListeners();
  }

  /// 로컬 기록들을 기반으로 AI 조언 코멘트를 새로 받아옵니다.
  Future<void> updateAiFeedback() async {
    _aiFeedback = await _analysisService.generateFeedback(
      records: _records,
      height: _height,
      targetWeight: _targetWeight,
      aiEngine: _aiEngine,
      ollamaBaseUrl: _ollamaBaseUrl,
      ollamaModel: _ollamaModel,
    );
  }

  /// 테스트 및 데모를 위한 30일 가상 건강 데이터(점진적 체중 하락 변화 트렌드)를 생성하여 주입합니다.
  Future<void> generateMockData() async {
    _isLoading = true;
    notifyListeners();

    // 1. 기존 가짜 데이터 및 실 데이터 초기화 (클린 테스트를 위해)
    for (var r in _records) {
      await _storageService.deleteRecord(r.id);
    }

    final double startWeight = _targetWeight != null
        ? _targetWeight! + 6.2
        : 78.5; // 목표치보다 6.2kg 높게 설정 시작
    final DateTime now = DateTime.now();

    double currentW = startWeight;

    for (int i = 29; i >= 0; i--) {
      // 29일 전부터 오늘(0일 전)까지 루프
      final date = now.subtract(Duration(days: i));

      // 체중 변화: 매일 점진적으로 하락하되 가끔 정체/반등 양상 부여
      double step;
      if (i % 5 == 0) {
        step = 0.15; // 가벼운 반등
      } else if (i % 3 == 0) {
        step = 0.0; // 정체기
      } else {
        step = -0.35; // 본격 감량
      }
      currentW = currentW + step;
      if (currentW < 35.0) currentW = 35.0;

      // 체지방률: 체중에 비례하여 감량 시뮬레이션
      final double bodyFat = 26.0 - (startWeight - currentW) * 0.45;

      // 허리둘레: 감량 비율에 맞춤
      final double waist = 86.5 - (startWeight - currentW) * 0.35;

      // 수면 시간
      final double sleep = 6.0 + (i % 4) * 0.5;

      // 식단 상태
      String meal = 'normal';
      if (i % 4 == 0) {
        meal = 'good';
      } else if (i % 9 == 0) {
        meal = 'bad';
      }

      // 운동 내용
      String? exercise;
      if (i % 2 == 0) {
        if (i % 6 == 0) {
          exercise = '야외 자전거 라이딩 40분';
        } else if (i % 4 == 0) {
          exercise = '헬스 근력강화 트레이닝 1시간';
        } else {
          exercise = '공원 파워 워킹 30분';
        }
      }

      final record = HealthRecord(
        id: 'mock_id_${date.millisecondsSinceEpoch}',
        date: date,
        weight: double.parse(currentW.toStringAsFixed(1)),
        bodyFat: double.parse(bodyFat.toStringAsFixed(1)),
        waist: double.parse(waist.toStringAsFixed(1)),
        sleepHours: sleep,
        mealStatus: meal,
        exercise: exercise,
        memo: '${30 - i}일째 운동 완수! 식단을 조절하고 활력을 유지하고 있습니다.',
      );

      await _storageService.saveRecord(record);
    }

    // 2. 주입 완료 후 데이터 다시 불러오기 및 피드백 재생성
    _records = await _storageService.loadRecords();
    await updateAiFeedback();

    _isLoading = false;
    notifyListeners();
  }
}
