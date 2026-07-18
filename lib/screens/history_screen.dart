import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';
import '../providers/health_provider.dart';
import 'input_screen.dart';

/// 저장된 전체 기록 목록을 날짜 역순으로 리스팅하고,
/// 각 기록의 조회, 수정, 삭제 작업을 지원하는 화면입니다.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final records = provider.records;

    // 만약 데이터가 없을 경우 표시할 엠티 뷰
    if (records.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history,
                  size: 64,
                  color: theme.colorScheme.onSurface.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                '저장된 건강 기록이 없습니다.',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ),
              const SizedBox(height: 6),
              const Text('새로운 기록을 먼저 입력해 보세요!',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 스크롤 상단 헤더 영역
          Padding(
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기록 리스트',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '총 ${records.length}개의 건강 기록이 안전하게 저장되어 있습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // 리스트 뷰 영역
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return _buildRecordCard(context, record, theme, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 각 날짜별 건강 데이터를 요약 표시하는 카드 아이템 빌더입니다.
  Widget _buildRecordCard(
      BuildContext context, HealthRecord record, ThemeData theme, bool isDark) {
    // 식단 등급별 뱃지 컬러 및 라벨
    Color mealColor;
    String mealLabel;
    switch (record.mealStatus) {
      case 'good':
        mealColor = Colors.green;
        mealLabel = '식단: 좋음';
        break;
      case 'bad':
        mealColor = Colors.red;
        mealLabel = '식단: 나쁨';
        break;
      default:
        mealColor = Colors.orange;
        mealLabel = '식단: 보통';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : Colors.blueGrey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 헤더: 날짜 & 식단 뱃지 & 액션 버튼 (수정, 삭제)
          Row(
            children: [
              Text(
                DateFormat('yyyy년 MM월 dd일 (E)').format(record.date),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              // 식단 뱃지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mealColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mealLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: mealColor),
                ),
              ),
              const Spacer(),
              // 수정 버튼 (손으로 탭하기 편한 크기의 IconButton)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                visualDensity: VisualDensity.compact,
                color: theme.primaryColor,
                onPressed: () {
                  // 수정 화면(InputScreen)으로 이동하며 대상 데이터를 전달합니다.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => InputScreen(recordToEdit: record),
                    ),
                  );
                },
              ),
              // 삭제 버튼
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                visualDensity: VisualDensity.compact,
                color: Colors.redAccent,
                onPressed: () {
                  _showDeleteConfirmDialog(context, record);
                },
              ),
            ],
          ),
          const Divider(height: 16, thickness: 0.5),

          // 2. 바디 지표 및 사진 영역
          if (record.photoBase64 != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetricItem('체중', '${record.weight}kg', theme),
                          _buildMetricItem(
                            '체지방률',
                            record.bodyFat != null ? '${record.bodyFat}%' : '-',
                            theme,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetricItem(
                            '허리둘레',
                            record.waist != null ? '${record.waist}cm' : '-',
                            theme,
                            color: Colors.blueGrey,
                          ),
                          _buildMetricItem(
                            '수면 시간',
                            record.sleepHours != null
                                ? '${record.sleepHours}시간'
                                : '-',
                            theme,
                            color: Colors.indigo,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showPhotoLightbox(context, record, theme),
                  child: Hero(
                    tag: 'photo_${record.id}',
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _decodeBase64(record.photoBase64!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricItem('체중', '${record.weight}kg', theme),
                _buildMetricItem(
                  '체지방률',
                  record.bodyFat != null ? '${record.bodyFat}%' : '-',
                  theme,
                  color: Colors.teal,
                ),
                _buildMetricItem(
                  '허리둘레',
                  record.waist != null ? '${record.waist}cm' : '-',
                  theme,
                  color: Colors.blueGrey,
                ),
                _buildMetricItem(
                  '수면 시간',
                  record.sleepHours != null ? '${record.sleepHours}시간' : '-',
                  theme,
                  color: Colors.indigo,
                ),
              ],
            ),

          // 3. 부가 정보: 운동 내용 노출 (있는 경우만)
          if (record.exercise != null) const SizedBox(height: 12),
          if (record.exercise != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_run,
                      size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.exercise!,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // 4. 부가 정보: 메모 노출 (있는 경우만)
          if (record.memo != null) const SizedBox(height: 8),
          if (record.memo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.memo!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 보조 지표를 라벨 및 수치 쌍으로 예쁘게 렌더링합니다.
  Widget _buildMetricItem(String label, String value, ThemeData theme,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.4)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// 기록을 삭제하기 전 물어보는 모달 다이얼로그를 띄웁니다.
  void _showDeleteConfirmDialog(BuildContext context, HealthRecord record) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('기록 삭제',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            '${DateFormat('yyyy년 MM월 dd일').format(record.date)}의 기록을 정말로 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: const TextStyle(height: 1.4, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                context.read<HealthProvider>().deleteRecord(record.id);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('기록이 성공적으로 삭제되었습니다.',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('삭제',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
                    tag: 'photo_${record.id}',
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
