import 'package:flutter/material.dart';
import '../models/weight_goal.dart';

/// 목표 진행 상태별 표시 문구, 색상, 아이콘입니다.
/// 홈 대시보드와 목표 계획 화면이 같은 표현을 쓰도록 한곳에 모아 둡니다.
class GoalStatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const GoalStatusStyle._(this.label, this.color, this.icon);

  static GoalStatusStyle of(GoalStatus status) {
    switch (status) {
      case GoalStatus.noData:
        return const GoalStatusStyle._(
            '계획 시작 후 기록이 필요해요', Colors.grey, Icons.edit_note);
      case GoalStatus.ahead:
        return const GoalStatusStyle._(
            '계획보다 앞서가는 중', Color(0xFF3B82F6), Icons.trending_down);
      case GoalStatus.onTrack:
        return const GoalStatusStyle._(
            '계획대로 진행 중', Color(0xFF10B981), Icons.check_circle);
      case GoalStatus.behind:
        return const GoalStatusStyle._(
            '계획보다 조금 뒤처짐', Colors.orange, Icons.schedule);
      case GoalStatus.achieved:
        return const GoalStatusStyle._(
            '목표 달성!', Color(0xFFF59E0B), Icons.emoji_events);
      case GoalStatus.ended:
        return const GoalStatusStyle._(
            '목표 기간 종료', Colors.redAccent, Icons.flag);
    }
  }

  /// 계획 대비 차이를 한 줄로 설명합니다. 예: "계획보다 0.4kg 무거움"
  static String? diffText(GoalProgress progress) {
    final diff = progress.diffFromPlan;
    if (diff == null) return null;
    if (diff.abs() < 0.05) return '계획과 같음';
    final amount = diff.abs().toStringAsFixed(1);
    return diff > 0 ? '계획보다 ${amount}kg 무거움' : '계획보다 ${amount}kg 가벼움';
  }
}
