// lib/core/config/app_config.dart
import 'dart:convert'; // jsonDecode를 위해 사용 (YamlMap을 Map<String,dynamic>으로 변환 시)
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/core/models/llm_models.dart'; // ToolDefinition 및 하위 모델들
import 'package:logging/logging.dart';

class AppConfig {
  final _log = Logger('AppConfig');

  // LLM Service Config (EnvService에서 관리)
  // late final String o3LlmApiKey; // EnvService에서 가져옴
  // late final String o3LlmApiEndpoint; // EnvService에서 가져옴
  late final String primaryLlmModelName;
  late final String secondaryLlmModelName;

  // Task: Slot Extraction Config
  late final String slotExtractionModel;
  late final double slotExtractionTemperature;
  late final int slotExtractionMaxTokens;
  late final String slotExtractionPromptTemplateString; // 로드된 프롬프트 내용

  // Task: Summarization Config
  late final bool summarizationEnabled;
  late final String summarizationModel;
  late final double summarizationTemperature;
  late final int summarizationMaxTokens;
  late final int targetSummaryTokens;
  late final int summarizeEveryNTurns;
  late final bool includeSlotsInSummaryPrompt;
  late final String includeToolResultsInSummary;
  late final String summarizationPromptTemplateString; // 로드된 프롬프트 내용

  // Task: Chat Orchestration Config
  late final double toolDecisionTemperature;
  late final int toolDecisionMaxTokens;
  late final double finalResponseTemperature;
  late final int finalResponseMaxTokens;
  late final int maxToolIterations;

  // Context Management
  late final int recentKTurns;

  // Tool Definitions
  late final List<ToolDefinition> toolDefinitions;

  // Private constructor
  AppConfig._({
    // required this.o3LlmApiKey, // EnvService에서 가져옴
    // required this.o3LlmApiEndpoint, // EnvService에서 가져옴
    required this.primaryLlmModelName,
    required this.secondaryLlmModelName,
    required this.slotExtractionModel,
    required this.slotExtractionTemperature,
    required this.slotExtractionMaxTokens,
    required this.slotExtractionPromptTemplateString,
    required this.summarizationEnabled,
    required this.summarizationModel,
    required this.summarizationTemperature,
    required this.summarizationMaxTokens,
    required this.targetSummaryTokens,
    required this.summarizeEveryNTurns,
    required this.includeSlotsInSummaryPrompt,
    required this.includeToolResultsInSummary,
    required this.summarizationPromptTemplateString,
    required this.toolDecisionTemperature,
    required this.toolDecisionMaxTokens,
    required this.finalResponseTemperature,
    required this.finalResponseMaxTokens,
    required this.maxToolIterations,
    required this.recentKTurns,
    required this.toolDefinitions,
  });

  // YamlMap을 일반 Map<String, dynamic>으로 변환하는 헬퍼 함수
  static Map<String, dynamic> _convertYamlMapToMap(YamlMap yamlMap) {
    final Map<String, dynamic> map = {};
    yamlMap.nodes.forEach((key, value) {
      if (key is YamlScalar) {
        map[key.value.toString()] = _convertNodeToValue(value.value);
      }
    });
    return map;
  }

  static dynamic _convertNodeToValue(dynamic node) {
    if (node is YamlMap) {
      return _convertYamlMapToMap(node);
    } else if (node is YamlList) {
      return node.nodes.map(_convertNodeToValue).toList();
    }
    return node;
  }

  static Future<AppConfig> load(EnvService envService) async {
    final log = Logger('AppConfig.load');
    log.info("Loading AppConfig from YAML and .env...");

    final yamlString = await rootBundle.loadString('assets/config/app_config.yaml');
    final dynamic yamlDoc = loadYaml(yamlString);

    if (yamlDoc == null || !(yamlDoc is YamlMap)) {
      log.severe('Failed to load or parse app_config.yaml. Content was null or not a YamlMap.');
      throw Exception('Failed to load or parse app_config.yaml');
    }
    final YamlMap yamlMap = yamlDoc;

    // Helper to get nested values safely from YamlMap
    dynamic getYamlValue(List<String> path, dynamic defaultValue) {
      dynamic current = yamlMap;
      for (String key in path) {
        if (current is YamlMap && current.containsKey(key)) {
          current = current[key];
        } else {
          log.warning("YAML path '${path.join('.')}' not found, using default: $defaultValue");
          return defaultValue;
        }
      }
      // YamlScalar/YamlList/YamlMap 등을 Dart 기본 타입으로 변환
      return _convertNodeToValue(current);
    }

    // 프롬프트 파일 내용 로드 함수
    Future<String> loadPromptString(String path, String fallbackPrompt) async {
      if (path.isNotEmpty) {
        try {
          return await rootBundle.loadString(path);
        } catch (e) {
          log.warning("Failed to load prompt from $path: $e. Using fallback.");
          return fallbackPrompt;
        }
      }
      return fallbackPrompt;
    }

    final slotPromptPath = getYamlValue(['tasks', 'slot_extraction', 'prompt_template_asset_path'], '') as String;
    final slotPromptString = await loadPromptString(slotPromptPath,
        """Extract key entities (slots) from the following user input. Respond strictly in JSON format. Example slots: "product_category", "brand_mentioned", "user_preference", "size_info". If no specific slots are found, return an empty JSON object. User input: "{user_input}" """
    );

    final summaryPromptPath = getYamlValue(['tasks', 'summarization', 'prompt_template_asset_path'], '') as String;
    final summaryPromptString = await loadPromptString(summaryPromptPath,
        """다음은 이전 대화 요약과 최근 대화 기록입니다. 이 전체 대화를 간결하게 요약해주세요. 사용자 프로필 정보나 시스템 지침은 제외하고 순수 대화 내용만 요약합니다. 한국어로 작성해주세요.\n\n[이전 요약]:\n{previous_summary}\n\n[최근 대화 기록]:\n{conversation_history}\n\n[요청사항]: 위 대화 내용을 바탕으로 전체 대화의 핵심 내용을 {target_summary_tokens} 토큰 내외로 요약해주세요."""
    );

    // Tool Definitions 파싱
    final List<ToolDefinition> parsedToolDefinitions = [];
    final dynamic yamlToolDefinitionsRaw = getYamlValue(['tool_definitions'], []); // 기본값으로 빈 리스트

    if (yamlToolDefinitionsRaw is List) {
      final List<dynamic> yamlToolDefinitions = yamlToolDefinitionsRaw;
      for (var toolDefRaw in yamlToolDefinitions) {
        if (toolDefRaw is Map<String, dynamic>) { // _convertNodeToValue가 Map<String,dynamic>으로 변환했음을 가정
          try {
            // Freezed 모델의 fromJson을 사용하기 위해 Map<String, dynamic>으로 변환
            parsedToolDefinitions.add(ToolDefinition.fromJson(toolDefRaw));
          } catch (e, s) {
            log.severe("Failed to parse tool definition: $toolDefRaw. Error: $e", e, s);
          }
        } else {
          log.warning("Skipping invalid tool definition item (not a Map): $toolDefRaw");
        }
      }
    } else {
      log.warning("Tool definitions in YAML is not a list or is missing. Found: ${yamlToolDefinitionsRaw.runtimeType}");
    }


    final config = AppConfig._(
      primaryLlmModelName: getYamlValue(['llm_service', 'primary_llm_model_name'], 'o3') as String,
      secondaryLlmModelName: getYamlValue(['llm_service', 'secondary_llm_model_name'], 'o3-mini') as String,

      slotExtractionModel: getYamlValue(['tasks', 'slot_extraction', 'model'], 'o3-mini') as String,
      slotExtractionTemperature: (getYamlValue(['tasks', 'slot_extraction', 'temperature'], 0.5) as num).toDouble(),
      slotExtractionMaxTokens: (getYamlValue(['tasks', 'slot_extraction', 'max_completion_tokens'], 500) as num).toInt(),
      slotExtractionPromptTemplateString: slotPromptString,

      summarizationEnabled: getYamlValue(['tasks', 'summarization', 'enabled'], true) as bool,
      summarizationModel: getYamlValue(['tasks', 'summarization', 'model'], 'o3-mini') as String,
      summarizationTemperature: (getYamlValue(['tasks', 'summarization', 'temperature'], 0.7) as num).toDouble(),
      summarizationMaxTokens: (getYamlValue(['tasks', 'summarization', 'max_completion_tokens'], 1000) as num).toInt(),
      targetSummaryTokens: (getYamlValue(['tasks', 'summarization', 'target_summary_tokens'], 300) as num).toInt(),
      summarizeEveryNTurns: (getYamlValue(['tasks', 'summarization', 'summarize_every_n_turns'], 3) as num).toInt(),
      includeSlotsInSummaryPrompt: getYamlValue(['tasks', 'summarization', 'include_slots_in_summary_prompt'], true) as bool,
      includeToolResultsInSummary: getYamlValue(['tasks', 'summarization', 'include_tool_results_in_summary'], 'brief') as String,
      summarizationPromptTemplateString: summaryPromptString,

      toolDecisionTemperature: (getYamlValue(['tasks', 'chat_orchestration', 'tool_decision_temperature'], 1.0) as num).toDouble(),
      toolDecisionMaxTokens: (getYamlValue(['tasks', 'chat_orchestration', 'tool_decision_max_completion_tokens'], 2000) as num).toInt(),
      finalResponseTemperature: (getYamlValue(['tasks', 'chat_orchestration', 'final_response_temperature'], 1.0) as num).toDouble(),
      finalResponseMaxTokens: (getYamlValue(['tasks', 'chat_orchestration', 'final_response_max_completion_tokens'], 2000) as num).toInt(),
      maxToolIterations: (getYamlValue(['tasks', 'chat_orchestration', 'max_tool_iterations'], 5) as num).toInt(),

      recentKTurns: (getYamlValue(['context_management', 'recent_k_turns'], 3) as num).toInt(),
      toolDefinitions: parsedToolDefinitions,
    );
    log.info("AppConfig loaded and initialized successfully.");
    log.fine("Loaded config details: Primary Model='${config.primaryLlmModelName}', Tool Definitions Count='${config.toolDefinitions.length}'");
    return config;
  }
}