import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_record.dart';

/// 로컬 규칙 또는 로컬 Ollama 분석을 제공하는 서비스입니다.
abstract class AnalysisService {
  /// 최근 체중 변화와 식단, 수면 기록을 분석하여 AI 조언 메시지를 생성합니다.
  Future<String> generateFeedback({
    required List<HealthRecord> records,
    required double? height,
    required double? targetWeight,
    String? aiEngine,
    String? ollamaBaseUrl,
    String? ollamaModel,
  });
}

/// AI 분석 서비스 구현체입니다.
/// 설정된 AI 엔진에 따라 로컬 규칙 또는 Ollama 로컬 API를 호출합니다.
class MockAnalysisService implements AnalysisService {
  @override
  Future<String> generateFeedback({
    required List<HealthRecord> records,
    required double? height,
    required double? targetWeight,
    String? aiEngine,
    String? ollamaBaseUrl,
    String? ollamaModel,
  }) async {
    // 기록이 부족한 경우
    if (records.isEmpty) {
      return '충분한 데이터가 쌓이면 AI 건강 분석 리포트를 제공해 드립니다. 체중 기록을 남겨보세요!';
    }

    final resolvedEngine = aiEngine ?? 'ollama';

    // 1. 로컬 룰 엔진
    if (resolvedEngine == 'local') {
      return _getMockFeedback(records, height, targetWeight);
    }

    // 2. Ollama (로컬 AI)
    if (resolvedEngine == 'ollama') {
      final model =
          (ollamaModel == null || ollamaModel.isEmpty) ? 'llama3' : ollamaModel;
      String baseUrl = (ollamaBaseUrl == null || ollamaBaseUrl.isEmpty)
          ? 'http://localhost:11434'
          : ollamaBaseUrl;
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'http://$baseUrl';
      }
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      try {
        final url = Uri.parse('$baseUrl/api/chat');
        final prompt = _buildPrompt(records, height, targetWeight);

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'model': model,
                'messages': [
                  {'role': 'user', 'content': prompt}
                ],
                'stream': false,
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final resData = json.decode(utf8.decode(response.bodyBytes));
          final String text = resData['message']['content'];
          return text.trim();
        } else {
          print('Ollama API Error: ${response.statusCode} - ${response.body}');
          final mockAdvice = _getMockFeedback(records, height, targetWeight);
          return '🤖 [Ollama 응답 에러 - 기본 조언 제공]\n선택한 모델명($model)이 정상 작동하는지 확인해 주세요.\n\n$mockAdvice';
        }
      } catch (e) {
        print('Ollama connection error: $e');
        final mockAdvice = _getMockFeedback(records, height, targetWeight);
        return '🤖 [Ollama 연결 실패 - 기본 조언 제공]\nOllama 서버가 실행 중인지, 현재 앱의 정확한 출처(origin)가 OLLAMA_ORIGINS에 허용되어 있는지 확인해 주세요.\n\n$mockAdvice';
      }
    }

    return _getMockFeedback(records, height, targetWeight);
  }

  /// 프롬프트 생성 빌더
  String _buildPrompt(
      List<HealthRecord> records, double? height, double? targetWeight) {
    final latest = records.first;
    final latestWeight = latest.weight;
    final latestBodyFat =
        latest.bodyFat != null ? '${latest.bodyFat}%' : '기록 없음';
    final latestWaist = latest.waist != null ? '${latest.waist}cm' : '기록 없음';
    final latestSleep =
        latest.sleepHours != null ? '${latest.sleepHours}시간' : '기록 없음';
    final latestMeal = latest.mealStatus == 'good'
        ? '좋음'
        : (latest.mealStatus == 'bad' ? '나쁨' : '보통');
    final latestExercise = latest.exercise ?? '기록 없음';

    final recordsSummary = records.take(5).map((r) {
      final dateStr = '${r.date.month}월 ${r.date.day}일';
      return '- $dateStr: 체중 ${r.weight}kg, 식단 ${r.mealStatus == 'good' ? '좋음' : (r.mealStatus == 'bad' ? '나쁨' : '보통')}, 수면 ${r.sleepHours ?? '-'}시간, 운동: ${r.exercise ?? '-'}';
    }).join('\n');

    return '''
당신은 친절하고 전문적인 퍼스널 건강 및 다이어트 코치입니다. 다음은 사용자의 최근 건강 정보입니다:
- 신장: ${height ?? '설정 안 됨'} cm
- 목표 체중: ${targetWeight ?? '설정 안 됨'} kg
- 오늘 기록: 체중 ${latestWeight}kg, 체지방률 $latestBodyFat, 허리둘레 $latestWaist, 수면 $latestSleep, 식단 상태 $latestMeal, 운동 $latestExercise

최근 5회 기록 요약:
$recordsSummary

위 데이터를 분석하여, 사용자의 체중 흐름에 대한 따뜻한 코칭 피드백과 함께 식단/운동/수면에 대한 구체적이고 실천 가능한 조언을 제공해 주세요.
반드시 한국어로 작성하고, 분량은 3~4문장(공백 포함 200자 내외)으로 작성해 주세요. 친근하고 다정한 어조(~해요, ~보세요)를 사용해 주세요.
''';
  }

  /// 로컬 기본 피드백 룰엔진
  String _getMockFeedback(
      List<HealthRecord> records, double? height, double? targetWeight) {
    final latest = records.first;
    final buffer = StringBuffer();
    buffer.write('현재 체중은 ${latest.weight}kg입니다. ');

    if (targetWeight != null) {
      final diff = latest.weight - targetWeight;
      if (diff > 0) {
        buffer.write('목표 체중까지 약 ${diff.toStringAsFixed(1)}kg 남았습니다. 힘내세요! ');
      } else {
        buffer.write('축하합니다! 목표 체중을 이미 달성하셨습니다. 현재 상태를 잘 유지해보세요! ');
      }
    }

    if (latest.mealStatus == 'bad') {
      buffer.write('최근 식단 점수가 좋지 않습니다. 탄수화물 비율을 줄이고 단백질 섭취를 늘려보세요. ');
    } else if (latest.mealStatus == 'good') {
      buffer.write('식단을 훌륭하게 관리하고 계시네요! 꾸준히 단백질과 유기농 채소를 포함한 식단을 유지해보세요. ');
    }

    if (latest.sleepHours != null && latest.sleepHours! < 6) {
      buffer.write(
          '수면 시간이 ${latest.sleepHours}시간으로 다소 부족합니다. 면역력과 회복을 위해 최소 7시간 이상 취침하는 것을 권장합니다.');
    }

    return buffer.toString();
  }
}
