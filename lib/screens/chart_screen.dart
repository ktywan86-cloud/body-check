import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';
import '../providers/health_provider.dart';
import '../widgets/health_chart.dart';

/// 건강 통계 및 차트를 보여주는 분석 화면입니다.
/// 최근 체중 변화 곡선과 7일 이동평균선, 목표 체중 기준선이 그려진 fl_chart 그래프를 제공하고,
/// 저장된 데이터의 최소/최대/평균 체중 분석 지표를 수치화하여 카드 레이아웃으로 노출합니다.
class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final records = provider.records;

    // 통계에 사용할 통계값 계산 ( records 는 역순정렬이므로 전체를 돌며 연산합니다 )
    double? minWeight;
    double? maxWeight;
    double avgWeight = 0;

    if (records.isNotEmpty) {
      minWeight = records.first.weight;
      maxWeight = records.first.weight;
      double sum = 0;
      for (var r in records) {
        if (r.weight < minWeight!) minWeight = r.weight;
        if (r.weight > maxWeight!) maxWeight = r.weight;
        sum += r.weight;
      }
      avgWeight = sum / records.length;
    }

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 화면 타이틀
            Text(
              '통계 분석',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '체중 추이와 주요 지표 통계를 체계적으로 분석합니다.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),

            // 1. 메인 차트 카드 (큰 면적으로 강조)
            Container(
              width: double.infinity,
              height: 380,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.15)
                        : Colors.blueGrey.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.analytics_outlined,
                            color: theme.primaryColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.weightGoal != null
                              ? '체중 추이와 목표 계획'
                              : '체중 추이 분석 리포트',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 범례 표시 (좁은 화면에서도 넘치지 않도록 줄바꿈 허용)
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildLegendItem('실제 체중', theme.primaryColor),
                      _buildLegendItem('7일 평균', Colors.amber, isDashed: true),
                      if (provider.weightGoal != null)
                        _buildLegendItem('목표 계획', HealthChart.planColor,
                            isDashed: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: HealthChart(
                      records: records,
                      targetWeight: provider.targetWeight,
                      goal: provider.weightGoal,
                      range: ChartRange.plan, // 계획이 있으면 시작일부터 목표일까지 전체
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. 건강 분석 통계 지표 카드들 (반응형 그리드 구성)
            if (records.isNotEmpty)
              Text(
                '체중 데이터 요약',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            if (records.isNotEmpty) const SizedBox(height: 12),
            if (records.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  final crossCount = width >= 600 ? 3 : 1;
                  final aspect = width >= 600 ? 1.8 : 3.0;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: aspect,
                    children: [
                      // 최저 체중 카드
                      _buildMetricSummaryCard(
                        '최저 체중',
                        '${minWeight!.toStringAsFixed(1)} kg',
                        Icons.trending_down,
                        Colors.blue,
                        theme,
                      ),
                      // 최고 체중 카드
                      _buildMetricSummaryCard(
                        '최고 체중',
                        '${maxWeight!.toStringAsFixed(1)} kg',
                        Icons.trending_up,
                        Colors.redAccent,
                        theme,
                      ),
                      // 평균 체중 카드
                      _buildMetricSummaryCard(
                        '전체 평균',
                        '${avgWeight.toStringAsFixed(1)} kg',
                        Icons.star_half,
                        Colors.amber,
                        theme,
                      ),
                    ],
                  );
                },
              ),
            if (records.isNotEmpty) const SizedBox(height: 24),
            _buildPhotoTimelineSection(context, records, theme),
          ],
        ),
      ),
    );
  }

  /// 그래프 상단의 색상 범례 표시용 헬퍼입니다.
  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Wrap 안에서 한 줄에 나란히 놓이도록
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
      ],
    );
  }

  /// 하단 분석 통계 요약용 카드 레이아웃 빌더입니다.
  Widget _buildMetricSummaryCard(String title, String value, IconData icon,
      Color iconColor, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.12)
                : Colors.blueGrey.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 바디 포토 타임라인 섹션 빌더
  Widget _buildPhotoTimelineSection(
      BuildContext context, List<HealthRecord> records, ThemeData theme) {
    final photoRecords =
        records.where((r) => r.photoBase64 != null).toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '바디 포토 타임라인',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (photoRecords.isEmpty)
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined,
                    color: theme.colorScheme.onSurface.withOpacity(0.25),
                    size: 36),
                const SizedBox(height: 8),
                Text(
                  '등록된 바디 사진이 없습니다.',
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                ),
                const SizedBox(height: 4),
                Text(
                  '기록 등록 시 사진을 추가하여 변화를 시각적으로 확인해 보세요!',
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.3)),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: photoRecords.length,
              itemBuilder: (context, index) {
                final r = photoRecords[index];
                return GestureDetector(
                  onTap: () => _showPhotoLightbox(context, r, theme),
                  child: Hero(
                    tag: 'chart_photo_${r.id}',
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _decodeBase64(r.photoBase64!),
                              fit: BoxFit.cover,
                              width: 120,
                              height: 170,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                DateFormat('MM/dd').format(r.date),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${r.weight}kg',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 바디 사진을 모달 팝업으로 크게 보여줍니다.
  void _showPhotoLightbox(
      BuildContext context, HealthRecord record, ThemeData theme) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Hero(
                    tag: 'chart_photo_${record.id}',
                    child: Image.memory(
                      _decodeBase64(record.photoBase64!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('yyyy년 MM월 dd일 (E)').format(record.date),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    final rawBase64 =
        commaIndex != -1 ? dataUrl.substring(commaIndex + 1) : dataUrl;
    return base64Decode(rawBase64);
  }
}
