// lib/core/providers/core_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/core/services/o3_llm_service.dart';
import 'package:decathlon_demo_app/core/services/mock_api_service.dart';
import 'package:decathlon_demo_app/core/config/app_config.dart'; // AppConfig 임포트

// --- AppConfig Provider ---
// AppConfig는 비동기로 로드되므로 FutureProvider 또는 AsyncNotifierProvider 사용
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final envService = ref.watch(envServiceProvider); // EnvService를 먼저 watch
  // EnvService의 load가 완료된 후에 AppConfig.load를 호출하도록 보장 필요
  // EnvService에서 load가 동기적이거나, Future를 반환한다면 여기서 await 필요
  // 현재 EnvService.load()는 Future<void>이므로, EnvService 자체를 로딩 완료 시점으로 보기 어려움.
  // main.dart에서 EnvService.load()를 먼저 호출하고, 그 다음에 AppConfig.load()를 호출하는 방식 권장.
  // 여기서는 EnvService가 이미 로드되었다고 가정하고 진행.
  // 또는 EnvService.load()를 여기서도 호출하고 await 할 수 있음.
  // await envService.load(); // 안전하게 여기서도 호출 (선택 사항)
  return AppConfig.load(envService);
});

// --- EnvService Provider ---
final envServiceProvider = Provider<EnvService>((ref) {
  // EnvService의 load()는 main.dart에서 앱 시작 시 호출되는 것을 가정
  return EnvService.instance;
});

// --- O3LlmService Provider ---
final o3LlmServiceProvider = Provider<O3LlmService>((ref) {
  final envService = ref.watch(envServiceProvider);
  // AppConfig가 로드된 후에 O3LlmService를 생성해야 할 수 있음 (만약 모델명 등을 AppConfig에서 읽어온다면)
  // 현재 O3LlmService는 EnvService만 받으므로 이대로 유지. 필요시 AppConfig도 주입.
  return O3LlmService(envService);
});

// --- MockApiService Provider ---
final mockApiServiceProvider = Provider<MockApiService>((ref) {
  return MockApiService();
});

// --- Background Task State Enum ---
// 백그라운드 작업의 현재 상태를 나타냅니다.
enum BackgroundTaskState {
  idle, // 대기 중
  slotExtracting, // 슬롯 추출 작업 중
  summarizing, // 대화 요약 작업 중
  error, // 오류 발생
}

// --- Background Task Status Provider ---
// 현재 진행 중인 백그라운드 작업의 상태를 관리합니다.
final backgroundTaskStatusProvider = StateProvider<BackgroundTaskState>((ref) => BackgroundTaskState.idle);

// (선택적) 백그라운드 작업의 구체적인 오류 메시지나 결과를 위한 프로바이더
final backgroundTaskErrorProvider = StateProvider<String?>((ref) => null);
final backgroundTaskResultProvider = StateProvider<dynamic>((ref) => null); // 작업 결과 타입이 다양할 수 있음