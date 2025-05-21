// 파일 경로: lib/core/providers/core_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/core/services/o3_llm_service.dart';
import 'package:decathlon_demo_app/core/services/mock_api_service.dart'; // MockApiService 클래스 import

// EnvService Provider
final envServiceProvider = Provider<EnvService>((ref) {
  final service = EnvService.instance;
  // EnvService.instance.load(); // 필요하다면 여기서 load 호출 (또는 main.dart, 또는 EnvService 내부에서)
  return service;
});

// O3LlmService Provider
final o3LlmServiceProvider = Provider<O3LlmService>((ref) {
  final envService = ref.watch(envServiceProvider);
  return O3LlmService(envService);
});

// MockApiService Provider
final mockApiServiceProvider = Provider<MockApiService>((ref) { // ✅ 이 정의를 사용합니다.
  return MockApiService();
});