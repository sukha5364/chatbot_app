// lib/features/chat/providers/chat_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/features/auth/providers/auth_providers.dart';
import 'package:decathlon_demo_app/features/chat/services/chat_orchestration_service.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart';
import 'package:decathlon_demo_app/core/config/app_config.dart';

// Chat Orchestration Service Provider
final chatOrchestrationServiceProvider = Provider<ChatOrchestrationService>((ref) {
  final appConfigAsync = ref.watch(appConfigProvider);
  // EnvService는 AppConfig 로드 시 이미 사용되었으므로, ChatOrchestrationService에 직접 전달할 필요가 없습니다.
  // final envService = ref.watch(envServiceProvider); // 이 줄은 더 이상 필요하지 않습니다.
  final o3LlmService = ref.watch(o3LlmServiceProvider);
  final mockApiService = ref.watch(mockApiServiceProvider); // ToolRunner 내부에서 ref.read로 접근하게 됩니다.
  final currentUserProfile = ref.watch(currentUserProfileProvider);

  final appConfig = appConfigAsync.value;

  if (appConfig == null) {
    // AppConfig가 로드되지 않은 경우, 서비스 생성 불가.
    // main.dart에서 AppConfig 로딩을 처리하므로 이 경우는 예외적이어야 합니다.
    throw Exception("AppConfig not loaded when creating ChatOrchestrationService. Check main.dart initialization logic.");
  }

  return ChatOrchestrationService(
    ref: ref,
    o3LlmService: o3LlmService,
    mockApiService: mockApiService, // 생성자에는 있지만, ToolRegistry 내부에서 사용되도록 변경됨
    // envService: envService, // <<< 이 줄을 제거합니다.
    appConfig: appConfig,
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

// Background task results (이전에 background_task_queue.dart에서 참조하려 했던 것들)
final lastExtractedSlotsProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final currentChatSummaryProvider = StateProvider<String?>((ref) => null);