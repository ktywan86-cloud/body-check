import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/health_provider.dart';
import 'services/storage_service.dart';
import 'services/analysis_service.dart';
import 'screens/home_screen.dart';
import 'screens/input_screen.dart';
import 'screens/history_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        // Storage 및 Analysis 서비스는 상태 변화가 없는 싱글톤처럼 관리합니다.
        Provider<StorageService>(
          create: (_) => LocalStorageService(),
        ),
        Provider<AnalysisService>(
          create: (_) => MockAnalysisService(),
        ),
        // 의존성을 주입하여 HealthProvider를 상위에 배치합니다.
        ChangeNotifierProxyProvider2<StorageService, AnalysisService,
            HealthProvider>(
          create: (context) => HealthProvider(
            storageService: context.read<StorageService>(),
            analysisService: context.read<AnalysisService>(),
          ),
          update: (_, storage, analysis, previous) =>
              previous ??
              HealthProvider(
                storageService: storage,
                analysisService: analysis,
              ),
        ),
      ],
      child: const BodyCheckApp(),
    ),
  );
}

class BodyCheckApp extends StatefulWidget {
  const BodyCheckApp({super.key});

  @override
  State<BodyCheckApp> createState() => _BodyCheckAppState();
}

class _BodyCheckAppState extends State<BodyCheckApp> {
  @override
  void initState() {
    super.initState();
    // 앱이 처음 구동될 때 상태 정보(로컬 데이터 등)를 비동기로 로드합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthProvider>().loadAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<HealthProvider>().isDarkMode;

    return MaterialApp(
      title: 'Body Check',
      debugShowCheckedModeBanner: false,

      // 세련되고 모던한 헬스케어 테마 (Light Mode)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF3B82F6), // 스포티 블루
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        dividerColor: const Color(0xFFE2E8F0), // Slate 200 경계선 정의
        cardTheme: const CardTheme(
          color: Colors.white,
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
        textTheme: const TextTheme(
          headlineLarge:
              TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          titleLarge:
              TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
      ),

      // 프리미엄 다크 테마 (Dark Mode)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF60A5FA), // 밝은 하늘색
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B), // Slate 800
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        dividerColor: const Color(0xFF334155), // Slate 700 경계선 정의
        cardTheme: const CardTheme(
          color: Color(0xFF1E293B),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              color: Colors.white),
          titleLarge: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),

      // 사용자 설정에 따라 테마를 전환합니다.
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      home: context.watch<HealthProvider>().isLoggedIn
          ? const MainAppShell()
          : const LoginScreen(),
    );
  }
}

/// PC 웹화면에서는 왼쪽 사이드바, 모바일 화면에서는 하단 탭바로 자동 전환되는
/// 반응형 앱 쉘(Navigation Shell) 위젯입니다.
class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _currentIndex = 0;

  // 네비게이션 대상이 될 화면들
  final List<Widget> _screens = const [
    HomeScreen(),
    InputScreen(),
    HistoryScreen(),
    ChartScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.watch<HealthProvider>().isLoading;

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 너비가 768px 이상이면 PC/태블릿 레이아웃 (사이드 바 제공)
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                // 좌측 사이드 네비게이션 레일
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.primaryColor.withOpacity(0.15),
                  selectedIconTheme: IconThemeData(color: theme.primaryColor),
                  selectedLabelTextStyle: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.primaryColor,
                          child:
                              const Icon(Icons.favorite, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Body Check',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('홈'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add_circle_outline),
                      selectedIcon: Icon(Icons.add_circle),
                      label: Text('기록 입력'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('기록 목록'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.show_chart_outlined),
                      selectedIcon: Icon(Icons.show_chart),
                      label: Text('그래프'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('설정'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // 실제 화면 콘텐츠 영역
                Expanded(
                  child: ClipRect(
                    child: _screens[_currentIndex],
                  ),
                ),
              ],
            ),
          );
        } else {
          // 모바일 레이아웃 (하단 탭바 제공)
          return Scaffold(
            body: SafeArea(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: theme.colorScheme.surface,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle),
                  label: '입력',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: '목록',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.show_chart_outlined),
                  activeIcon: Icon(Icons.show_chart),
                  label: '차트',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: '설정',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
