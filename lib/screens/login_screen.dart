import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedProfile;
  final _pinController = TextEditingController();
  bool _isCreatingProfile = false;
  bool _obscurePin = true;
  bool _autoLogin = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // Generate a distinct avatar color based on username hash
  Color _getAvatarColor(String username) {
    final hash = username.hashCode;
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFFEF4444), // Red
    ];
    return colors[hash.abs() % colors.length];
  }

  void _handleLogin() async {
    if (_selectedProfile == null) return;
    final pin = _pinController.text;

    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호를 입력해 주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final provider = context.read<HealthProvider>();
    final success =
        await provider.login(_selectedProfile!, pin, autoLogin: _autoLogin);

    if (success) {
      _pinController.clear();
      // Login triggers navigation swap in main.dart
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다. 다시 입력해 주세요.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCreateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final provider = context.read<HealthProvider>();

    // 1. Register new user
    final success = await provider.register(username, password);
    if (success) {
      // 2. Automatically log in
      await provider.login(username, password);

      _usernameController.clear();
      _passwordController.clear();
      setState(() {
        _isCreatingProfile = false;
      });
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final users = provider.registeredUsers;

    // Default premium dark background for login flow (Netflix-style dark aesthetic)
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding:
                const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Heart/Check Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFF60A5FA), // Light Blue
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Body Check',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  users.isEmpty
                      ? '최초 접속: 시스템을 관리할 관리자(Admin) 프로필을 추가해 주세요.'
                      : (_isCreatingProfile
                          ? '새 프로필 추가'
                          : (_selectedProfile != null
                              ? '비밀번호를 입력하세요'
                              : '누가 오늘 몸무게를 체크하나요?')),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF94A3B8), // Slate 400
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // 1. Register Mode Form
                if (_isCreatingProfile || users.isEmpty)
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          users.isEmpty ? '관리자 이름 (Admin)' : '사용자 이름 (프로필 명칭)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: _buildInputDecoration(users.isEmpty
                              ? '예: admin, 관리자 등'
                              : '예: 아빠, 엄마, 길동 등'),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return '이름을 입력해 주세요.';
                            if (val.trim().length > 12)
                              return '12자 이하로 입력해 주세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '비밀번호 / PIN 번호',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: _buildInputDecoration('프로필 보호용 비밀번호 입력'),
                          validator: (val) {
                            if (val == null || val.isEmpty)
                              return '비밀번호를 입력해 주세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _handleCreateProfile,
                            child: Text(
                                users.isEmpty
                                    ? '관리자 프로필 생성 및 진입'
                                    : '프로필 생성 및 진입',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (users.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF334155)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isCreatingProfile = false;
                                });
                              },
                              child: const Text('취소',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]
                      ],
                    ),
                  )

                // 2. Select profile mode or password entry mode
                else if (_selectedProfile != null)
                  Column(
                    children: [
                      // Profile Avatar Icon
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _getAvatarColor(_selectedProfile!),
                        child: Text(
                          _selectedProfile![0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedProfile!,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        autofocus: true,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '비밀번호를 입력하세요',
                          hintStyle: const TextStyle(
                              color: Color(0xFF475569), fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF3B82F6), width: 1.5),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                        ),
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _autoLogin,
                              activeColor: const Color(0xFF3B82F6),
                              checkColor: Colors.white,
                              side: const BorderSide(
                                  color: Color(0xFF475569), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _autoLogin = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _autoLogin = !_autoLogin;
                              });
                            },
                            child: const Text(
                              '이 기기에서 자동 로그인',
                              style: TextStyle(
                                color: Color(0xFF94A3B8), // Slate 400
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFF334155)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedProfile = null;
                                    _pinController.clear();
                                    _autoLogin = false;
                                  });
                                },
                                child: const Text('프로필 목록',
                                    style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _handleLogin,
                                child: const Text('로그인',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )

                // 3. Grid Profile List
                else
                  Column(
                    children: [
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: [
                          ...users.map((username) {
                            final isUserAdmin =
                                provider.getUserRole(username) == 'admin';
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedProfile = username;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: _getAvatarColor(username),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          username[0].toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      ),
                                      if (isUserAdmin)
                                        Positioned(
                                          top: -8,
                                          right: -8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber[700],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '👑 Admin',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    username,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Add Profile Card
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCreatingProfile = true;
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFF334155),
                                        width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.add,
                                    color: Color(0xFF64748B),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '프로필 추가',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
