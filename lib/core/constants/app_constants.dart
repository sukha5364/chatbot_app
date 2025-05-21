// 파일 경로: lib/core/constants/app_constants.dart
class AppConstants {
  // API Endpoints
  static const String defaultOpenAIApiBaseUrl = "https://api.openai.com/v1";
  static const String chatCompletionsEndpoint = "/chat/completions";

  // LLM Model Names (will be overridden by .env values if present)
  static const String defaultO3PrimaryModel = "o3"; // .env에서 읽어올 키: O3_PRIMARY_MODEL_NAME
  static const String defaultO3SecondaryModel = "o3-mini"; // .env에서 읽어올 키: O3_SECONDARY_MODEL_NAME

  // Function Calling Max Iterations (Python 코드 참고)
  static const int maxToolIterations = 5; // 또는 config.yaml의 max_iterations 값

  // 기타 앱 전역 상수
  static const String appTitle = "데카트론 AI 시연";
}