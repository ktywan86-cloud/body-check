import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/health_provider.dart';

/// 앱의 설정을 조정하는 화면입니다.
/// 키와 목표 체중을 입력하여 BMI를 계산하고, 다크 모드를 설정할 수 있습니다.
/// 모든 저장 데이터가 디바이스 내부에 로컬로만 저장된다는 보안 수칙 안내도 제공합니다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  final _ollamaBaseUrlController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  String _selectedAiEngine = 'ollama';
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<HealthProvider>();
    _heightController.text = provider.height?.toString() ?? '';
    _targetWeightController.text = provider.targetWeight?.toString() ?? '';

    _ollamaBaseUrlController.text = provider.ollamaBaseUrl;
    _ollamaModelController.text = provider.ollamaModel;
    _selectedAiEngine = provider.aiEngine;
  }

  @override
  void dispose() {
    _heightController.dispose();
    _targetWeightController.dispose();
    _ollamaBaseUrlController.dispose();
    _ollamaModelController.dispose();
    super.dispose();
  }

  Future<void> _testOllamaConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    String baseUrl = _ollamaBaseUrlController.text.trim();
    final model = _ollamaModelController.text.trim();

    if (baseUrl.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소와 모델명을 먼저 입력해 주세요.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isTestingConnection = false;
      });
      return;
    }

    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    try {
      final url = Uri.parse('$baseUrl/api/tags');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final modelsList = data['models'] as List?;
        bool modelFound = false;

        if (modelsList != null) {
          for (var m in modelsList) {
            final name = m['name'] as String?;
            if (name != null && (name == model || name.startsWith('$model:'))) {
              modelFound = true;
              break;
            }
          }
        }

        if (!mounted) return;

        if (modelFound) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('연결 성공', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                  'Ollama 서버에 성공적으로 연결되었으며, 지정하신 모델($model)이 설치되어 있음을 확인했습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('확인',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('서버 연결 성공 (모델 없음)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                  'Ollama 서버에는 연결되었으나, 지정하신 모델($model)을 찾을 수 없습니다.\n서버에 설치된 모델이 맞는지 확인해 주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('확인',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('연결 실패', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Ollama 서버에 연결할 수 없습니다.\n\n[의심되는 원인]\n1. 로컬에 Ollama가 실행 중인지 확인하세요.\n2. 현재 앱의 정확한 출처(origin)가 OLLAMA_ORIGINS에 허용되어 있는지 확인하세요.\n\n에러 내용: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Widget _buildEngineSelector(String engineType, String title, IconData icon,
      String subtitle, HealthProvider provider) {
    final isSelected = _selectedAiEngine == engineType;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedAiEngine = engineType;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.12)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.primaryColor
                  : theme.dividerColor.withOpacity(0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.primaryColor
                    : theme.colorScheme.onSurface.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 키와 목표 체중 값을 검증하고 저장합니다.
  void _saveSettings() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<HealthProvider>();
    final double height = double.parse(_heightController.text);
    final double targetWeight = double.parse(_targetWeightController.text);

    provider.updateHeight(height);
    provider.updateTargetWeight(targetWeight);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('설정이 정상적으로 저장되었습니다.',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    // 키보드 닫기
    FocusScope.of(context).unfocus();
  }

  /// 현재 로그인한 사용자의 비밀번호 찾기용 보안 질문을 설정하거나 변경합니다.
  void _showRecoveryQuestionDialog() {
    final provider = context.read<HealthProvider>();
    final username = provider.currentUserId;
    if (username == null) return;

    final answerController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // 기존에 저장된 질문이 프리셋 목록에 있을 때만 초기 선택값으로 사용합니다.
    String? selected = provider.getSecurityQuestion(username);
    if (!HealthProvider.securityQuestions.contains(selected)) {
      selected = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('비밀번호 찾기 질문 설정',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '비밀번호를 잊었을 때 이 질문의 답변만으로 재설정할 수 있습니다.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '보안 질문',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: HealthProvider.securityQuestions
                      .map((q) => DropdownMenuItem(
                            value: q,
                            child: Text(q, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selected = val;
                    });
                  },
                  validator: (val) {
                    if (val == null) return '보안 질문을 선택해 주세요.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: answerController,
                  decoration: const InputDecoration(
                    labelText: '답변',
                    hintText: '대소문자와 공백은 구분하지 않습니다',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return '답변을 입력해 주세요.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                await provider.setRecovery(
                    username, selected!, answerController.text);

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('보안 질문이 저장되었습니다. 이제 비밀번호를 잊어도 재설정할 수 있습니다.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('저장',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(String username) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$username 비밀번호 강제 변경',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '새로운 비밀번호/PIN 번호를 입력하세요',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return '비밀번호를 입력해 주세요.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              context
                  .read<HealthProvider>()
                  .adminResetUserPassword(username, controller.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$username 유저의 비밀번호가 성공적으로 변경되었습니다.'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('변경',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('사용자 프로필 삭제 경고',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '정말로 사용자 [$username] 프로필을 삭제하시겠습니까?\n\n'
          '⚠️ 주의: 이 사용자의 모든 건강 기록 리스트와 설정 데이터가 기기에서 일괄 소멸하며, 절대 복구할 수 없습니다.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<HealthProvider>().adminDeleteUser(username);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$username 사용자 프로필 및 모든 관련 데이터가 삭제되었습니다.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('삭제 진행',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신규 프로필 생성 (User)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  hintText: '사용자 이름 입력',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return '이름을 입력해 주세요.';
                  if (val.trim().length > 12) return '12자 이하로 입력해 주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '보호용 비밀번호 / PIN 입력',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return '비밀번호를 입력해 주세요.';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = usernameController.text.trim();
              final pw = passwordController.text.trim();

              final success =
                  await context.read<HealthProvider>().register(name, pw);
              if (success) {
                if (!mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name 일반 사용자 프로필이 성공적으로 가입되었습니다.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('이미 존재하는 사용자 이름입니다.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('생성',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀 영역
              Text(
                '앱 설정',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '신체 스펙 정보 및 테마를 설정합니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),

              // 사용자 프로필 표시 및 로그아웃 카드
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: () {
                        final username = provider.currentUserId ?? 'U';
                        final hash = username.hashCode;
                        final colors = [
                          const Color(0xFF3B82F6),
                          const Color(0xFF8B5CF6),
                          const Color(0xFFEC4899),
                          const Color(0xFFF59E0B),
                          const Color(0xFF10B981),
                          const Color(0xFFEF4444),
                        ];
                        return colors[hash.abs() % colors.length];
                      }(),
                      child: Text(
                        (provider.currentUserId ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${provider.currentUserId ?? '사용자'} 프로필',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '오늘 하루도 건강하게 기록해 보세요.',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('로그아웃',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text(
                                '현재 프로필에서 로그아웃하고 프로필 선택 화면으로 이동하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('취소',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  provider.logout();
                                },
                                child: const Text('로그아웃',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.logout, size: 14),
                      label: const Text('로그아웃',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 1-2. 비밀번호 찾기(보안 질문) 설정 카드
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(20.0),
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_reset,
                              color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '비밀번호 찾기 (보안 질문)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.currentUserId != null &&
                              provider.hasRecovery(provider.currentUserId!)
                          ? '현재 질문: ${provider.getSecurityQuestion(provider.currentUserId!)}'
                          : '아직 보안 질문이 설정되지 않았습니다. 지금 설정해 두면 비밀번호를 잊어도 로그인 화면에서 직접 재설정할 수 있습니다.',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _showRecoveryQuestionDialog,
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(
                          provider.currentUserId != null &&
                                  provider.hasRecovery(provider.currentUserId!)
                              ? '보안 질문 변경'
                              : '보안 질문 설정하기',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 1-2. 관리자 전용 사용자 계정 관리 카드 (관리자 권한일 때만 노출)
              if (provider.isAdmin) ...[
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.admin_panel_settings,
                                color: Colors.amber, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '사용자 및 프로필 관리 (Admin)',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '등록된 사용자 프로필을 관리하고 패스워드를 변경하거나 데이터를 영구 삭제할 수 있습니다.',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            height: 1.4),
                      ),
                      const SizedBox(height: 16),

                      // 사용자 목록 렌더링
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.registeredUsers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final username = provider.registeredUsers[index];
                          final role = provider.getUserRole(username);
                          final isSelf = username == provider.currentUserId;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      theme.primaryColor.withOpacity(0.1),
                                  child: Text(
                                    username[0].toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            username,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (isSelf) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '(나)',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.primaryColor,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        role == 'admin'
                                            ? '권한: 관리자 (Admin)'
                                            : '권한: 일반 사용자',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.4)),
                                      ),
                                    ],
                                  ),
                                ),
                                // 액션 버튼들
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 비밀번호 변경 버튼
                                    IconButton(
                                      icon: const Icon(Icons.key,
                                          size: 18, color: Colors.blueGrey),
                                      onPressed: () =>
                                          _showResetPasswordDialog(username),
                                      tooltip: '비밀번호 변경',
                                    ),
                                    // 프로필 삭제 버튼 (자기 자신은 삭제 불가)
                                    if (!isSelf)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: Colors.redAccent),
                                        onPressed: () =>
                                            _showDeleteConfirmDialog(username),
                                        tooltip: '프로필 삭제',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // 신규 프로필 생성 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: theme.primaryColor, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _showAddUserDialog,
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('신규 프로필 등록',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. BMI 정보 분석 요약 카드 (키가 등록된 경우 실시간 렌더링)
              Container(
                width: double.infinity,
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
                        Icon(Icons.health_and_safety,
                            color: provider.bmiStatusColor, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          '나의 체질량지수 (BMI)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.bmi != null
                                  ? provider.bmi!.toStringAsFixed(1)
                                  : '-',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: provider.bmiStatusColor,
                              ),
                            ),
                            Text(
                              'BMI 지수',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4)),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    provider.bmiStatusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                provider.bmiStatus,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: provider.bmiStatusColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '키: ${provider.height ?? '-'}cm / 체중: ${provider.currentWeight ?? '-'}kg',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. 신체 세부 설정 카드
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '기본 정보 설정',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),

                    // 신장 (키) 입력 필드
                    const Text('신장(키) 입력',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _heightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration(
                          '현재 신장을 센티미터 단위로 입력하세요.', 'cm', theme),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return '키를 입력해 주세요.';
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) return '올바른 신장 값을 입력하세요.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 목표 체중 입력 필드
                    const Text('목표 체중 설정',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _targetWeightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration(
                          '달성하고자 하는 목표 체중을 입력하세요.', 'kg', theme),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return '목표 체중을 입력해 주세요.';
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) return '올바른 체중 값을 입력하세요.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 정보 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _saveSettings,
                        child: const Text(
                          '설정 변경 저장',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. 다크모드 대응 토글 설정
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.3)),
                ),
                child: SwitchListTile(
                  title: const Text('다크 모드 적용',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('화면 색상을 어두운 슬레이트 톤으로 전환합니다.',
                      style: TextStyle(fontSize: 12)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette,
                        color: Colors.indigo, size: 20),
                  ),
                  value: provider.isDarkMode,
                  activeColor: theme.primaryColor,
                  onChanged: (bool value) {
                    provider.toggleDarkMode(value);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 4. AI 분석 엔진 설정 카드
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.3)),
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
                            color: theme.primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.psychology,
                              color: theme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'AI 분석 엔진 설정',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI가 제공하는 맞춤 코칭 조언의 백엔드 엔진을 설정합니다.',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // 엔진 선택 토글
                    Row(
                      children: [
                        _buildEngineSelector(
                            'local', '로컬 규칙', Icons.code, '오프라인 분석', provider),
                        const SizedBox(width: 8),
                        _buildEngineSelector('ollama', 'Ollama local',
                            Icons.computer, '로컬 AI', provider),
                        const SizedBox(width: 8),
                      ],
                    ),

                    if (_selectedAiEngine == 'local') ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.dividerColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          '디바이스 내부 자체 규칙 엔진을 활용하여 오프라인 상태에서도 즉시 피드백을 생성합니다. (API 설정이 필요 없음)',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            provider.updateAiEngine('local');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('AI 분석 엔진이 로컬 규칙으로 설정되었습니다.',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Text('설정 저장',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    if (_selectedAiEngine == 'ollama') ...[
                      const SizedBox(height: 20),
                      const Text('Ollama API 주소 (Base URL)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ollamaBaseUrlController,
                        decoration: _buildInputDecoration(
                            'http://localhost:11434', '', theme),
                      ),
                      const SizedBox(height: 16),
                      const Text('Ollama 모델명',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ollamaModelController,
                        decoration: _buildInputDecoration('llama3', '', theme),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.amber.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.orangeAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'CORS 통신 허용 권장 가이드',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.orange[200]
                                          : Colors.orange[800]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '1. CORS 설정: `OLLAMA_ORIGINS=*`처럼 모든 사이트를 허용하지 마세요. 프로젝트의 setup_ollama.bat은 기본적으로 localhost:8080만 허용합니다.\n\n'
                              '2. GitHub Pages에서 연결하려면 `setup_ollama.bat https://사용자명.github.io`처럼 정확한 사이트 출처를 전달한 뒤 Ollama를 재시작하세요.\n\n'
                              '3. HTTPS 페이지에서 HTTP Ollama 주소로 접속하면 브라우저 정책에 따라 차단될 수 있습니다. 연결이 안 되면 로컬에서 앱을 실행하거나, 인증을 적용한 HTTPS 프록시를 사용하세요. Ollama 포트를 인터넷에 직접 공개하지 마세요.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(
                                      color: theme.primaryColor, width: 1.2),
                                ),
                                onPressed: _isTestingConnection
                                    ? null
                                    : _testOllamaConnection,
                                icon: _isTestingConnection
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.indigo),
                                      )
                                    : const Icon(Icons.bolt, size: 18),
                                label: const Text('연결 테스트',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  final engine = _selectedAiEngine;
                                  final url =
                                      _ollamaBaseUrlController.text.trim();
                                  final model =
                                      _ollamaModelController.text.trim();
                                  provider.updateAiEngine(engine);
                                  provider.updateOllamaBaseUrl(url);
                                  provider.updateOllamaModel(model);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ollama 로컬 AI 설정이 저장되었습니다.',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Text('설정 저장',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4-3. 개발자 옵션 카드
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.3)),
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
                            color: Colors.redAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bug_report,
                              color: Colors.redAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '개발자 옵션 (데모 테스트)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '대시보드 차트와 요약을 즉시 확인할 수 있도록 30일 분량의 점진적 다이어트 감량 가상 데이터를 주입합니다. (※ 기존 데이터는 전체 삭제됩니다.)',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.redAccent, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('가상 데이터 주입',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              content: const Text(
                                  '정말로 30일간의 가상 데이터를 주입하시겠습니까?\n기존 기록들은 모두 유실됩니다.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('취소',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    provider.generateMockData();
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '30일 가상 건강 데이터가 성공적으로 주입되었습니다.',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: const Text('주입 시작',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          '가상 건강 데이터 (30일분) 일괄 주입',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. 홈 화면에 앱(PWA) 추가 가이드
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.3)),
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
                            color: Colors.blue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.install_mobile,
                              color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '앱 설치 & 실행 방법 (PWA)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '본 웹앱은 PWA 규격을 완벽 지원하여 일반 스토어 앱처럼 독립 실행형으로 간편하게 모바일에 추가해 사용 가능합니다.',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    _buildPwaGuideRow(
                      Icons.phone_iphone,
                      'iOS Safari (아이폰/아이패드)',
                      '1. Safari 브라우저로 접속합니다.\n2. 하단 도구바에서 공유(공유 아이콘) 버튼을 클릭합니다.\n3. 목록에서 \'홈 화면에 추가\' 항목을 탭합니다.',
                      theme,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildPwaGuideRow(
                      Icons.android,
                      'Android Chrome & PC',
                      '1. Chrome 브라우저로 접속합니다.\n2. 우측 상단 더보기(:) 또는 주소창에서 \'앱 설치\' 아이콘을 탭합니다.\n3. 설치 완료 시 바탕화면에 앱 아이콘이 자동 생성됩니다.',
                      theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // 4. 보안 및 로컬 저장 안내 텍스트 영역
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security,
                              size: 14,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(width: 6),
                          Text(
                            '보안 및 개인정보 보호정책',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '건강 기록과 프로필은 브라우저 로컬 저장소에 보관됩니다. Ollama 분석을 선택하면 분석에 필요한 건강 기록이 사용자가 지정한 Ollama 서버로 전송될 수 있습니다. 프로필 PIN은 이 기기 안에서만 동작하며 서버 인증 수단이 아닙니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 텍스트필드 공통 데코레이션
  InputDecoration _buildInputDecoration(
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

  /// PWA 설치 가이드 열 정보 위젯
  Widget _buildPwaGuideRow(
      IconData icon, String title, String body, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            color: theme.colorScheme.onSurface.withOpacity(0.6), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
