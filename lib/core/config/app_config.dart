// lib/core/config/app_config.dart
import 'dart:convert'; // jsonDecode and jsonEncode
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/core/models/llm_models.dart'; // ToolDefinition 및 하위 모델들
import 'package:logging/logging.dart';

class AppConfig {
  final _log = Logger('AppConfig');

  // LLM Service Config (EnvService에서 관리)
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

  // Helper function to deeply convert YamlNodes to standard Dart types.
  static dynamic _convertNodeToValue(dynamic node) {
    if (node is YamlMap) {
      return _convertYamlMapToMap(node);
    } else if (node is YamlList) {
      // Ensure elements of the list are also converted
      return node.nodes.map((e) => _convertNodeToValue(e)).toList();
    } else if (node is YamlScalar) {
      // YamlScalar's value property holds the actual Dart type (String, int, double, bool, null)
      return node.value;
    }
    // If it's already a standard Dart type (e.g., from a default value), return as is.
    return node;
  }

  // Helper function to convert YamlMap to standard Map<String, dynamic>.
  static Map<String, dynamic> _convertYamlMapToMap(YamlMap yamlMap) {
    final Map<String, dynamic> map = {};
    yamlMap.nodes.forEach((keyNode, valueNode) {
      String key;
      // Ensure the key is a String
      if (keyNode is YamlScalar) {
        key = keyNode.value.toString();
      } else {
        // Fallback, though YAML keys are typically scalars.
        key = keyNode.toString();
      }
      map[key] = _convertNodeToValue(valueNode); // Recursively convert values
    });
    return map;
  }

  static Future<AppConfig> load(EnvService envService) async {
    final log = Logger('AppConfig.load');
    log.info("Loading AppConfig from YAML and .env...");

    final yamlString = await rootBundle.loadString('assets/config/app_config.yaml');
    final dynamic yamlDocNode = loadYamlNode(yamlString); // Use loadYamlNode for more control

    if (yamlDocNode == null || !(yamlDocNode is YamlMap)) {
      log.severe('Failed to load or parse app_config.yaml. Content was null or not a YamlMap.');
      throw Exception('Failed to load or parse app_config.yaml');
    }
    final YamlMap yamlMap = yamlDocNode;

    // Helper to get nested values safely from YamlMap and ensure they are converted
    dynamic getYamlValue(List<String> path, dynamic defaultValue) {
      dynamic currentYamlNode = yamlMap;
      for (String key in path) {
        if (currentYamlNode is YamlMap && currentYamlNode.containsKey(key)) {
          currentYamlNode = currentYamlNode[key]; // currentYamlNode is now a YamlNode
        } else {
          log.warning("YAML path '${path.join('.')}' not found, using default: $defaultValue");
          // If default value is provided, return it directly (it's already a Dart type)
          return defaultValue;
        }
      }
      // Convert the final YamlNode to a standard Dart type/structure
      return _convertNodeToValue(currentYamlNode);
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
    // getYamlValue now returns fully converted Dart structures
    final dynamic toolDefinitionsData = getYamlValue(['tool_definitions'], []);

    if (toolDefinitionsData is List) {
      for (var toolDefItem in toolDefinitionsData) {
        if (toolDefItem is Map<String, dynamic>) { // Expecting Map<String, dynamic> after conversion
          try {
            parsedToolDefinitions.add(ToolDefinition.fromJson(toolDefItem));
          } catch (e, s) {
            // Log the problematic map for easier debugging
            String problematicItemJson = "{ parsing error }";
            try {
              problematicItemJson = jsonEncode(toolDefItem);
            } catch (_) {}
            log.severe(
                "Failed to parse tool definition from fully converted map: $problematicItemJson. Error: $e",
                e, s
            );
          }
        } else {
          log.warning("Skipping invalid tool definition item (not a Map<String, dynamic> after YAML conversion): $toolDefItem, type: ${toolDefItem.runtimeType}");
        }
      }
    } else {
      log.warning("Tool definitions in YAML is not a list or is missing after conversion. Found: ${toolDefinitionsData.runtimeType}");
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
    if (config.toolDefinitions.isEmpty && (toolDefinitionsData is List && toolDefinitionsData.isNotEmpty)) {
      log.warning("Tool definitions were present in YAML but failed to parse into ToolDefinition objects. Check SEVERE logs above.");
    }
    return config;
  }
}