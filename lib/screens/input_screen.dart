import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';
import '../providers/health_provider.dart';

/// 건강 데이터를 입력받는 화면입니다.
/// 날짜, 체중, 체지방, 허리둘레, 운동, 수면, 식단 상태, 메모를 기록합니다.
/// 기존 기록의 수정(Edit) 목적으로도 재사용이 가능하도록 설계되었습니다.
class InputScreen extends StatefulWidget {
  final HealthRecord? recordToEdit; // 수정하려는 기존 데이터 (있을 경우만 전달)

  const InputScreen({super.key, this.recordToEdit});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();

  // 입력 컨트롤러 및 변수들
  late DateTime _selectedDate;
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
  final _exerciseController = TextEditingController();
  final _sleepController = TextEditingController();
  String _selectedMealStatus = 'normal'; // 기본값: 보통
  final _memoController = TextEditingController();
  String? _photoBase64; // 바디 사진 Base64
  bool _isPickingImage = false;
  static const int _maxPhotoBytes = 8 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    // 수정 모드인 경우 전달받은 기록으로 초기값을 세팅하고, 아니면 신규 값으로 세팅합니다.
    if (widget.recordToEdit != null) {
      final rec = widget.recordToEdit!;
      _selectedDate = rec.date;
      _weightController.text = rec.weight.toString();
      _bodyFatController.text = rec.bodyFat?.toString() ?? '';
      _waistController.text = rec.waist?.toString() ?? '';
      _exerciseController.text = rec.exercise ?? '';
      _sleepController.text = rec.sleepHours?.toString() ?? '';
      _selectedMealStatus = rec.mealStatus;
      _memoController.text = rec.memo ?? '';
      _photoBase64 = rec.photoBase64;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _exerciseController.dispose();
    _sleepController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  /// 날짜 선택 캘린더 다이얼로그를 띄웁니다.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// 폼 유효성 검사 후 데이터를 저장합니다.
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<HealthProvider>();

    // 데이터 파싱
    final double weight = double.parse(_weightController.text);
    final double? bodyFat = double.tryParse(_bodyFatController.text);
    final double? waist = double.tryParse(_waistController.text);
    final String? exercise = _exerciseController.text.trim().isEmpty
        ? null
        : _exerciseController.text.trim();
    final double? sleepHours = double.tryParse(_sleepController.text);
    final String? memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();

    // 신규 혹은 수정 레코드 객체 생성
    final newRecord = HealthRecord(
      id: widget.recordToEdit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      weight: weight,
      bodyFat: bodyFat,
      waist: waist,
      exercise: exercise,
      sleepHours: sleepHours,
      mealStatus: _selectedMealStatus,
      memo: memo,
      photoBase64: _photoBase64,
    );

    // 프로바이더를 통해 저장
    try {
      await provider.saveRecord(newRecord);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('저장에 실패했습니다. 네트워크 또는 저장 공간을 확인해 주세요.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // 알림 스낵바 노출
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.recordToEdit != null
              ? '기록이 성공적으로 수정되었습니다.'
              : '오늘의 건강 기록이 저장되었습니다.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 수정 모드인 경우 이전 화면(기록 목록)으로 돌아갑니다.
    if (widget.recordToEdit != null) {
      Navigator.of(context).pop();
    } else {
      // 신규 등록 시 폼을 초기화합니다.
      setState(() {
        _selectedDate = DateTime.now();
        _weightController.clear();
        _bodyFatController.clear();
        _waistController.clear();
        _exerciseController.clear();
        _sleepController.clear();
        _selectedMealStatus = 'normal';
        _memoController.clear();
        _photoBase64 = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: widget.recordToEdit != null
          ? AppBar(
              title: const Text('기록 수정',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true,
            )
          : null,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 스크롤 상단 안내 헤더 (신규 등록 시에만 노출)
              if (widget.recordToEdit == null)
                Text(
                  '기록 등록',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (widget.recordToEdit == null) const SizedBox(height: 4),
              if (widget.recordToEdit == null)
                Text(
                  '오늘의 체중과 몸 상태를 상세하게 남겨보세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              if (widget.recordToEdit == null) const SizedBox(height: 24),

              // 1. 날짜 선택 영역 카드 (아이폰 터치 편의성 극대화)
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: theme.primaryColor),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기록 날짜',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('yyyy년 MM월 dd일 (E)')
                                .format(_selectedDate),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. 필수 입력: 체중 입력 (모든 입력 폼의 타겟을 굵고 크게 처리)
              _buildSectionTitle('체중 입력 *'),
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: _buildInputDecoration('체중을 입력해주세요.', 'kg', theme),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '체중은 필수 입력 항목입니다.';
                  }
                  if (double.tryParse(value) == null) {
                    return '올바른 숫자를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 3. 선택 입력: 체지방률 & 허리둘레 (반응형 2열 가로배치)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('체지방률'),
                        TextFormField(
                          controller: _bodyFatController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          decoration:
                              _buildInputDecoration('선택 사항', '%', theme),
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return '숫자만 가능';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('허리둘레'),
                        TextFormField(
                          controller: _waistController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          decoration:
                              _buildInputDecoration('선택 사항', 'cm', theme),
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return '숫자만 가능';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. 선택 입력: 운동 내용 & 수면 시간
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('오늘 한 운동'),
                        TextFormField(
                          controller: _exerciseController,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          decoration: _buildInputDecoration(
                              '예: 러닝 5km, 홈트 30분', '', theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('수면 시간'),
                        TextFormField(
                          controller: _sleepController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: _buildInputDecoration('시간', '시간', theme),
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return '숫자만';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. 식단 상태 선택 (라디오 대신 손가락 터치가 쉬운 카드 3개 나열)
              _buildSectionTitle('식단 관리 상태'),
              Row(
                children: [
                  _buildMealCard('good', '🟢 좋음', isDark, theme),
                  const SizedBox(width: 10),
                  _buildMealCard('normal', '🟡 보통', isDark, theme),
                  const SizedBox(width: 10),
                  _buildMealCard('bad', '🔴 나쁨', isDark, theme),
                ],
              ),
              const SizedBox(height: 24),

              // 6. 메모 입력
              _buildSectionTitle('오늘의 메모'),
              TextFormField(
                controller: _memoController,
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
                decoration: _buildInputDecoration(
                    '바디 상태나 식단 메모 등 자유롭게 기입하세요.', '', theme),
              ),
              const SizedBox(height: 20),

              // 6-2. 바디 사진 등록
              _buildSectionTitle('바디 사진 등록'),
              _buildPhotoPicker(theme, isDark),
              const SizedBox(height: 36),

              // 7. 대형 저장 버튼 (아이폰 Safari에서 누르기 편하도록 세로 크기를 56px로 두껍게 빌드)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _submitForm,
                  child: Text(
                    widget.recordToEdit != null ? '수정 완료' : '기록 저장',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 각 입력 섹션의 타이틀 위젯입니다.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 텍스트필드 데코레이션을 공통 포맷으로 리턴합니다.
  InputDecoration _buildInputDecoration(
      String hint, String suffix, ThemeData theme) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.35)),
      suffixText: suffix.isNotEmpty ? suffix : null,
      suffixStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withOpacity(0.5)),
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  /// 식단 카드 위젯을 생성합니다.
  Widget _buildMealCard(
      String status, String label, bool isDark, ThemeData theme) {
    final isSelected = _selectedMealStatus == status;
    Color activeColor;

    switch (status) {
      case 'good':
        activeColor = Colors.green;
        break;
      case 'bad':
        activeColor = Colors.red;
        break;
      default:
        activeColor = Colors.orange;
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMealStatus = status;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(isDark ? 0.2 : 0.1)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : theme.dividerColor.withOpacity(0.5),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? activeColor : activeColor.withOpacity(0.9))
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  /// 바디 사진 등록 카드/미리보기 위젯
  Widget _buildPhotoPicker(ThemeData theme, bool isDark) {
    if (_photoBase64 != null) {
      return Stack(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _decodeBase64(_photoBase64!),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon:
                    const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                onPressed: () {
                  setState(() {
                    _photoBase64 = null;
                  });
                },
                tooltip: '사진 제거',
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo,
                size: 36, color: theme.primaryColor.withOpacity(0.8)),
            const SizedBox(height: 10),
            Text(
              '바디 사진 추가',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '사진을 업로드하여 시각적 타임라인을 관리해보세요.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 브라우저 파일 선택 창을 열고, 캔버스를 이용해 이미지를 리사이징한 뒤 Base64로 인코딩합니다.
  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      try {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          if (!file.type.toLowerCase().startsWith('image/')) {
            throw StateError('이미지 파일만 업로드할 수 있습니다.');
          }
          if (file.size > _maxPhotoBytes) {
            throw StateError('사진은 8MB 이하만 업로드할 수 있습니다.');
          }
          final reader = html.FileReader();
          reader.readAsDataUrl(file);
          reader.onLoadEnd.listen((event) {
            if (reader.error != null || reader.result is! String) {
              if (mounted) setState(() => _isPickingImage = false);
              return;
            }
            final base64Str = reader.result as String;

            final imageElement = html.ImageElement();
            imageElement.src = base64Str;
            imageElement.onLoad.listen((_) {
              const int maxWidth = 600;
              const int maxHeight = 600;
              int width = imageElement.naturalWidth;
              int height = imageElement.naturalHeight;

              if (width > maxWidth || height > maxHeight) {
                final double ratio = width / height;
                if (width > height) {
                  width = maxWidth;
                  height = (maxWidth / ratio).round();
                } else {
                  height = maxHeight;
                  width = (maxHeight * ratio).round();
                }
              }

              final canvas = html.CanvasElement(width: width, height: height);
              final ctx = canvas.context2D;
              ctx.drawImageScaled(imageElement, 0, 0, width, height);

              final resizedBase64 = canvas.toDataUrl('image/jpeg', 0.7);
              if (!mounted) return;
              setState(() {
                _photoBase64 = resizedBase64;
                _isPickingImage = false;
              });
            });
            imageElement.onError.listen((_) {
              if (mounted) setState(() => _isPickingImage = false);
            });
          });
        } else if (mounted) {
          setState(() => _isPickingImage = false);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  Uint8List _decodeBase64(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    final rawBase64 =
        commaIndex != -1 ? dataUrl.substring(commaIndex + 1) : dataUrl;
    return base64Decode(rawBase64);
  }
}
