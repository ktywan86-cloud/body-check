import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';

/// 체중 데이터 추이와 7일 평균선, 목표 체중 기준선을 함께 그려주는
/// 고성능 및 반응형 라인 차트 위젯입니다.
class HealthChart extends StatelessWidget {
  final List<HealthRecord> records; // 오름차순(오래된 순) 정렬 권장
  final double? targetWeight; // 목표 체중

  const HealthChart({
    super.key,
    required this.records,
    this.targetWeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 만약 기록이 없거나 2개 미만인 경우 그래프를 그릴 수 없으므로 안내 메시지를 표시합니다.
    if (records.length < 2) {
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

    // fl_chart 처리를 위해 데이터를 시간 오름차순(과거 -> 최신)으로 정렬합니다.
    final chartRecords = List<HealthRecord>.from(records);
    chartRecords.sort((a, b) => a.date.compareTo(b.date));

    // 최근 최대 30개 기록만 차트에 노출하여 모바일 가독성을 확보합니다.
    final displayedRecords = chartRecords.length > 30
        ? chartRecords.sublist(chartRecords.length - 30)
        : chartRecords;

    // 1. 체중 추이 스팟 생성
    final List<FlSpot> weightSpots = [];
    // 2. 7일 평균 스팟 생성
    final List<FlSpot> avgSpots = [];

    for (int i = 0; i < displayedRecords.length; i++) {
      final double xVal = i.toDouble();
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

    // Y축 최소/최대값 보정을 통해 차트를 보기 좋은 축척으로 조절합니다.
    double minY =
        displayedRecords.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    double maxY =
        displayedRecords.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    if (targetWeight != null) {
      if (targetWeight! < minY) minY = targetWeight!;
      if (targetWeight! > maxY) maxY = targetWeight!;
    }
    // 마진 3kg 추가
    minY = (minY - 3).clamp(0, double.infinity);
    maxY = maxY + 3;

    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 12, bottom: 8),
      child: LineChart(
        LineChartData(
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
                interval: (displayedRecords.length / 5)
                    .clamp(1, double.infinity)
                    .ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= displayedRecords.length) {
                    return const SizedBox();
                  }

                  // x축 날짜 라벨 포맷 (MM.dd)
                  final date = displayedRecords[index].date;
                  final formattedDate = DateFormat('MM.dd').format(date);

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(
                      formattedDate,
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
                  // 소수점 1자리 텍스트 표시
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
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  final record = displayedRecords[index];
                  final isWeightLine = touchedSpot.barIndex == 0;

                  if (isWeightLine) {
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
                  } else {
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

          lineBarsData: [
            // Line 1: 실제 체중 변화 곡선
            LineChartBarData(
              spots: weightSpots,
              isCurved: true, // 곡선 큐빅 베지어 적용
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
              isCurved: true,
              color: Colors.amber,
              barWidth: 2.0,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false), // 평균선은 점을 숨겨 간소화
              dashArray: [4, 2], // 7일 평균선은 미세 점선
            ),
          ],
        ),
      ),
    );
  }
}
