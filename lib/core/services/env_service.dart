// lib/core/services/env_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:decathlon_demo_app/core/constants/app_constants.dart';
import 'package:logging/logging.dart'; // 로거 사용을 위해 추가

class EnvService {
  EnvService._();
  static final EnvService _instance = EnvService._();
  static EnvService get instance => _instance;

  final String _envFileName = ".env";
  final _log = Logger('EnvService'); // 로거 인스턴스 생성

  Future<void> load() async {
    try {
      await dotenv.load(fileName: _envFileName, mergeWith: {});
      _log.info('$_envFileName file loaded successfully by EnvService.');
      // 로드된 값 직접 확인 (디버깅용)
      _log.info('Loaded O3_LLM_API_KEY: ${dotenv.env['O3_LLM_API_KEY'] != null && dotenv.env['O3_LLM_API_KEY']!.isNotEmpty ? "Exists" : "MISSING or EMPTY"}');
      _log.info('Loaded O3_LLM_API_ENDPOINT: ${dotenv.env['O3_LLM_API_ENDPOINT'] ?? "MISSING or EMPTY"}');

    } catch (e, s) {
      _log.severe('Could not load $_envFileName file: $e', e, s);
    }
  }

  String _getEnvVariable(String key, {String defaultValue = ''}) {
    // dotenv.env에서 직접 읽어오기 전에 dotenv.isInitialized 확인 (선택적)
    if (!dotenv.isInitialized) {
      _log.warning('.env has not been loaded yet. Attempting to load now for key: $key');
      // load()를 여기서 다시 호출하는 것은 재귀적 문제를 일으킬 수 있으므로 주의.
      // main.dart에서 load()가 완료되도록 보장하는 것이 중요.
    }
    return dotenv.env[key]?.replaceAll('"', '') ?? defaultValue;
  }

  String get o3LlmApiKey => _getEnvVariable('O3_LLM_API_KEY');

  String get o3LlmApiEndpoint {
    String rawUrl = _getEnvVariable('O3_LLM_API_ENDPOINT');

    if (rawUrl.isEmpty) {
      _log.warning('O3_LLM_API_ENDPOINT not found in .env, using default from AppConstants.');
      rawUrl = AppConstants.defaultOpenAIApiBaseUrl;
    }

    String sanitizedUrl = rawUrl.replaceFirst(RegExp(r'/chat/completions/?$'), '');
    sanitizedUrl = sanitizedUrl.endsWith('/') ? sanitizedUrl.substring(0, sanitizedUrl.length - 1) : sanitizedUrl;

    return sanitizedUrl;
  }

  String get primaryLlmModelName => _getEnvVariable('PRIMARY_LLM_MODEL_NAME', defaultValue: AppConstants.defaultO3PrimaryModel);
  String get secondaryLlmModelName => _getEnvVariable('SECONDARY_LLM_MODEL_NAME', defaultValue: AppConstants.defaultO3SecondaryModel);

  bool get hasLlmApiKey => o3LlmApiKey.isNotEmpty;
}