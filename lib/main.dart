// 파일 경로: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/features/auth/presentation/login_screen.dart';
import 'package:decathlon_demo_app/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart'; // logging 패키지 import

// 로깅 설정 함수
void _setupLogging() {
  Logger.root.level = Level.ALL; // 개발 중에는 모든 로그를 확인, 배포 시 Level.INFO 등으로 조정
  Logger.root.onRecord.listen((record) {
    // 콘솔에 로그 출력 형식: [시간] 레벨: 로거이름: 메시지
    // ignore: avoid_print
    print('[${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')}:${record.time.second.toString().padLeft(2, '0')}.${record.time.millisecond.toString().padLeft(3, '0')}] ${record.level.name.padRight(7)}: ${record.loggerName.padRight(25)}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('  STACKTRACE: ${record.stackTrace}');
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging(); // 앱 시작 시 로깅 설정
  final log = Logger('AppMain'); // main.dart용 로거

  try {
    await dotenv.load(fileName: ".env");
    log.info(".env file loaded successfully.");
  } catch (e) {
    log.warning("Error loading .env file: $e. This may be normal if running in an environment where .env is not used (e.g., CI/CD with injected vars) or if the file is missing. Ensure API keys are available.", e);
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget { // ConsumerWidget으로 변경하여 Riverpod 사용 용이
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 필요시 여기서 테마 모드 등을 Riverpod으로 관리 가능
    return MaterialApp(
      title: 'Decathlon AI Chatbot Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // 시연을 위해 다크 모드로 고정 (또는 시스템 설정 따르도록 ThemeMode.system)
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'), // Optional fallback
      ],
      locale: const Locale('ko', 'KR'), // 기본 로케일 한국어로 강제
      home: const LoginScreen(),
    );
  }
}