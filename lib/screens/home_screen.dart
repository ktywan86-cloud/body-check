import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weight_goal.dart';
import '../providers/health_provider.dart';
import '../widgets/goal_status_style.dart';
import '../widgets/summary_card.dart';
import '../widgets/health_chart.dart';
import 'goal_screen.dart';

/// 메인 홈 대시보드 화면입니다.
/// 최근 건강 지표 요약(현재 체중, 목표 체중, 7일 평균, 30일 변화 등)과
/// AI 분석 가이드를 카드 형태로 노출합니다. PC와 모바일용으로 각각 반응형 레이아웃을 처리합니다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goal = provider.weightGoal;
    final goalProgress = provider.goalProgress;

    void openGoal() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalScreen()),
        );

    // 포맷용 도우미: null 값을 안전하게 문자열로 변경
    String formatDouble(double? val,
        {int decimals = 1, String fallback = '-'}) {
      if (val == null) return fallback;
      return val.toStringAsFixed(decimals);
    }

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 웰컴 타이틀 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '건강 대시보드',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '오늘 하루도 건강하게 관리해 보세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                // 다크모드 빠른 토글 버튼 (헤더)
                IconButton(
                  icon: Icon(
                    provider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: provider.isDarkMode ? Colors.amber : Colors.indigo,
                  ),
                  onPressed: () {
                    provider.toggleDarkMode(!provider.isDarkMode);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 1. AI 건강 조언 카드 (눈에 잘 띄도록 프리미엄 그라데이션 박스 적용)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.psychology,
                        color: theme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 건강 리포트',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          provider.aiFeedback,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. 핵심 지표 요약 카드 그리드 (PC 2~3열, 모바일 1열 반응형 레이아웃 구현)
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                // 모바일, 태블릿, PC 해상도에 맞춰 그리드 열 수 분기
                int crossAxisCount = 2; // 모바일 기본값을 2열로 조정
                // 모바일 카드 비율. 1.15에서는 375px 폭 기준 카드 높이가 모자라
                // 하단 안내 문구가 잘렸으므로, 두 줄 문구까지 들어가도록 세로로 늘립니다.
                double aspect = 0.82;

                if (width >= 900) {
                  crossAxisCount = 3;
                  aspect = 1.5;
                } else if (width >= 600) {
                  crossAxisCount = 2;
                  aspect = 1.4;
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: aspect,
                  children: [
                    // 현재 체중 카드
                    SummaryCard(
                      title: '현재 체중',
                      value: formatDouble(provider.currentWeight),
                      unit: 'kg',
                      icon: Icons.monitor_weight_outlined,
                      iconColor: Colors.blue,
                      trailing: provider.currentBodyFat != null
                          ? Text(
                              '체지방률: ${provider.currentBodyFat}%',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500),
                            )
                          : null,
                    ),

                    // 목표 체중 카드
                    SummaryCard(
                      title: '목표 체중',
                      value: formatDouble(provider.targetWeight),
                      unit: 'kg',
                      icon: Icons.track_changes,
                      iconColor: Colors.red,
                      onTap: openGoal,
                      trailing: LayoutBuilder(
                        builder: (context, c) {
                          final remain = provider.remainingWeight;
                          if (remain == null) {
                            return const Text('목표 체중을 설정해 보세요.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey));
                          }
                          if (remain <= 0) {
                            return const Text(
                              '🎉 목표 달성 성공!',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            );
                          }
                          return Text(
                            '목표까지 ${remain.toStringAsFixed(1)} kg 남음',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),

                    // 7일 평균 체중
                    SummaryCard(
                      title: '7일 평균',
                      value: formatDouble(provider.sevenDayAverage),
                      unit: 'kg',
                      icon: Icons.functions,
                      iconColor: Colors.amber,
                      trailing: Text(
                        '최근 ${provider.records.length < 7 ? provider.records.length : 7}회 측정 기준',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),

                    // 30일 변화량
                    SummaryCard(
                      title: '30일 변화',
                      value: provider.thirtyDayChange != null
                          ? (provider.thirtyDayChange! > 0 ? '+' : '') +
                              provider.thirtyDayChange!.toStringAsFixed(1)
                          : '-',
                      unit: 'kg',
                      icon: Icons.swap_vert,
                      iconColor: Colors.purple,
                      trailing: Text(
                        provider.thirtyDayChange == null
                            ? '비교군 데이터 부족'
                            : (provider.thirtyDayChange! <= 0
                                ? '체중이 줄었습니다 👍'
                                : '체중이 늘었습니다 ⚠️'),
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.thirtyDayChange == null
                              ? Colors.grey
                              : (provider.thirtyDayChange! <= 0
                                  ? Colors.green
                                  : Colors.orange),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // BMI 카드 (키가 설정되어 있을 때만 계산됨)
                    SummaryCard(
                      title: '나의 BMI',
                      value: formatDouble(provider.bmi),
                      unit: '',
                      icon: Icons.accessibility_new,
                      iconColor: provider.bmiStatusColor,
                      trailing: Text(
                        '상태: ${provider.bmiStatus}',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.bmiStatusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // 목표 계획 진행 카드 (탭하면 계획 화면으로 이동)
                    _buildGoalProgressCard(goal, goalProgress, openGoal),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. 최근 체중 변화 추이 그래프 맛보기 카드
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.2)
                        : Colors.blueGrey.withOpacity(0.08),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '최근 체중 변화 추이',
                        style:
                            theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                      Icon(Icons.show_chart,
                          color: theme.primaryColor, size: 20),
                    ],
                  ),
                  if (goal != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                            width: 14, height: 2, color: HealthChart.planColor),
                        const SizedBox(width: 6),
                        Text(
                          '목표 계획 (전체 계획은 차트 탭에서 볼 수 있어요)',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: HealthChart(
                      records: provider.records,
                      targetWeight: provider.targetWeight,
                      goal: goal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 목표 계획의 진행률과 상태를 보여주는 요약 카드입니다.
  Widget _buildGoalProgressCard(
      WeightGoal? goal, GoalProgress? progress, VoidCallback onTap) {
    if (goal == null || progress == null) {
      return SummaryCard(
        title: '목표 진행',
        value: '-',
        unit: '',
        icon: Icons.flag_outlined,
        iconColor: Colors.teal,
        onTap: onTap,
        trailing: const Text(
          '탭해서 기간별 계획 세우기',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final style = GoalStatusStyle.of(progress.status);
    final hasRecord = progress.status != GoalStatus.noData;
    final index = progress.currentMilestoneIndex;
    return SummaryCard(
      title: '목표 진행',
      value: hasRecord ? '${(progress.progressRatio * 100).round()}' : '-',
      unit: hasRecord ? '%' : '',
      icon: Icons.flag_outlined,
      iconColor: style.color,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            style.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, color: style.color, fontWeight: FontWeight.bold),
          ),
          Text(
            '$index${goal.periodUnit.ordinal} 목표 '
            '${goal.plannedWeightFor(index).toStringAsFixed(1)}kg',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
