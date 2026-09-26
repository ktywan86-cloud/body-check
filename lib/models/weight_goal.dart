import 'dart:convert';
import 'dart:math' as math;

import 'health_record.dart';

/// 목표 기간을 나누는 단위입니다. 기간 입력과 기간별 목표(마일스톤)에 함께 쓰입니다.
enum GoalPeriodUnit { week, month }

/// 기간 단위의 저장용 키와 화면 표시 문구입니다.
extension GoalPeriodUnitLabel on GoalPeriodUnit {
  String get key => this == GoalPeriodUnit.week ? 'week' : 'month';

  /// 기간 입력칸 뒤에 붙는 단위 (예: 12주, 3개월)
  String get label => this == GoalPeriodUnit.week ? '주' : '개월';

  /// 기간별 목표 목록의 순번 표시 (예: 3주차, 2개월차)
  String get ordinal => this == GoalPeriodUnit.week ? '주차' : '개월차';
}

/// 계획 대비 진행 상태입니다.
enum GoalStatus {
  noData, // 계획 시작 이후 기록이 없음
  ahead, // 계획보다 앞서감
  onTrack, // 계획대로 진행 중
  behind, // 계획보다 뒤처짐
  achieved, // 목표 체중 달성
  ended, // 목표일이 지났지만 미달
}

/// 기간별 목표 하나(한 주 또는 한 달의 끝 지점)를 나타냅니다.
/// index 0은 시작 지점, 마지막 index는 목표 지점입니다.
class GoalMilestone {
  final int index; // 0(시작) ~ periodCount(목표)
  final DateTime date; // 이 기간이 끝나는 날짜
  final double plannedWeight; // 이 날짜까지 도달할 계획 체중 (kg)
  final bool isOverridden; // 사용자가 직접 수정한 값인지

  const GoalMilestone({
    required this.index,
    required this.date,
    required this.plannedWeight,
    required this.isOverridden,
  });
}

/// 최신 기록을 계획과 비교한 결과입니다.
class GoalProgress {
  final GoalStatus status;
  final double progressRatio; // 전체 감량 목표 대비 진행률 (0.0 ~ 1.0)
  final double? latestWeight; // 비교에 사용한 최신 기록의 체중
  final DateTime? latestDate; // 비교에 사용한 최신 기록의 날짜
  final double? plannedAtLatest; // 최신 기록 날짜 기준 계획 체중
  final double? diffFromPlan; // 실제 - 계획 (양수면 뒤처짐)
  final int currentMilestoneIndex; // 오늘이 속한 기간의 순번 (1 ~ periodCount)

  const GoalProgress({
    required this.status,
    required this.progressRatio,
    this.latestWeight,
    this.latestDate,
    this.plannedAtLatest,
    this.diffFromPlan,
    required this.currentMilestoneIndex,
  });
}

/// 목표 체중 계획을 나타내는 모델 클래스입니다.
///
/// 계획은 시작 지점(체중·날짜)과 목표 지점(체중·기간)으로 정의되며,
/// 기간별 목표는 이 두 지점 사이를 균등하게 나눠 자동으로 계산됩니다.
/// 사용자가 특정 기간의 목표를 직접 수정하면 그 이후 기간만 남은 감량분을
/// 다시 균등하게 나눠 갖습니다 (이전 기간은 바뀌지 않음).
///
/// 시작 지점을 계획 생성 시점에 고정(스냅샷)하는 이유는, 기록이 쌓일 때마다
/// 기준이 따라 움직이면 계획보다 앞서가는지 뒤처지는지 판단할 수 없기 때문입니다.
class WeightGoal {
  final double startWeight; // 계획 시작 체중 (kg)
  final DateTime startDate; // 계획 시작일 (시각 없이 날짜만)
  final double targetWeight; // 목표 체중 (kg)
  final GoalPeriodUnit periodUnit; // 기간 단위 (주 / 월)
  final int periodCount; // 목표 기간 (단위 개수)
  final Map<int, double> overrides; // 직접 수정한 기간별 목표 (index → kg)

  // --- 입력 범위 및 판정 기준 ---
  static const double minWeight = 20;
  static const double maxWeight = 300;
  static const int maxWeeks = 104;
  static const int maxMonths = 24;

  /// 계획 대비 이 범위(kg) 안이면 '순조'로 봅니다. 하루 체중 변동을 감안한 여유입니다.
  static const double onTrackTolerance = 0.5;

  /// 주당 감량 경고 기준의 상한 (kg). 실제 기준은 시작 체중의 1%와 이 값 중 작은 쪽입니다.
  static const double maxSafeKgPerWeek = 1.0;

  static const int _schemaVersion = 1;

  WeightGoal({
    required this.startWeight,
    required DateTime startDate,
    required this.targetWeight,
    required this.periodUnit,
    required this.periodCount,
    Map<int, double>? overrides,
  })  : startDate = dateOnly(startDate),
        overrides = Map.unmodifiable(overrides ?? const <int, double>{});

  // --- 날짜 계산 헬퍼 ---

  /// 시각 성분을 버리고 날짜만 남깁니다.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 두 날짜 사이의 일수입니다. 서머타임과 시각 차이의 영향을 받지 않도록 UTC 날짜로 계산합니다.
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// 시작일에서 n 단위만큼 지난 날짜를 구합니다.
  ///
  /// 월 단위는 매번 시작일에서 직접 더하고 말일로 맞춥니다.
  /// 한 달씩 누적해서 더하면 1/31 → 2/28 → 3/28처럼 날짜가 밀리기 때문입니다.
  static DateTime addUnits(DateTime start, GoalPeriodUnit unit, int n) {
    if (unit == GoalPeriodUnit.week) {
      return DateTime(start.year, start.month, start.day + 7 * n);
    }
    final totalMonths = start.month - 1 + n;
    final year = start.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, math.min(start.day, lastDay));
  }

  // --- 계획 요약 값 ---

  DateTime get targetDate => addUnits(startDate, periodUnit, periodCount);

  /// 전체 감량 목표 (kg, 양수)
  double get totalLoss => startWeight - targetWeight;

  int get totalDays => daysBetween(startDate, targetDate);

  /// 단위(주 또는 월)당 평균 감량 (kg)
  double get averageLossPerPeriod => totalLoss / periodCount;

  bool get hasOverrides => overrides.isNotEmpty;

  /// 이 계획에 적용되는 주당 감량 경고 기준 (kg).
  /// 체중이 가벼울수록 같은 1kg도 부담이 크므로 시작 체중의 1%로 제한합니다.
  double get safeKgPerWeek => math.min(maxSafeKgPerWeek, startWeight * 0.01);

  // --- 기간별 목표 계산 ---

  DateTime milestoneDate(int index) => addUnits(startDate, periodUnit, index);

  /// index번째 기간의 계획 체중입니다.
  ///
  /// 직접 수정한 값이 있으면 그 값을, 없으면 앞쪽의 가장 가까운 기준점(시작 또는
  /// 직접 수정한 기간)에서 목표까지 남은 감량분을 균등하게 나눈 값을 씁니다.
  /// 뒤쪽 값은 보지 않으므로, 앞의 기간을 고쳐도 그 이전 기간은 바뀌지 않습니다.
  double plannedWeightFor(int index) {
    if (index <= 0) return startWeight;
    if (index >= periodCount) return targetWeight;

    final overridden = overrides[index];
    if (overridden != null) return overridden;

    var anchorIndex = 0;
    var anchorWeight = startWeight;
    for (var j = index - 1; j >= 1; j--) {
      final w = overrides[j];
      if (w != null) {
        anchorIndex = j;
        anchorWeight = w;
        break;
      }
    }
    return anchorWeight +
        (targetWeight - anchorWeight) *
            (index - anchorIndex) /
            (periodCount - anchorIndex);
  }

  /// 시작(0)부터 목표(periodCount)까지 모든 기간별 목표를 반환합니다.
  List<GoalMilestone> milestones() {
    return List.generate(periodCount + 1, (i) {
      return GoalMilestone(
        index: i,
        date: milestoneDate(i),
        plannedWeight: plannedWeightFor(i),
        isOverridden: overrides.containsKey(i),
      );
    });
  }

  /// 특정 날짜의 계획 체중입니다. 기간별 목표 사이는 날짜 비율로 보간합니다.
  double plannedWeightAt(DateTime date) {
    final day = dateOnly(date);
    if (!day.isAfter(startDate)) return startWeight;
    if (!day.isBefore(targetDate)) return targetWeight;

    for (var i = 1; i <= periodCount; i++) {
      final end = milestoneDate(i);
      if (!day.isAfter(end)) {
        final begin = milestoneDate(i - 1);
        final span = daysBetween(begin, end);
        final from = plannedWeightFor(i - 1);
        final to = plannedWeightFor(i);
        if (span <= 0) return to;
        return from + (to - from) * daysBetween(begin, day) / span;
      }
    }
    return targetWeight;
  }

  /// 오늘이 속한 기간의 순번입니다 (1 ~ periodCount).
  int currentMilestoneIndex(DateTime today) {
    final day = dateOnly(today);
    for (var i = 1; i <= periodCount; i++) {
      if (!day.isAfter(milestoneDate(i))) return i;
    }
    return periodCount;
  }

  // --- 기간별 목표 직접 수정 ---

  /// index번째 기간에 입력할 수 있는 체중 범위입니다. 시작과 목표 지점은 수정할 수 없어 null입니다.
  ///
  /// 감량 계획이므로 직전 기간보다 무거울 수 없고, 목표보다 가벼울 수 없습니다.
  /// 직전 기간과 같은 값(정체기)은 허용합니다.
  ({double min, double max})? overrideRange(int index) {
    if (index <= 0 || index >= periodCount) return null;
    return (min: targetWeight, max: plannedWeightFor(index - 1));
  }

  /// index보다 뒤에 있는 직접 수정 값의 개수입니다. 수정 전 확인 문구에 씁니다.
  int overridesAfter(int index) =>
      overrides.keys.where((k) => k > index).length;

  /// index번째 기간의 목표를 직접 지정한 새 계획을 반환합니다.
  ///
  /// 이후 기간은 새 값에서 목표까지 다시 균등 분배되도록, 뒤쪽의 직접 수정 값은 모두 지웁니다.
  /// 뒤쪽 값을 남겨 두면 앞쪽 변경으로 계획선이 거꾸로 올라가는 구간이 생길 수 있습니다.
  WeightGoal withOverride(int index, double weight) {
    final range = overrideRange(index);
    if (range == null) {
      throw ArgumentError('시작 지점과 목표 지점은 직접 수정할 수 없습니다.');
    }
    if (weight < range.min - 1e-9 || weight > range.max + 1e-9) {
      throw ArgumentError('허용 범위를 벗어난 체중입니다.');
    }
    final next = <int, double>{
      for (final e in overrides.entries)
        if (e.key < index) e.key: e.value,
    };
    next[index] = weight;
    return copyWith(overrides: next);
  }

  /// index번째 기간의 직접 수정 값을 되돌린 새 계획을 반환합니다.
  /// 수정과 같은 이유로 뒤쪽의 직접 수정 값도 함께 지웁니다.
  WeightGoal withoutOverride(int index) {
    final next = <int, double>{
      for (final e in overrides.entries)
        if (e.key < index) e.key: e.value,
    };
    return copyWith(overrides: next);
  }

  // --- 경고 및 검증 ---

  /// 주당 감량이 권장 속도를 넘는 기간의 순번 목록입니다. 저장을 막지는 않고 경고만 합니다.
  List<int> aggressiveSegments() {
    final limit = safeKgPerWeek;
    final result = <int>[];
    for (var i = 1; i <= periodCount; i++) {
      final days = daysBetween(milestoneDate(i - 1), milestoneDate(i));
      if (days <= 0) continue;
      final loss = plannedWeightFor(i - 1) - plannedWeightFor(i);
      if (loss / (days / 7) > limit + 1e-9) result.add(i);
    }
    return result;
  }

  /// 계획의 기본 입력값을 검사합니다. 문제가 있으면 한국어 오류 문구를, 없으면 null을 반환합니다.
  /// 화면의 입력 검증과 provider의 저장 검증이 같은 규칙을 쓰도록 모델에 둡니다.
  static String? validateBase({
    required double? startWeight,
    required double? targetWeight,
    required GoalPeriodUnit unit,
    required int? periodCount,
  }) {
    if (startWeight == null) return '시작 체중을 입력해 주세요.';
    if (targetWeight == null) return '목표 체중을 입력해 주세요.';
    if (startWeight < minWeight || startWeight > maxWeight) {
      return '시작 체중은 ${minWeight.toInt()}~${maxWeight.toInt()}kg 사이로 입력해 주세요.';
    }
    if (targetWeight < minWeight || targetWeight > maxWeight) {
      return '목표 체중은 ${minWeight.toInt()}~${maxWeight.toInt()}kg 사이로 입력해 주세요.';
    }
    if (targetWeight > startWeight - 0.1 + 1e-9) {
      return '목표 체중은 시작 체중보다 낮아야 합니다. (감량 계획만 지원)';
    }
    if (periodCount == null || periodCount < 1) {
      return '기간을 1${unit.label} 이상으로 입력해 주세요.';
    }
    final max = unit == GoalPeriodUnit.week ? maxWeeks : maxMonths;
    if (periodCount > max) {
      return '기간은 최대 $max${unit.label}까지 설정할 수 있습니다.';
    }
    return null;
  }

  // --- 기록과의 비교 ---

  /// index번째 기간 안에서 가장 최근 기록을 찾습니다. 없으면 null입니다.
  /// 첫 기간은 시작일 당일 기록도 포함합니다.
  HealthRecord? actualFor(int index, List<HealthRecord> records) {
    if (index <= 0 || index > periodCount) return null;
    final begin = milestoneDate(index - 1);
    final end = milestoneDate(index);

    HealthRecord? latest;
    for (final r in records) {
      final day = dateOnly(r.date);
      final afterBegin = index == 1 ? !day.isBefore(begin) : day.isAfter(begin);
      if (!afterBegin || day.isAfter(end)) continue;
      if (latest == null || r.date.isAfter(latest.date)) latest = r;
    }
    return latest;
  }

  /// 최신 기록을 그 기록 날짜의 계획 체중과 비교합니다.
  ///
  /// 오늘의 계획과 비교하지 않는 이유: 마지막 기록이 며칠 전이면 며칠 전 체중을
  /// 오늘 목표와 비교하게 되어, 실제로는 순조로운데도 뒤처진 것으로 보이기 때문입니다.
  /// [today]를 받는 것은 테스트에서 현재 시각에 의존하지 않기 위해서입니다.
  GoalProgress evaluate(List<HealthRecord> records, DateTime today) {
    final day = dateOnly(today);
    final currentIndex = currentMilestoneIndex(day);

    HealthRecord? latest;
    for (final r in records) {
      if (latest == null || r.date.isAfter(latest.date)) latest = r;
    }

    if (latest == null || dateOnly(latest.date).isBefore(startDate)) {
      return GoalProgress(
        status: GoalStatus.noData,
        progressRatio: 0,
        currentMilestoneIndex: currentIndex,
      );
    }

    final weight = latest.weight;
    final ratio = totalLoss <= 0
        ? 0.0
        : ((startWeight - weight) / totalLoss).clamp(0.0, 1.0).toDouble();
    final planned = plannedWeightAt(latest.date);
    final diff = weight - planned;

    final GoalStatus status;
    if (weight <= targetWeight + 1e-9) {
      status = GoalStatus.achieved;
    } else if (day.isAfter(targetDate)) {
      status = GoalStatus.ended;
    } else if (diff <= -onTrackTolerance) {
      status = GoalStatus.ahead;
    } else if (diff >= onTrackTolerance) {
      status = GoalStatus.behind;
    } else {
      status = GoalStatus.onTrack;
    }

    return GoalProgress(
      status: status,
      progressRatio: ratio,
      latestWeight: weight,
      latestDate: latest.date,
      plannedAtLatest: planned,
      diffFromPlan: diff,
      currentMilestoneIndex: currentIndex,
    );
  }

  // --- 복사 및 직렬화 ---

  WeightGoal copyWith({
    double? startWeight,
    DateTime? startDate,
    double? targetWeight,
    GoalPeriodUnit? periodUnit,
    int? periodCount,
    Map<int, double>? overrides,
    bool clearOverrides = false,
  }) {
    return WeightGoal(
      startWeight: startWeight ?? this.startWeight,
      startDate: startDate ?? this.startDate,
      targetWeight: targetWeight ?? this.targetWeight,
      periodUnit: periodUnit ?? this.periodUnit,
      periodCount: periodCount ?? this.periodCount,
      overrides: clearOverrides ? null : (overrides ?? this.overrides),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'v': _schemaVersion, // 저장 형식 버전 (이후 마이그레이션용)
      'startWeight': startWeight,
      'startDate': startDate.toIso8601String(),
      'targetWeight': targetWeight,
      'periodUnit': periodUnit.key,
      'periodCount': periodCount,
      // JSON 객체의 키는 문자열이어야 하므로 순번을 문자열로 바꿔 저장합니다.
      'overrides': {
        for (final e in overrides.entries) e.key.toString(): e.value,
      },
    };
  }

  /// 저장된 Map에서 계획을 복원합니다. 필수 값이 없으면 [FormatException]을 던집니다.
  ///
  /// 직접 수정 값은 순번이 범위를 벗어나거나 감량 규칙(직전보다 무겁지 않고 목표보다
  /// 가볍지 않음)을 어기면 버립니다. 저장 데이터가 손상돼도 계획선이 거꾸로 가지 않게 하기 위함입니다.
  factory WeightGoal.fromMap(Map<String, dynamic> map) {
    final startWeight = map['startWeight'];
    final startDate = map['startDate'];
    final targetWeight = map['targetWeight'];
    final periodCount = map['periodCount'];
    if (startWeight is! num ||
        startDate is! String ||
        targetWeight is! num ||
        periodCount is! num) {
      throw const FormatException('목표 계획 데이터에 필수 값이 없습니다.');
    }

    var goal = WeightGoal(
      startWeight: startWeight.toDouble(),
      startDate: DateTime.parse(startDate),
      targetWeight: targetWeight.toDouble(),
      periodUnit: map['periodUnit'] == 'month'
          ? GoalPeriodUnit.month
          : GoalPeriodUnit.week,
      periodCount: periodCount.toInt(),
    );

    final rawOverrides = map['overrides'];
    if (rawOverrides is Map) {
      final parsed = <int, double>{};
      rawOverrides.forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index != null && value is num) parsed[index] = value.toDouble();
      });
      // 앞 순번부터 하나씩 검증하며 적용합니다.
      final keys = parsed.keys.toList()..sort();
      for (final k in keys) {
        final range = goal.overrideRange(k);
        final w = parsed[k]!;
        if (range == null || w < range.min - 1e-9 || w > range.max + 1e-9) {
          continue;
        }
        goal = goal.copyWith(overrides: {...goal.overrides, k: w});
      }
    }
    return goal;
  }

  String toJson() => json.encode(toMap());

  factory WeightGoal.fromJson(String source) =>
      WeightGoal.fromMap(json.decode(source) as Map<String, dynamic>);
}
