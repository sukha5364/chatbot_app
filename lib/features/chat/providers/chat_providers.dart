// 파일 경로: lib/features/chat/providers/chat_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/features/auth/providers/auth_providers.dart';
import 'package:decathlon_demo_app/features/chat/services/chat_orchestration_service.dart';
// import 'package:decathlon_demo_app/core/services/o3_llm_service.dart'; // 사용되지 않아 삭제
// import 'package:decathlon_demo_app/core/services/mock_api_service.dart'; // 사용되지 않아 삭제
// import 'package:decathlon_demo_app/core/services/env_service.dart'; // 사용되지 않아 삭제
import 'package:decathlon_demo_app/core/providers/core_providers.dart';

// Chat Orchestration Service Provider
final chatOrchestrationServiceProvider = Provider<ChatOrchestrationService>((ref) {
  return ChatOrchestrationService(
    ref: ref,
    o3LlmService: ref.watch(o3LlmServiceProvider), // core_providers.dart에서 가져옴
    mockApiService: ref.watch(mockApiServiceProvider), // core_providers.dart에서 가져옴
    envService: ref.watch(envServiceProvider), // core_providers.dart에서 가져옴
    currentUserProfile: ref.watch(currentUserProfileProvider),
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