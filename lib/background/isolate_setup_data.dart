// lib/background/isolate_setup_data.dart
import 'package:decathlon_demo_app/core/config/app_config.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/core/constants/app_constants.dart'; // AppConstants 추가

class IsolateSetupData {
  final AppConfig appConfig;
  final String o3LlmApiKey;
  final String o3LlmApiFullEndpoint; // base 엔드포인트 대신 전체 엔드포인트

  IsolateSetupData({
    required this.appConfig,
    required this.o3LlmApiKey,
    required this.o3LlmApiFullEndpoint, // 이름 변경 및 역할 명확화
  });

  factory IsolateSetupData.fromServices(AppConfig config, EnvService env) {
    // EnvService에서 base URL을 가져오고, 여기에 chat completions 경로를 추가합니다.
    final baseUrl = env.o3LlmApiEndpoint; // EnvService는 base URL을 반환한다고 가정
    final fullEndpoint = baseUrl.endsWith('/')
        ? "$baseUrl${AppConstants.chatCompletionsEndpoint.substring(1)}"
        : "$baseUrl${AppConstants.chatCompletionsEndpoint}";

    return IsolateSetupData(
      appConfig: config,
      o3LlmApiKey: env.o3LlmApiKey,
      o3LlmApiFullEndpoint: fullEndpoint, // 완전한 엔드포인트 전달
    );
  }
}