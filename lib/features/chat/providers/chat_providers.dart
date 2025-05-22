// lib/features/chat/providers/chat_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/features/auth/providers/auth_providers.dart';
import 'package:decathlon_demo_app/features/chat/services/chat_orchestration_service.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart'; // envServiceProvider, o3LlmServiceProvider, mockApiServiceProvider, appConfigProvider
import 'package:decathlon_demo_app/core/config/app_config.dart'; // AppConfig 모델

// Chat Orchestration Service Provider
final chatOrchestrationServiceProvider = Provider<ChatOrchestrationService>((ref) {
  // AppConfig와 다른 서비스들을 비동기적으로 watch합니다.
  // AppConfig 로드가 완료된 후에 ChatOrchestrationService를 생성합니다.
  final appConfig = ref.watch(appConfigProvider).value; // .value로 실제 값 접근 (null일 수 있음)
  final envService = ref.watch(envServiceProvider);
  final o3LlmService = ref.watch(o3LlmServiceProvider);
  final mockApiService = ref.watch(mockApiServiceProvider);
  final currentUserProfile = ref.watch(currentUserProfileProvider);

  if (appConfig == null) {
    // AppConfig가 아직 로드되지 않았거나 로드에 실패한 경우,
    // ChatOrchestrationService를 생성할 수 없습니다.
    // 이 경우, 앱 로직상 오류를 던지거나, 기능이 제한된 플레이스홀더 객체를 반환해야 합니다.
    // main.dart에서 AppConfig 로딩을 처리하므로, 이 시점에는 appConfig가 null이 아니어야 정상입니다.
    throw Exception("AppConfig not loaded when creating ChatOrchestrationService. Check main.dart initialization logic.");
  }

  return ChatOrchestrationService(
    ref: ref,
    o3LlmService: o3LlmService,
    mockApiService: mockApiService,
    envService: envService,
    appConfig: appConfig, // ✨ AppConfig 전달
    currentUserProfile: currentUserProfile,
  );
});

// Chat Messages State Provider
final chatMessagesProvider = StateNotifierProvider<ChatMessageNotifier, List<ChatMessage>>((ref) {
  return ChatMessageNotifier();
});

class ChatMessageNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessageNotifier() : super([]);

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void addMessages(List<ChatMessage> messages) {
    state = [...state, ...messages];
  }

  void clearMessages() {
    state = [];
  }
}

// Chat Loading State Provider
final chatLoadingProvider = StateProvider<bool>((ref) => false);

// QR Code Data State Provider
final qrCodeDataProvider = StateProvider<String?>((ref) => null);

// 음성 인식 중 상태 Provider
final voiceRecognitionActiveProvider = StateProvider<bool>((ref) => false);

// ✨ 추가된 Provider (이전에 background_task_queue.dart에서 참조하려고 했던 것들)
final lastExtractedSlotsProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final currentChatSummaryProvider = StateProvider<String?>((ref) => null);