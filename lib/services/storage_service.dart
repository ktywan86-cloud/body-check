import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_record.dart';

/// 데이터 저장 관련 기능을 인터페이스로 정의(추상화)합니다.
abstract class StorageService {
  Future<void> init();
  Future<List<HealthRecord>> loadRecords();
  Future<void> saveRecord(HealthRecord record);
  Future<void> deleteRecord(String id);
  Future<double?> loadTargetWeight();
  Future<void> saveTargetWeight(double weight);
  Future<double?> loadHeight();
  Future<void> saveHeight(double height);
  Future<bool> loadDarkMode();
  Future<void> saveDarkMode(bool isDark);

  // AI 엔진 및 Ollama 관련 메서드
  Future<String> loadAiEngine();
  Future<void> saveAiEngine(String engine);
  Future<String> loadOllamaBaseUrl();
  Future<void> saveOllamaBaseUrl(String url);
  Future<String> loadOllamaModel();
  Future<void> saveOllamaModel(String model);

  // 다중 사용자 세션 및 자격증명 관련 메서드
  void setActiveUser(String? userId);
  String? get activeUser;
  Future<Map<String, dynamic>> loadUserCredentials();
  Future<void> saveUserCredentials(Map<String, dynamic> credentials);
  Future<String?> loadLastActiveUser();
  Future<void> saveLastActiveUser(String? userId);
  Future<bool> loadAutoLoginEnabled();
  Future<void> saveAutoLoginEnabled(bool enabled);
  Future<void> wipeUserScopedData(String username);
}

/// shared_preferences 패키지를 사용하여 디바이스 로컬 저장소에 데이터를 저장하는 구현체입니다.
/// 모든 건강 데이터와 설정을 브라우저 로컬 저장소에 보관합니다.
class LocalStorageService implements StorageService {
  SharedPreferences? _prefs;
  String? _activeUserId;

  // SharedPreferences 초기화 오류나 작동 불능을 대비한 인메모리 대체 저장소
  final Map<String, HealthRecord> _memoryRecords = {};
  double? _memoryTargetWeight;
  double? _memoryHeight;
  bool _memoryDarkMode = false;
  bool _useFallback = false;

  // AI 엔진 및 Ollama 설정 인메모리 백업
  String? _memoryAiEngine;
  String? _memoryOllamaBaseUrl;
  String? _memoryOllamaModel;

  // 자동 로그인 인메모리 백업
  String? _memoryLastActiveUser;
  bool _memoryAutoLoginEnabled = false;

  static const String _keyRecords = 'health_records_key';
  static const String _keyTargetWeight = 'target_weight_key';
  static const String _keyHeight = 'user_height_key';
  static const String _keyDarkMode = 'dark_mode_key';

  static const String _keyAiEngine = 'ai_engine_type_key';
  static const String _keyOllamaBaseUrl = 'ollama_base_url_key';
  static const String _keyOllamaModel = 'ollama_model_key';

  static const String _keyUserCredentials = 'user_credentials_map_key';
  static const String _keyLastActiveUser = 'last_active_user_id_key';
  static const String _keyAutoLoginEnabled = 'auto_login_enabled_key';

  @override
  void setActiveUser(String? userId) {
    _activeUserId = userId;
    // 사용자별 로드 데이터를 보장하기 위해 기존 인메모리 캐시를 초기화합니다.
    _memoryRecords.clear();
    _memoryTargetWeight = null;
    _memoryHeight = null;
    _memoryDarkMode = false;
    _memoryAiEngine = null;
    _memoryOllamaBaseUrl = null;
    _memoryOllamaModel = null;
  }

  @override
  String? get activeUser => _activeUserId;

  /// 유저별 데이터 격리를 위한 키 변조 도우미
  String _scopedKey(String baseKey) {
    if (_activeUserId == null || _activeUserId!.isEmpty) {
      return baseKey;
    }
    return '${_activeUserId}_$baseKey';
  }

  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _useFallback = false;
      // 이전 버전에서 저장된 Gemini 키를 클라이언트 저장소에서 제거합니다.
      final legacyGeminiKeys = _prefs!
          .getKeys()
          .where((key) =>
              key == 'gemini_api_key_key' ||
              key.endsWith('_gemini_api_key_key'))
          .toList();
      for (final key in legacyGeminiKeys) {
        await _prefs!.remove(key);
      }
    } catch (e) {
      _useFallback = true;
      print(
          'Warning: SharedPreferences failed to initialize, using In-Memory Fallback. Error: $e');
    }
  }

  // 로컬 기록만 읽어오기
  Future<List<HealthRecord>> _loadLocalRecordsOnly() async {
    if (_useFallback || _prefs == null) {
      final list = _memoryRecords.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }

    try {
      final List<String>? jsonList =
          _prefs!.getStringList(_scopedKey(_keyRecords));
      if (jsonList == null) return [];

      final records =
          jsonList.map((item) => HealthRecord.fromJson(item)).toList();

      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (e) {
      print('Error loading local records: $e');
      return [];
    }
  }

  // 로컬 기록만 저장하기
  Future<void> _saveLocalRecordsOnly(List<HealthRecord> records) async {
    if (_useFallback || _prefs == null) {
      _memoryRecords.clear();
      for (var r in records) {
        _memoryRecords[r.id] = r;
      }
      return;
    }

    try {
      final List<String> jsonStringList =
          records.map((item) => item.toJson()).toList();
      await _prefs!.setStringList(_scopedKey(_keyRecords), jsonStringList);
    } catch (e) {
      print('Error saving local records: $e');
    }
  }

  @override
  Future<List<HealthRecord>> loadRecords() async {
    return _loadLocalRecordsOnly();
  }

  @override
  Future<void> saveRecord(HealthRecord record) async {
    // 1. 로컬 저장소 우선 반영
    final List<HealthRecord> current = await _loadLocalRecordsOnly();
    final index = current.indexWhere((element) => element.id == record.id);
    if (index != -1) {
      current[index] = record;
    } else {
      current.add(record);
    }
    await _saveLocalRecordsOnly(current);
  }

  @override
  Future<void> deleteRecord(String id) async {
    // 1. 로컬 저장소 우선 삭제
    final List<HealthRecord> current = await _loadLocalRecordsOnly();
    current.removeWhere((element) => element.id == id);
    await _saveLocalRecordsOnly(current);
  }

  @override
  Future<double?> loadTargetWeight() async {
    if (_useFallback || _prefs == null) {
      return _memoryTargetWeight;
    }
    return _prefs!.getDouble(_scopedKey(_keyTargetWeight));
  }

  @override
  Future<void> saveTargetWeight(double weight) async {
    if (_useFallback || _prefs == null) {
      _memoryTargetWeight = weight;
      return;
    }
    await _prefs!.setDouble(_scopedKey(_keyTargetWeight), weight);
  }

  @override
  Future<double?> loadHeight() async {
    if (_useFallback || _prefs == null) {
      return _memoryHeight;
    }
    return _prefs!.getDouble(_scopedKey(_keyHeight));
  }

  @override
  Future<void> saveHeight(double height) async {
    if (_useFallback || _prefs == null) {
      _memoryHeight = height;
      return;
    }
    await _prefs!.setDouble(_scopedKey(_keyHeight), height);
  }

  @override
  Future<bool> loadDarkMode() async {
    if (_useFallback || _prefs == null) {
      return _memoryDarkMode;
    }
    return _prefs!.getBool(_scopedKey(_keyDarkMode)) ?? false;
  }

  @override
  Future<void> saveDarkMode(bool isDark) async {
    if (_useFallback || _prefs == null) {
      _memoryDarkMode = isDark;
      return;
    }
    await _prefs!.setBool(_scopedKey(_keyDarkMode), isDark);
  }

  // --- AI 엔진 및 Ollama SharedPreferences 저장/로드 로직 구현 ---

  @override
  Future<String> loadAiEngine() async {
    if (_useFallback || _prefs == null) return _memoryAiEngine ?? 'local';
    return _prefs!.getString(_scopedKey(_keyAiEngine)) ?? 'local';
  }

  @override
  Future<void> saveAiEngine(String engine) async {
    if (_useFallback || _prefs == null) {
      _memoryAiEngine = engine;
      return;
    }
    await _prefs!.setString(_scopedKey(_keyAiEngine), engine);
  }

  @override
  Future<String> loadOllamaBaseUrl() async {
    if (_useFallback || _prefs == null)
      return _memoryOllamaBaseUrl ?? 'http://localhost:11434';
    return _prefs!.getString(_scopedKey(_keyOllamaBaseUrl)) ??
        'http://localhost:11434';
  }

  @override
  Future<void> saveOllamaBaseUrl(String url) async {
    if (_useFallback || _prefs == null) {
      _memoryOllamaBaseUrl = url;
      return;
    }
    await _prefs!.setString(_scopedKey(_keyOllamaBaseUrl), url);
  }

  @override
  Future<String> loadOllamaModel() async {
    if (_useFallback || _prefs == null) return _memoryOllamaModel ?? 'llama3';
    return _prefs!.getString(_scopedKey(_keyOllamaModel)) ?? 'llama3';
  }

  @override
  Future<void> saveOllamaModel(String model) async {
    if (_useFallback || _prefs == null) {
      _memoryOllamaModel = model;
      return;
    }
    await _prefs!.setString(_scopedKey(_keyOllamaModel), model);
  }

  // --- 다중 사용자 자격증명 저장/로드 로직 구현 ---

  @override
  Future<Map<String, dynamic>> loadUserCredentials() async {
    if (_useFallback || _prefs == null) return {};
    final jsonStr = _prefs!.getString(_keyUserCredentials);
    if (jsonStr == null) return {};
    try {
      final decoded = json.decode(jsonStr) as Map;
      return decoded.map((k, v) => MapEntry(k as String, v));
    } catch (e) {
      print('Error decoding user credentials: $e');
      return {};
    }
  }

  @override
  Future<void> saveUserCredentials(Map<String, dynamic> credentials) async {
    if (_useFallback || _prefs == null) return;
    try {
      await _prefs!.setString(_keyUserCredentials, json.encode(credentials));
    } catch (e) {
      print('Error saving user credentials: $e');
    }
  }

  @override
  Future<String?> loadLastActiveUser() async {
    if (_useFallback || _prefs == null) return _memoryLastActiveUser;
    return _prefs!.getString(_keyLastActiveUser);
  }

  @override
  Future<void> saveLastActiveUser(String? userId) async {
    if (_useFallback || _prefs == null) {
      _memoryLastActiveUser = userId;
      return;
    }
    if (userId == null) {
      await _prefs!.remove(_keyLastActiveUser);
    } else {
      await _prefs!.setString(_keyLastActiveUser, userId);
    }
  }

  @override
  Future<bool> loadAutoLoginEnabled() async {
    if (_useFallback || _prefs == null) return _memoryAutoLoginEnabled;
    return _prefs!.getBool(_keyAutoLoginEnabled) ?? false;
  }

  @override
  Future<void> saveAutoLoginEnabled(bool enabled) async {
    if (_useFallback || _prefs == null) {
      _memoryAutoLoginEnabled = enabled;
      return;
    }
    await _prefs!.setBool(_keyAutoLoginEnabled, enabled);
  }

  @override
  Future<void> wipeUserScopedData(String username) async {
    if (_useFallback || _prefs == null) return;
    final keys = _prefs!.getKeys();
    final prefix = '${username}_';
    for (var key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs!.remove(key);
      }
    }
  }
}
