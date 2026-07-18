import 'dart:convert';

/// 건강 기록 데이터를 나타내는 모델 클래스입니다.
/// 체중, 체지방률, 허리둘레, 수면 시간 및 운동 내용, 식단 상태 등을 포함합니다.
class HealthRecord {
  final String id; // 기록의 고유 식별자 (UUID 또는 타임스탬프)
  final DateTime date; // 기록 등록 날짜
  final double weight; // 체중 (kg)
  final double? bodyFat; // 체지방률 (%, 선택 사항)
  final double? waist; // 허리둘레 (cm, 선택 사항)
  final String? exercise; // 운동 내용 (선택 사항)
  final double? sleepHours; // 수면 시간 (시간, 선택 사항)
  final String mealStatus; // 식단 상태 ('good': 좋음, 'normal': 보통, 'bad': 나쁨)
  final String? memo; // 메모 (선택 사항)
  final String? photoBase64; // 바디 사진 (Base64 인코딩 문자열, 선택 사항)

  HealthRecord({
    required this.id,
    required this.date,
    required this.weight,
    this.bodyFat,
    this.waist,
    this.exercise,
    this.sleepHours,
    required this.mealStatus,
    this.memo,
    this.photoBase64,
  });

  /// 이 객체의 사본을 만들면서 일부 필드만 수정할 수 있게 해주는 헬퍼 메서드입니다.
  /// 수정 기능 구현 시 매우 유용하게 사용됩니다.
  HealthRecord copyWith({
    String? id,
    DateTime? date,
    double? weight,
    double? bodyFat,
    double? waist,
    String? exercise,
    double? sleepHours,
    String? mealStatus,
    String? memo,
    String? photoBase64,
    bool clearPhoto = false,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      bodyFat: bodyFat ?? this.bodyFat,
      waist: waist ?? this.waist,
      exercise: exercise ?? this.exercise,
      sleepHours: sleepHours ?? this.sleepHours,
      mealStatus: mealStatus ?? this.mealStatus,
      memo: memo ?? this.memo,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
    );
  }

  /// 로컬 저장소(shared_preferences) 등에 저장하기 위해 객체를 Map 형태로 변환합니다.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(), // 날짜는 ISO 8601 문자열로 저장
      'weight': weight,
      'bodyFat': bodyFat,
      'waist': waist,
      'exercise': exercise,
      'sleepHours': sleepHours,
      'mealStatus': mealStatus,
      'memo': memo,
      'photoBase64': photoBase64,
    };
  }

  /// 로컬 저장소에서 불러온 Map 데이터를 바탕으로 객체를 역직렬화(생성)합니다.
  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] ?? '',
      date: DateTime.parse(map['date']),
      weight: (map['weight'] as num).toDouble(),
      bodyFat:
          map['bodyFat'] != null ? (map['bodyFat'] as num).toDouble() : null,
      waist: map['waist'] != null ? (map['waist'] as num).toDouble() : null,
      exercise: map['exercise'],
      sleepHours: map['sleepHours'] != null
          ? (map['sleepHours'] as num).toDouble()
          : null,
      mealStatus: map['mealStatus'] ?? 'normal',
      memo: map['memo'],
      photoBase64: map['photoBase64'],
    );
  }

  /// Map 데이터를 JSON 문자열로 변환합니다.
  String toJson() => json.encode(toMap());

  /// JSON 문자열을 객체로 역직렬화합니다.
  factory HealthRecord.fromJson(String source) =>
      HealthRecord.fromMap(json.decode(source));
}
