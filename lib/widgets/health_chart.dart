import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';
import '../models/weight_goal.dart';

/// 차트에 보여줄 기간 범위입니다.
enum ChartRange {
  recent, // 최근 기록 위주 (목표 계획은 앞으로 2주까지만 미리 보여줌)
  plan, // 목표 계획 전체 (시작일부터 목표일까지)
}

/// 체중 데이터 추이와 7일 평균선, 목표 체중 기준선, 목표 계획선을 함께 그려주는
/// 고성능 및 반응형 라인 차트 위젯입니다.
///
/// x축은 날짜입니다 (기준일로부터 지난 일수). 기록이 없는 미래의 목표일까지
/// 계획선을 그리려면 기록 순번이 아닌 날짜 축이 필요하기 때문입니다.
class HealthChart extends StatelessWidget {
  final List<HealthRecord> records; // 정렬 순서 무관 (내부에서 오름차순 정렬)
  final double? targetWeight; // 목표 체중
  final WeightGoal? goal; // 목표 계획 (없으면 계획선을 그리지 않음)
  final ChartRange range;

  const HealthChart({
    super.key,
    required this.records,
    this.targetWeight,
    this.goal,
    this.range = ChartRange.recent,
  });

  /// 계획선 색상입니다. 범례에서도 같은 색을 씁니다.
  static const Color planColor = Color(0xFF10B981);

  /// 최근 범위에서 계획선을 앞으로 미리 보여줄 일수
  static const int _recentLookaheadDays = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goal = this.goal;

    // fl_chart 처리를 위해 데이터를 시간 오름차순(과거 -> 최신)으로 정렬합니다.
    final chartRecords = List<HealthRecord>.from(records);
    chartRecords.sort((a, b) => a.date.compareTo(b.date));

    // 계획 전체 보기일 때만 값이 있습니다. (Flutter 버전에 상관없이 null 검사가 통하도록 별도 변수로 둠)
    final WeightGoal? wholePlan = range == ChartRange.plan ? goal : null;
    final showWholePlan = wholePlan != null;
    final List<HealthRecord> displayedRecords;
    if (wholePlan != null) {
      // 계획 전체 보기: 시작 1주 전부터의 기록 (과도한 점 개수 방지를 위해 최대 200개)
      final from = wholePlan.startDate.subtract(const Duration(days: 7));
      final inPlan = chartRecords.where((r) => !r.date.isBefore(from)).toList();
      displayedRecords =
          inPlan.length > 200 ? inPlan.sublist(inPlan.length - 200) : inPlan;
    } else {
      // 최근 최대 30개 기록만 차트에 노출하여 모바일 가독성을 확보합니다.
      displayedRecords = chartRecords.length > 30
          ? chartRecords.sublist(chartRecords.length - 30)
          : chartRecords;
    }

    // 그릴 선이 없으면 안내 메시지를 표시합니다.
    // 계획 전체 보기는 기록이 없어도 계획선만으로 그릴 수 있습니다.
    final canDraw = showWholePlan ||
        displayedRecords.length >= 2 ||
        (goal != null && displayedRecords.isNotEmpty);
    if (!canDraw) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart,
                size: 48, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text(
              '데이터가 2개 이상 기록되면 그래프가 표시됩니다.',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    // --- x축(날짜) 도메인 계산 ---

    // 기준일: 표시할 첫 기록의 날짜. 계획 전체 보기라면 계획 시작일이 더 이르면 그 날짜.
    DateTime base = displayedRecords.isNotEmpty
        ? WeightGoal.dateOnly(displayedRecords.first.date)
        : wholePlan!.startDate; // 기록이 없으면 canDraw 조건상 계획 전체 보기뿐
    if (wholePlan != null && wholePlan.startDate.isBefore(base)) {
      base = wholePlan.startDate;
    }

    // 분 단위로 계산해 같은 날 여러 기록도 순서대로 조금씩 떨어져 찍히게 합니다.
    double xOf(DateTime d) => d.difference(base).inMinutes / 1440.0;
    DateTime dateAtX(double x) =>
        base.add(Duration(minutes: (x * 1440).round()));

    final lastRecordX =
        displayedRecords.isEmpty ? 0.0 : xOf(displayedRecords.last.date);

    double spanEnd = lastRecordX;
    if (goal != null) {
      final targetX = xOf(goal.targetDate);
      spanEnd = showWholePlan
          ? math.max(lastRecordX, targetX)
          : math.max(
              lastRecordX,
              math.min(lastRecordX + _recentLookaheadDays, targetX),
            );
    }
    if (spanEnd <= 0) spanEnd = 1;

    // 눈금 간격을 정수 일수로 잡고 maxX를 눈금 위에 맞춥니다.
    // 맞추지 않으면 fl_chart가 끝 지점에 라벨을 하나 더 찍어 옆 라벨과 겹칩니다.
    final interval = math.max(1, (spanEnd / 5).ceil()).toDouble();
    final maxX = interval * (spanEnd / interval).ceil();
    const minX = 0.0;
    final labelFormat =
        DateFormat(maxX > 180 ? 'yy.MM' : 'MM.dd'); // 긴 기간은 연.월로 표시

    // --- 선 데이터 ---

    // 1. 체중 추이 스팟
    final List<FlSpot> weightSpots = [];
    // 2. 7일 평균 스팟 (정확히는 최근 7개 기록의 평균)
    final List<FlSpot> avgSpots = [];

    for (int i = 0; i < displayedRecords.length; i++) {
      final double xVal = xOf(displayedRecords[i].date);
      final double yVal = displayedRecords[i].weight;
      weightSpots.add(FlSpot(xVal, yVal));

      // 7일 평균 계산 로직 (현재 인덱스 포함 이전 최대 7개 평균)
      double sum = 0;
      int count = 0;
      for (int k = i; k >= 0 && k > i - 7; k--) {
        sum += displayedRecords[k].weight;
        count++;
      }
      avgSpots.add(FlSpot(xVal, sum / count));
    }

    // 3. 목표 계획 스팟
    // 보이는 범위 밖에서 시작하거나 끝나는 계획은 경계에 보간 점을 넣어 선이 끊기지 않게 합니다.
    // planMeta는 각 스팟이 어떤 기간별 목표인지 (경계 보간 점이면 null) 기록해 툴팁에 씁니다.
    final List<FlSpot> planSpots = [];
    final List<GoalMilestone?> planMeta = [];
    if (goal != null) {
      final planStartX = xOf(goal.startDate);
      final planEndX = xOf(goal.targetDate);
      final lo = math.max(minX, planStartX);
      final hi = math.min(maxX, planEndX);

      if (lo < hi) {
        if (lo > planStartX) {
          planSpots.add(FlSpot(lo, goal.plannedWeightAt(dateAtX(lo))));
          planMeta.add(null);
        }
        for (final m in goal.milestones()) {
          final mx = xOf(m.date);
          if (mx < lo || mx > hi) continue;
          planSpots.add(FlSpot(mx, m.plannedWeight));
          planMeta.add(m);
        }
        if (hi < planEndX) {
          planSpots.add(FlSpot(hi, goal.plannedWeightAt(dateAtX(hi))));
          planMeta.add(null);
        }
      }
    }
    final visibleMilestones = planMeta.whereType<GoalMilestone>().length;
    // 기간별 목표가 너무 많으면 점을 생략해 선만 보여줍니다.
    final showPlanDots = visibleMilestones <= 40;

    // --- Y축 범위 ---
    // 실제 기록, 목표 체중, 계획선을 모두 담도록 잡고 위아래로 3kg 여유를 둡니다.
    final allY = <double>[
      ...displayedRecords.map((e) => e.weight),
      ...planSpots.map((e) => e.y),
      if (targetWeight != null) targetWeight!,
    ];
    double minY = allY.reduce(math.min);
    double maxY = allY.reduce(math.max);
    minY = (minY - 3).clamp(0, double.infinity).toDouble();
    maxY = maxY + 3;

    final planName = goal?.periodUnit.ordinal ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 12, bottom: 8),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false, // 가로선만 표시하여 심플함 유지
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value < minX - 1e-6 || value > maxX + 1e-6) {
                    return const SizedBox();
                  }
                  // 눈금 위가 아닌 값(끝 지점 보정 라벨 등)은 그리지 않습니다.
                  final remainder = value % interval;
                  if (remainder > 1e-6 && interval - remainder > 1e-6) {
                    return const SizedBox();
                  }

                  final date = base.add(Duration(days: value.round()));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(
                      labelFormat.format(date),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // 정수 kg 텍스트 표시
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${value.toStringAsFixed(0)}k',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 10,
              tooltipBgColor: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.9)
                  : Colors.white.withOpacity(0.9),
              tooltipBorder: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              getTooltipItems: (touchedSpots) {
                // x가 날짜라서 기록 목록의 위치는 spotIndex로 찾아야 합니다.
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  switch (touchedSpot.barIndex) {
                    case 0:
                      final record = displayedRecords[touchedSpot.spotIndex];
                      return LineTooltipItem(
                        '${DateFormat('yyyy.MM.dd').format(record.date)}\n',
                        TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '체중: ${record.weight} kg',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          if (record.bodyFat != null)
                            TextSpan(
                              text: '\n체지방: ${record.bodyFat}%',
                              style: const TextStyle(
                                color: Colors.teal,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      );
                    case 1:
                      return LineTooltipItem(
                        '7일 평균: ',
                        TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 10,
                        ),
                        children: [
                          TextSpan(
                            text: '${touchedSpot.y.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    default:
                      // 경계 보간 점은 실제 기간별 목표가 아니므로 툴팁을 숨깁니다.
                      final milestone = planMeta[touchedSpot.spotIndex];
                      if (milestone == null || milestone.index == 0) {
                        return null;
                      }
                      return LineTooltipItem(
                        '계획 ${milestone.index}$planName: ',
                        TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 10,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${milestone.plannedWeight.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: planColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                  }
                }).toList();
              },
            ),
          ),

          // 목표 체중 기준 수평 점선 오버레이
          extraLinesData: ExtraLinesData(
            horizontalLines: targetWeight != null
                ? [
                    HorizontalLine(
                      y: targetWeight!,
                      color: Colors.red.withOpacity(0.4),
                      strokeWidth: 1.5,
                      dashArray: [5, 5], // 점선 형태
                    ),
                  ]
                : [],
          ),

          // 순서를 [실제 체중, 7일 평균, 계획]으로 고정합니다. 툴팁이 barIndex로 구분합니다.
          lineBarsData: [
            // Line 1: 실제 체중 변화 곡선
            LineChartBarData(
              spots: weightSpots,
              show: weightSpots.isNotEmpty, // 계획 전체 보기는 기록 없이도 그림
              isCurved: true, // 곡선 큐빅 베지어 적용
              // 날짜 간격이 불균등하면 곡선이 점을 넘어 튀어나가므로 방지합니다.
              preventCurveOverShooting: true,
              color: theme.primaryColor,
              barWidth: 4.0,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: theme.primaryColor,
                    strokeWidth: 2,
                    strokeColor: theme.colorScheme.surface,
                  );
                },
              ),
              // 하단 하늘색 그라데이션 영역 채우기
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withOpacity(0.32),
                    theme.primaryColor.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Line 2: 7일 이동 평균 곡선
            LineChartBarData(
              spots: avgSpots,
              show: avgSpots.isNotEmpty,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.amber,
              barWidth: 2.0,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false), // 평균선은 점을 숨겨 간소화
              dashArray: [4, 2], // 7일 평균선은 미세 점선
            ),

            // Line 3: 목표 계획선 (기간별 목표를 직선으로 연결)
            LineChartBarData(
              spots: planSpots,
              show: planSpots.isNotEmpty,
              isCurved: false,
              color: planColor,
              barWidth: 2.0,
              dashArray: [6, 4],
              dotData: FlDotData(
                show: showPlanDots,
                getDotPainter: (spot, percent, barData, index) {
                  final milestone = planMeta[index];
                  // 경계 보간 점은 점을 그리지 않습니다.
                  if (milestone == null) {
                    return FlDotCirclePainter(
                      radius: 0,
                      color: Colors.transparent,
                      strokeWidth: 0,
                    );
                  }
                  // 직접 수정한 기간은 속이 빈 점으로 구분합니다.
                  return FlDotCirclePainter(
                    radius: 3,
                    color: milestone.isOverridden
                        ? theme.colorScheme.surface
                        : planColor,
                    strokeWidth: 1.5,
                    strokeColor: planColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
