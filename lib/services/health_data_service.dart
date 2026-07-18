/// 향후 Apple Health, Google Fit 등 모바일 기기의 건강 데이터 SDK와
/// 연동할 수 있도록 데이터 연동 구조를 사전에 분리하여 정의합니다.
abstract class HealthDataService {
  /// 사용자가 건강 데이터 연동 권한을 허용했는지 여부를 반환합니다.
  Future<bool> isAuthorized();

  /// 기기 건강 데이터 연동 권한을 요청합니다.
  Future<bool> requestAuthorization();

  /// 지정한 날짜의 걸음 수 데이터를 동기화하여 가져옵니다.
  Future<int?> fetchSteps(DateTime date);

  /// 지정한 날짜의 수면 데이터를 동기화하여 가져옵니다.
  Future<double?> fetchSleepDuration(DateTime date);

  /// 기기에서 당일 체중 데이터를 동기화하여 가져옵니다.
  Future<double?> fetchWeight(DateTime date);
}

/// MVP 단계에서 사용할 목(Mock) 연동 서비스입니다.
/// 나중에 플러그인 패키지(예: health, flutter_health_connect)를 이용해 실제 코드를 채워넣을 수 있습니다.
class MockHealthDataService implements HealthDataService {
  bool _authorized = false;

  @override
  Future<bool> isAuthorized() async {
    // 권한 체크 모방
    return _authorized;
  }

  @override
  Future<bool> requestAuthorization() async {
    // 권한 요청 모방
    _authorized = true;
    return _authorized;
  }

  @override
  Future<int?> fetchSteps(DateTime date) async {
    // 임시 걸음 수 데이터 반환
    return null;
  }

  @override
  Future<double?> fetchSleepDuration(DateTime date) async {
    // 임시 수면 시간 데이터 반환
    return null;
  }

  @override
  Future<double?> fetchWeight(DateTime date) async {
    // 임시 체중 데이터 반환
    return null;
  }
}
