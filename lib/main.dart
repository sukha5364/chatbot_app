// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/features/auth/presentation/login_screen.dart';
import 'package:decathlon_demo_app/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/background/background_task_queue.dart'; // backgroundTaskQueueProvider

// 로깅 설정 함수
void _setupLogging() {
  Logger.root.level = Level.ALL; // 개발 중에는 상세 로깅, 배포 시 INFO 등으로 조정
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
        '[${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')}:${record.time.second.toString().padLeft(2, '0')}.${record.time.millisecond.toString().padLeft(3, '0')}] ${record.level.name.padRight(7)}: ${record.loggerName.padRight(25)}: ${record.message}'); // loggerName 길이 조정
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null && record.level.value >= Level.SEVERE.value) { // 심각한 오류 시에만 스택 트레이스 출력 (선택)
      // ignore: avoid_print
      // print('  STACKTRACE: ${record.stackTrace}'); // 너무 길어서 주석 처리 (필요시 해제)
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();
  final log = Logger('AppMain');

  // 1. EnvService 로드 (필수)
  try {
    await EnvService.instance.load();
    log.info(".env file processing attempted by EnvService.");
  } catch (e) {
    log.severe("Critical error during EnvService.load(): $e. App might not function correctly.", e);
    // EnvService 로드 실패 시 앱 실행을 중단하거나 대체 흐름을 제공해야 할 수 있음
  }

  // ProviderScope로 앱을 감싸서 Riverpod 사용 가능하게 함
  runApp(const ProviderScope(child: MyAppEntry()));
}

// AppConfig 및 BackgroundTaskQueue 초기화를 처리하기 위한 중간 위젯
class MyAppEntry extends ConsumerWidget {
  const MyAppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = Logger('MyAppEntry');
    // AppConfig 로드 상태를 watch
    final appConfigAsyncValue = ref.watch(appConfigProvider);

    return appConfigAsyncValue.when(
      data: (appConfig) {
        log.info("AppConfig loaded successfully. Now initializing BackgroundTaskQueue...");
        // AppConfig 로드 성공 후 BackgroundTaskQueue 초기화 시도
        // backgroundTaskQueueProvider는 AppConfig에 의존하므로, 여기서 read하면
        // AppConfig가 주입된 인스턴스를 받게 됨.
        // 이 인스턴스의 initialize()를 호출하고 그 결과를 기다림.
        return FutureBuilder<void>(
          future: ref.read(backgroundTaskQueueProvider).initialize().timeout(
              const Duration(seconds: 25), // BGTQ 초기화 타임아웃
              onTimeout: () {
                log.severe("BackgroundTaskQueue initialization timed out in MyAppEntry.");
                // 여기서 에러를 throw하면 아래 error 빌더에서 처리됨
                throw Exception("BackgroundTaskQueue initialization timed out.");
              }
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              log.info("BackgroundTaskQueue is initializing...");
              return _buildLoadingScreen("백그라운드 서비스 준비 중...");
            } else if (snapshot.hasError) {
              log.severe("Failed to initialize BackgroundTaskQueue.", snapshot.error, snapshot.stackTrace);
              return _buildErrorScreen("백그라운드 서비스 초기화 실패: ${snapshot.error}");
            } else {
              log.info("BackgroundTaskQueue initialized successfully. Starting MyApp.");
              return const MyApp(); // 실제 앱 위젯 반환
            }
          },
        );
      },
      loading: () {
        log.info("AppConfig is loading... Showing loading screen.");
        return _buildLoadingScreen("앱 설정을 불러오는 중...");
      },
      error: (error, stackTrace) {
        log.severe("Failed to load AppConfig. Showing error screen.", error, stackTrace);
        return _buildErrorScreen("앱 설정 로드 실패: $error");
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "$message\n앱을 재시작하거나 관리자에게 문의하세요.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}


class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Decathlon AI Chatbot Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // 시스템 설정에 따르도록 변경 또는 ThemeMode.dark 유지
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'), // 기본 로케일 한국어
      home: const LoginScreen(),
    );
  }
}