import 'package:flutter/material.dart';

/// 대시보드의 주요 건강 지표(체중, BMI, 변화량 등)를 아름답게 시각화해주는 카드 위젯입니다.
/// 모바일 터치 편의성을 고려해 눌렀을 때 크기가 살짝 반응하는 애니메이션 효과가 들어있습니다.
class SummaryCard extends StatefulWidget {
  final String title; // 카드 제목 (예: '현재 체중')
  final String value; // 표시할 수치 (예: '72.5')
  final String unit; // 수치의 단위 (예: 'kg')
  final IconData icon; // 카드에 들어갈 아이콘
  final Color iconColor; // 아이콘의 테마 색상
  final Widget? trailing; // 하단에 추가될 보조 텍스트 또는 뱃지 위젯 (선택)
  final VoidCallback? onTap; // 카드를 눌렀을 때 동작 (선택)

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard>
    with SingleTickerProviderStateMixin {
  // 터치 시 크기가 변하는 애니메이션을 위한 컨트롤러
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _animController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _animController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20), // 둥글고 현대적인 카드 모서리
            boxShadow: [
              // 다크모드에서는 그림자를 흐리게 하고, 라이트모드에서는 부드럽게 세팅
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.blueGrey.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // 주요 수치를 큼직하고 굵게 표시
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.unit,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              if (widget.trailing != null) const SizedBox(height: 12),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
