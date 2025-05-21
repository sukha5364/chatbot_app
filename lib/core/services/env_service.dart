// 파일 경로: lib/core/services/env_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter/foundation.dart'; // 사용되지 않아 삭제

class EnvService {
  // Private constructor
  EnvService._();

  static final EnvService _instance = EnvService._();

  // Publicly accessible instance
  static EnvService get instance => _instance;

  Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
      // _log.info('.env file loaded successfully'); // Logger 사용 시
    } catch (e) {
      // _log.warning('Could not load .env file. Using default or environment variables.', e);
      // .env 파일이 없어도 환경 변수에서 값을 읽어올 수 있으므로, 여기서는 오류를 발생시키지 않음.
      // 필요하다면 print('Error loading .env file: $e'); 등으로 로깅 가능
    }
  }

  String get o3LlmApiKey => dotenv.env['O3_LLM_API_KEY'] ?? '';
  String get o3LlmApiEndpoint => dotenv.env['O3_LLM_API_ENDPOINT'] ?? '';

  // 여러 모델을 관리할 경우
  String get primaryLlmModelName => dotenv.env['PRIMARY_LLM_MODEL_NAME'] ?? 'gpt-4-turbo-preview'; // 예시 기본값
  String get secondaryLlmModelName => dotenv.env['SECONDARY_LLM_MODEL_NAME'] ?? 'gpt-3.5-turbo'; // 예시 기본값

  // API 키 존재 여부 확인 (선택적)
  bool get hasLlmApiKey => o3LlmApiKey.isNotEmpty;

// 필요하다면 다른 환경 변수들도 여기에 추가
// String get anotherApiEndpoint => dotenv.env['ANOTHER_API_ENDPOINT'] ?? '';
}