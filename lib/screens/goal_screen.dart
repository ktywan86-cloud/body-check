import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/health_record.dart';
import '../models/weight_goal.dart';
import '../providers/health_provider.dart';
import '../widgets/goal_status_style.dart';

/// 목표 체중 계획을 세우고, 기간별 목표를 확인·조정하는 화면입니다.
///
/// 목표 체중과 기간을 입력하면 기간별 목표가 자동으로 균등 분배되고,
/// 계획을 저장한 뒤에는 특정 기간의 목표를 직접 수정할 수 있습니다.
class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startController = TextEditingController();
  final _targetController = TextEditingController();
  final _countController = TextEditingController();
  GoalPeriodUnit _unit = GoalPeriodUnit.week;
  bool _touched = false; // 사용자가 입력을 바꿨는지 (이탈 확인용)
  bool _saving = false;

  static final _dateFormat = DateFormat('yyyy.MM.dd');
  static final _shortDateFormat = DateFormat('MM.dd');

  @override
  void initState() {
    super.initState();
    final provider = context.read<HealthProvider>();
    final saved = provider.weightGoal;
    if (saved != null) {
      _startController.text = _fmt(saved.startWeight);
      _targetController.text = _fmt(saved.targetWeight);
      _countController.text = saved.periodCount.toString();
      _unit = saved.periodUnit;
    } else {
      // 새 계획: 최근 체중을 시작 체중으로, 기존 목표 체중이 있으면 그대로 제안합니다.
      final current = provider.currentWeight;
      final target = provider.targetWeight;
      _startController.text = current != null ? _fmt(current) : '';
      _targetController.text =
          (target != null && current != null && target < current)
              ? _fmt(target)
              : '';
      _countController.text = '12';
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _targetController.dispose();
    _countController.dispose();
    super.dispose();
  }

  static String _fmt(double v) => v.toStringAsFixed(1);

  double? get _startValue => double.tryParse(_startController.text.trim());
  double? get _targetValue => double.tryParse(_targetController.text.trim());
  int? get _countValue => int.tryParse(_countController.text.trim());

  /// 저장되지 않은 계획(새 계획 또는 목표 체중·기간을 바꾼 상태)인지 확인합니다.
  bool _isDraft(WeightGoal? saved) {
    if (saved == null) return true;
    final target = _targetValue;
    return target == null ||
        (target - saved.targetWeight).abs() > 1e-9 ||
        _countValue != saved.periodCount ||
        _unit != saved.periodUnit;
  }

  /// 현재 입력값으로 만든 계획입니다. 입력이 올바르지 않으면 null입니다.
  /// 저장된 계획이 있으면 시작 지점(체중·날짜)은 그대로 유지합니다.
  WeightGoal? _draftGoal(WeightGoal? saved) {
    final start = saved?.startWeight ?? _startValue;
    final target = _targetValue;
    final count = _countValue;
    final error = WeightGoal.validateBase(
      startWeight: start,
      targetWeight: target,
      unit: _unit,
      periodCount: count,
    );
    if (error != null) return null;
    return WeightGoal(
      startWeight: start!,
      startDate: saved?.startDate ?? DateTime.now(),
      targetWeight: target!,
      periodUnit: _unit,
      periodCount: count!,
    );
  }

  void _markTouched() => setState(() => _touched = true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HealthProvider>();
    final saved = provider.weightGoal;
    final isDraft = _isDraft(saved);
    final goal = isDraft ? _draftGoal(saved) : saved;
    final progress = isDraft ? null : provider.goalProgress;
    final hasUnsavedInput = _touched && isDraft;

    return PopScope(
      canPop: !hasUnsavedInput,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await _confirm(
          title: '저장하지 않고 나갈까요?',
          message: '입력한 계획이 아직 저장되지 않았습니다.',
          confirmLabel: '나가기',
          destructive: true,
        );
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('목표 체중 계획',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSetupCard(theme, provider, saved),
                    const SizedBox(height: 24),
                    if (goal != null) ...[
                      _buildSummaryCard(theme, goal, saved, isDraft, progress),
                      const SizedBox(height: 24),
                      _buildMilestoneCard(theme, provider, goal, !isDraft),
                      const SizedBox(height: 24),
                    ],
                    _buildActions(theme, provider, saved, isDraft),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. 계획 설정 ---

  Widget _buildSetupCard(
      ThemeData theme, HealthProvider provider, WeightGoal? saved) {
    final records = provider.records;
    final HealthRecord? latest = records.isNotEmpty ? records.first : null;
    final draft = _draftGoal(saved);
    final hintStyle = TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
        height: 1.4);

    return _card(
      theme,
      icon: Icons.flag_outlined,
      accent: theme.primaryColor,
      title: '계획 설정',
      description: '목표 체중과 기간을 정하면 기간별 목표가 자동으로 나뉩니다.',
      children: [
        _label('시작 체중'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _startController,
          readOnly: saved != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _decoration('예: 80.0', 'kg', theme),
          onChanged: (_) => _markTouched(),
          validator: (val) {
            if (saved != null) return null;
            final v = double.tryParse(val?.trim() ?? '');
            if (v == null) return '시작 체중을 입력해 주세요.';
            if (v < WeightGoal.minWeight || v > WeightGoal.maxWeight) {
              return '20~300kg 사이로 입력해 주세요.';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          saved != null
              ? '시작일 ${_dateFormat.format(saved.startDate)}에 고정된 값입니다. 바꾸려면 아래 "오늘 기준으로 다시 시작"을 누르세요.'
              : (latest != null
                  ? '최근 기록 ${_dateFormat.format(latest.date)} · ${_fmt(latest.weight)}kg. 오늘부터 계획이 시작됩니다.'
                  : '아직 체중 기록이 없어요. 현재 체중을 직접 입력해 주세요.'),
          style: hintStyle,
        ),
        const SizedBox(height: 18),
        _label('목표 체중'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _targetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _decoration('예: 72.0', 'kg', theme),
          onChanged: (_) => _markTouched(),
          validator: (val) {
            final v = double.tryParse(val?.trim() ?? '');
            if (v == null) return '목표 체중을 입력해 주세요.';
            if (v < WeightGoal.minWeight || v > WeightGoal.maxWeight) {
              return '20~300kg 사이로 입력해 주세요.';
            }
            final start = saved?.startWeight ?? _startValue;
            if (start != null && v > start - 0.1 + 1e-9) {
              return '시작 체중보다 낮아야 합니다. (감량 계획만 지원)';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        _label('목표 기간'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: _decoration('예: 12', _unit.label, theme),
                onChanged: (_) => _markTouched(),
                validator: (val) {
                  final v = int.tryParse(val?.trim() ?? '');
                  if (v == null || v < 1) return '1 이상의 정수를 입력해 주세요.';
                  final max = _unit == GoalPeriodUnit.week
                      ? WeightGoal.maxWeeks
                      : WeightGoal.maxMonths;
                  if (v > max) return '최대 $max${_unit.label}까지 가능합니다.';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SegmentedButton<GoalPeriodUnit>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: GoalPeriodUnit.week, label: Text('주')),
                  ButtonSegment(value: GoalPeriodUnit.month, label: Text('개월')),
                ],
                selected: {_unit},
                onSelectionChanged: (selection) {
                  setState(() {
                    _unit = selection.first;
                    _touched = true;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '기간 단위는 기간별 목표를 나누는 단위로도 쓰입니다.'
          '${draft != null ? ' 목표일: ${_dateFormat.format(draft.targetDate)}' : ''}',
          style: hintStyle,
        ),
      ],
    );
  }

  // --- 2. 계획 요약 ---

  Widget _buildSummaryCard(ThemeData theme, WeightGoal goal, WeightGoal? saved,
      bool isDraft, GoalProgress? progress) {
    final aggressive = goal.aggressiveSegments();
    final perLabel = goal.periodUnit == GoalPeriodUnit.week ? '주당 평균' : '월 평균';

    return _card(
      theme,
      icon: Icons.insights,
      accent: const Color(0xFF8B5CF6),
      title: isDraft ? '계획 미리보기' : '계획 요약',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(theme, '총 감량', '${_fmt(goal.totalLoss)} kg'),
            _stat(theme, '기간',
                '${goal.periodCount}${goal.periodUnit.label} · ${goal.totalDays}일'),
            _stat(theme, perLabel,
                '${goal.averageLossPerPeriod.toStringAsFixed(2)} kg'),
            _stat(theme, '목표일', _dateFormat.format(goal.targetDate)),
          ],
        ),
        if (aggressive.isNotEmpty) ...[
          const SizedBox(height: 16),
          _banner(
            theme,
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
            text:
                '${aggressive.length}개 구간이 권장 감량 속도(주 ${goal.safeKgPerWeek.toStringAsFixed(1)}kg)를 넘습니다. '
                '급격한 감량은 근손실과 요요로 이어지기 쉬워요. 기간을 늘리는 것을 고려해 보세요.\n'
                '※ 일반적인 기준에 따른 안내이며 의학적 판단이 아닙니다.',
          ),
        ],
        if (isDraft && saved != null && saved.hasOverrides) ...[
          const SizedBox(height: 16),
          _banner(
            theme,
            color: theme.primaryColor,
            icon: Icons.info_outline,
            text:
                '목표 체중이나 기간을 바꿔 저장하면, 직접 수정한 ${saved.overrides.length}개 기간이 자동 계산으로 돌아갑니다.',
          ),
        ],
        if (progress != null) ...[
          const SizedBox(height: 20),
          _buildProgress(theme, progress),
        ],
      ],
    );
  }

  Widget _buildProgress(ThemeData theme, GoalProgress progress) {
    final style = GoalStatusStyle.of(progress.status);
    final diff = GoalStatusStyle.diffText(progress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(style.icon, color: style.color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(style.label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: style.color)),
            ),
            Text('${(progress.progressRatio * 100).round()}%',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.progressRatio,
            minHeight: 8,
            color: style.color,
            backgroundColor: theme.dividerColor.withOpacity(0.3),
          ),
        ),
        if (progress.latestDate != null) ...[
          const SizedBox(height: 8),
          Text(
            '${_dateFormat.format(progress.latestDate!)} 기록 ${_fmt(progress.latestWeight!)}kg · '
            '그날 계획 ${_fmt(progress.plannedAtLatest!)}kg'
            '${diff != null ? ' ($diff)' : ''}',
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                height: 1.4),
          ),
        ],
      ],
    );
  }

  // --- 3. 기간별 목표 ---

  Widget _buildMilestoneCard(ThemeData theme, HealthProvider provider,
      WeightGoal goal, bool editable) {
    final today = WeightGoal.dateOnly(DateTime.now());
    final aggressive = goal.aggressiveSegments().toSet();
    final currentIndex = goal.currentMilestoneIndex(today);
    final records = provider.records;

    final rows = <Widget>[];
    for (final m in goal.milestones().skip(1)) {
      // 각 기간은 (이전 기간 종료일, 이번 종료일] 구간이라 첫날은 종료일 다음 날입니다.
      // 단, 첫 기간은 시작일 당일부터 포함합니다. (WeightGoal.actualFor와 같은 규칙)
      final periodStart = goal.milestoneDate(m.index - 1);
      final isFuture = m.index == 1
          ? periodStart.isAfter(today)
          : !periodStart.isBefore(today);
      final isCurrent = editable &&
          m.index == currentIndex &&
          !today.isAfter(goal.targetDate);
      final actual = isFuture ? null : goal.actualFor(m.index, records);

      rows.add(_milestoneRow(
        theme,
        goal: goal,
        milestone: m,
        actual: actual,
        isFuture: isFuture,
        isCurrent: isCurrent,
        isAggressive: aggressive.contains(m.index),
        editable: editable,
        provider: provider,
      ));
    }

    return _card(
      theme,
      icon: Icons.format_list_numbered,
      accent: const Color(0xFF10B981),
      title: '기간별 목표',
      description: editable
          ? '연필 아이콘으로 특정 기간의 목표를 직접 조정할 수 있어요. 그 이후 기간은 남은 감량을 자동으로 다시 나눕니다.'
          : '계획을 저장하면 기간별 목표를 직접 조정할 수 있어요.',
      children: rows,
    );
  }

  Widget _milestoneRow(
    ThemeData theme, {
    required WeightGoal goal,
    required GoalMilestone milestone,
    required HealthRecord? actual,
    required bool isFuture,
    required bool isCurrent,
    required bool isAggressive,
    required bool editable,
    required HealthProvider provider,
  }) {
    final isLast = milestone.index == goal.periodCount;
    final muted = theme.colorScheme.onSurface.withOpacity(0.5);

    // 실제 기록 표시: 미래 기간은 '-', 지난 기간인데 기록이 없으면 '기록 없음'
    Widget actualWidget;
    if (isFuture) {
      actualWidget = Text('-', style: TextStyle(fontSize: 12, color: muted));
    } else if (actual == null) {
      actualWidget =
          Text('기록 없음', style: TextStyle(fontSize: 11, color: muted));
    } else {
      final diff = actual.weight - goal.plannedWeightAt(actual.date);
      final ok = diff < WeightGoal.onTrackTolerance;
      actualWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.schedule,
              size: 13, color: ok ? const Color(0xFF10B981) : Colors.orange),
          const SizedBox(width: 3),
          Text(_fmt(actual.weight),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? theme.primaryColor.withOpacity(0.08) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 기간 순번과 종료일
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLast
                      ? '목표'
                      : '${milestone.index}${goal.periodUnit.ordinal}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? theme.primaryColor : null),
                ),
                Text(
                  isCurrent ? '진행 중' : _shortDateFormat.format(milestone.date),
                  style: TextStyle(
                      fontSize: 10,
                      color: isCurrent ? theme.primaryColor : muted),
                ),
              ],
            ),
          ),
          // 계획 체중
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '${_fmt(milestone.plannedWeight)} kg',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: milestone.isOverridden || isLast
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (milestone.isOverridden) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('수동',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981))),
                  ),
                ],
                if (isAggressive) ...[
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: '권장 감량 속도를 넘는 구간',
                    child: Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
          // 실제 기록
          SizedBox(
              width: 60,
              child:
                  Align(alignment: Alignment.centerRight, child: actualWidget)),
          // 수정 / 되돌리기
          if (editable)
            SizedBox(
              // Material 3 아이콘 버튼은 compact 밀도에서도 40px이라 그만큼 확보합니다.
              width: milestone.isOverridden ? 80 : 40,
              child: isLast
                  ? const SizedBox()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 되돌리기 버튼이 앞에 끼어들어도 수정 버튼이 같은 요소로
                        // 유지되도록 키를 줍니다. (툴팁이 떠 있는 상태에서 버튼이
                        // 뒤바뀌면 프레임워크 오류가 날 수 있음)
                        if (milestone.isOverridden)
                          _iconButton(
                            key: const ValueKey('undo'),
                            icon: Icons.undo,
                            tooltip: '자동 계산으로 되돌리기',
                            onPressed: () => _revertMilestone(
                                provider, goal, milestone.index),
                          ),
                        _iconButton(
                          key: const ValueKey('edit'),
                          icon: Icons.edit_outlined,
                          tooltip: '이 기간 목표 수정',
                          onPressed: () =>
                              _editMilestone(provider, goal, milestone.index),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _iconButton(
      {required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    return IconButton(
      key: key,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onPressed,
    );
  }

  Future<void> _editMilestone(
      HealthProvider provider, WeightGoal goal, int index) async {
    final label = '$index${goal.periodUnit.ordinal}';
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _OverrideDialog(goal: goal, index: index, label: label),
    );
    if (result == null) return;

    final error =
        await provider.updateWeightGoal(goal.withOverride(index, result));
    if (!mounted) return;
    _snack(error ?? '$label 목표를 ${_fmt(result)}kg으로 바꿨습니다.',
        error == null ? Colors.green : Colors.redAccent);
  }

  Future<void> _revertMilestone(
      HealthProvider provider, WeightGoal goal, int index) async {
    final after = goal.overridesAfter(index);
    if (after > 0) {
      final ok = await _confirm(
        title: '자동 계산으로 되돌리기',
        message: '이 기간과 함께 이후 직접 수정한 $after개 기간도 자동 계산으로 돌아갑니다.',
        confirmLabel: '되돌리기',
      );
      if (!ok) return;
    }
    final error = await provider.updateWeightGoal(goal.withoutOverride(index));
    if (!mounted) return;
    if (error != null) _snack(error, Colors.redAccent);
  }

  // --- 4. 저장 / 다시 시작 / 삭제 ---

  Widget _buildActions(ThemeData theme, HealthProvider provider,
      WeightGoal? saved, bool isDraft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDraft)
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _saving ? null : () => _save(provider, saved),
              child: Text(saved == null ? '계획 저장' : '변경 사항 저장',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        if (saved != null) ...[
          if (isDraft) const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _restart(provider, saved),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('오늘 기준으로 다시 시작',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _delete(provider, saved),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('계획 삭제',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _save(HealthProvider provider, WeightGoal? saved) async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _draftGoal(saved);
    if (draft == null) return;

    if (saved != null && saved.hasOverrides) {
      final ok = await _confirm(
        title: '직접 수정한 목표 초기화',
        message:
            '목표 체중이나 기간이 바뀌어, 직접 수정한 ${saved.overrides.length}개 기간이 자동 계산으로 돌아갑니다. 계속할까요?',
        confirmLabel: '저장',
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    final error = await provider.updateWeightGoal(draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) _touched = false;
    });
    _snack(error ?? '목표 계획이 저장되었습니다.',
        error == null ? Colors.green : Colors.redAccent);
  }

  Future<void> _restart(HealthProvider provider, WeightGoal saved) async {
    final current = provider.currentWeight;
    if (current == null) {
      _snack('체중 기록이 없어 다시 시작할 수 없습니다.', Colors.redAccent);
      return;
    }
    final ok = await _confirm(
      title: '오늘 기준으로 다시 시작',
      message: '시작일을 오늘로, 시작 체중을 최근 기록(${_fmt(current)}kg)으로 다시 잡습니다.\n'
          '목표 체중과 기간은 그대로이고, 직접 수정한 기간 목표는 초기화됩니다.',
      confirmLabel: '다시 시작',
    );
    if (!ok) return;

    final next = saved.copyWith(
      startWeight: current,
      startDate: DateTime.now(),
      clearOverrides: true,
    );
    final error = await provider.updateWeightGoal(next);
    if (!mounted) return;
    if (error == null) {
      setState(() => _startController.text = _fmt(current));
      _snack('오늘부터 계획을 다시 시작합니다.', Colors.green);
    } else {
      _snack('다시 시작할 수 없습니다: $error', Colors.redAccent);
    }
  }

  Future<void> _delete(HealthProvider provider, WeightGoal saved) async {
    final ok = await _confirm(
      title: '계획 삭제',
      message:
          '목표 계획과 기간별 목표가 삭제됩니다. 목표 체중(${_fmt(saved.targetWeight)}kg)은 그대로 남습니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok) return;
    await provider.clearWeightGoal();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // --- 공통 위젯 ---

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: destructive ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 설정 화면과 같은 형태의 카드입니다.
  Widget _card(
    ThemeData theme, {
    required IconData icon,
    required Color accent,
    required String title,
    String? description,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

  Widget _stat(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.55))),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _banner(ThemeData theme,
      {required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.8))),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint, String suffix, ThemeData theme) =>
      _goalInputDecoration(hint, suffix, theme);
}

/// 기간별 목표 하나를 직접 수정하는 다이얼로그입니다.
///
/// 입력 컨트롤러를 이 위젯이 직접 소유하고 dispose합니다. 호출하는 쪽에서
/// showDialog가 끝나자마자 dispose하면, 다이얼로그가 닫히는 애니메이션 동안
/// 입력칸이 이미 폐기된 컨트롤러를 참조하게 되어 오류가 납니다.
class _OverrideDialog extends StatefulWidget {
  final WeightGoal goal;
  final int index;
  final String label;

  const _OverrideDialog(
      {required this.goal, required this.index, required this.label});

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late final ({double min, double max}) _range;
  late final double _shownMin;
  late final double _shownMax;

  @override
  void initState() {
    super.initState();
    _range = widget.goal.overrideRange(widget.index)!;
    // 화면에는 실제로 입력 가능한 소수점 한 자리 값으로 범위를 안내합니다.
    _shownMin = (_range.min * 10).ceil() / 10;
    _shownMax = (_range.max * 10).floor() / 10;
    _controller = TextEditingController(
        text: widget.goal.plannedWeightFor(widget.index).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _rangeText =>
      '${_shownMin.toStringAsFixed(1)} ~ ${_shownMax.toStringAsFixed(1)} kg';

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(double.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final after = widget.goal.overridesAfter(widget.index);
    final date = DateFormat('yyyy.MM.dd')
        .format(widget.goal.milestoneDate(widget.index));

    return AlertDialog(
      title: Text('${widget.label} 목표 수정',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$date까지 도달할 체중입니다.\n입력 가능 범위: $_rangeText',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _goalInputDecoration('체중', 'kg', theme),
              onFieldSubmitted: (_) => _apply(),
              validator: (val) {
                final v = double.tryParse(val?.trim() ?? '');
                if (v == null) return '체중을 입력해 주세요.';
                if (v < _range.min - 1e-9 || v > _range.max + 1e-9) {
                  return '$_rangeText 사이로 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Text(
              after > 0
                  ? '이후 직접 수정한 $after개 기간은 자동 계산으로 돌아가고, 남은 감량을 다시 나눕니다.'
                  : '이후 기간은 남은 감량을 자동으로 다시 나눕니다.',
              style: TextStyle(
                  fontSize: 11,
                  color: after > 0
                      ? Colors.orange
                      : theme.colorScheme.onSurface.withOpacity(0.55),
                  height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _apply,
          child: const Text('적용',
              style:
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// 설정 화면의 입력창 스타일과 같습니다.
InputDecoration _goalInputDecoration(
    String hint, String suffix, ThemeData theme) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
        fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.35)),
    suffixText: suffix,
    suffixStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface.withOpacity(0.5)),
    filled: true,
    fillColor: theme.colorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}
