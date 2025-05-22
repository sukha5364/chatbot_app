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
import 'package:decathlon_demo_app/background/background_task_queue.dart'; // <--- 이미 추가되어 있어야 함 (5번 항목과 연관)

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
        '[${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')}:${record.time.second.toString().padLeft(2, '0')}.${record.time.millisecond.toString().padLeft(3, '0')}] ${record.level.name.padRight(7)}: ${record.loggerName.padRight(25)}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null && record.level.value >= Level.SEVERE.value) {
      // ignore: avoid_print
      // print('  STACKTRACE: ${record.stackTrace}');
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();
  final log = Logger('AppMain');

  try {
    await EnvService.instance.load();
    log.info(".env file processing attempted by EnvService.");
  } catch (e) {
    log.severe("Critical error during EnvService.load(): $e. App might not function correctly.", e);
  }
  runApp(const ProviderScope(child: MyAppEntry()));
}

class MyAppEntry extends ConsumerWidget {
  const MyAppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = Logger('MyAppEntry');
    final appConfigAsyncValue = ref.watch(appConfigProvider);

    return appConfigAsyncValue.when(
      data: (appConfig) {
        log.info("AppConfig loaded successfully. Now initializing BackgroundTaskQueue...");
        return FutureBuilder<void>(
          future: ref.read(backgroundTaskQueueProvider).initialize().timeout( // <--- 여기!
              const Duration(seconds: 25),
              onTimeout: () {
                log.severe("BackgroundTaskQueue initialization timed out in MyAppEntry.");
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
              return const MyApp();
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
      themeMode: ThemeMode.system,
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
      locale: const Locale('ko', 'KR'),
      home: const LoginScreen(),
    );
  }
}