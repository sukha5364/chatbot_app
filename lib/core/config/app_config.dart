// lib/core/config/app_config.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart'; // EnvService 임포트
import 'package:logging/logging.dart';

class AppConfig {
  final _log = Logger('AppConfig');

  // LLM Service Config
  late final String o3LlmApiKey;
  late final String o3LlmApiEndpoint;
  late final String primaryLlmModelName;
  late final String secondaryLlmModelName;

  // Task: Slot Extraction Config
  late final String slotExtractionModel;
  late final double slotExtractionTemperature;
  late final int slotExtractionMaxTokens;
  late final String? slotExtractionPromptTemplate; // 직접 사용 또는 경로

  // Task: Summarization Config
  late final bool summarizationEnabled;
  late final String summarizationModel;
  late final double summarizationTemperature;
  late final int summarizationMaxTokens;
  late final int targetSummaryTokens;
  late final int summarizeEveryNTurns;
  late final bool includeSlotsInSummaryPrompt;
  late final String includeToolResultsInSummary;
  late final String? summarizationPromptTemplate; // 직접 사용 또는 경로

  // Task: Chat Orchestration Config
  late final double toolDecisionTemperature;
  late final int toolDecisionMaxTokens;
  late final double finalResponseTemperature;
  late final int finalResponseMaxTokens;
  late final int maxToolIterations;

  // Context Management
  late final int recentKTurns;

  // Private constructor
  AppConfig._({
    required this.o3LlmApiKey,
    required this.o3LlmApiEndpoint,
    required this.primaryLlmModelName,
    required this.secondaryLlmModelName,
    required this.slotExtractionModel,
    required this.slotExtractionTemperature,
    required this.slotExtractionMaxTokens,
    this.slotExtractionPromptTemplate,
    required this.summarizationEnabled,
    required this.summarizationModel,
    required this.summarizationTemperature,
    required this.summarizationMaxTokens,
    required this.targetSummaryTokens,
    required this.summarizeEveryNTurns,
    required this.includeSlotsInSummaryPrompt,
    required this.includeToolResultsInSummary,
    this.summarizationPromptTemplate,
    required this.toolDecisionTemperature,
    required this.toolDecisionMaxTokens,
    required this.finalResponseTemperature,
    required this.finalResponseMaxTokens,
    required this.maxToolIterations,
    required this.recentKTurns,
  });

  static Future<AppConfig> load(EnvService envService) async {
    final log = Logger('AppConfig.load');
    log.info("Loading AppConfig from YAML and .env...");

    // 1. Load YAML config
    final yamlString = await rootBundle.loadString('assets/config/app_config.yaml');
    final dynamic yamlMap = loadYaml(yamlString);

    if (yamlMap == null || !(yamlMap is Map)) {
      log.severe('Failed to load or parse app_config.yaml. Content was null or not a Map.');
      throw Exception('Failed to load or parse app_config.yaml');
    }

    // Helper to get nested values safely
    dynamic getYamlValue(List<String> path, dynamic defaultValue) {
      dynamic current = yamlMap;
      for (String key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          log.warning("YAML path '${path.join('.')}' not found, using default: $defaultValue");
          return defaultValue;
        }
      }
      return current;
    }

    // 2. Load values from EnvService (these will override YAML if present)
    // .env 파일은 EnvService.load()를 통해 main.dart 등에서 미리 로드되어야 함
    final String apiKeyFromEnv = envService.o3LlmApiKey;
    final String apiEndpointFromEnv = envService.o3LlmApiEndpoint;

    if (apiKeyFromEnv.isEmpty) {
      log.warning("O3_LLM_API_KEY is empty in .env or not loaded. App might not function correctly.");
    }
    if (apiEndpointFromEnv.isEmpty) {
      log.warning("O3_LLM_API_ENDPOINT is empty in .env or not loaded. Using default if any, or might fail.");
    }

    // 3. Construct AppConfig, preferring .env values for specified keys
    final config = AppConfig._(
      o3LlmApiKey: apiKeyFromEnv, // Always from .env
      o3LlmApiEndpoint: apiEndpointFromEnv.isNotEmpty
          ? apiEndpointFromEnv
          : getYamlValue(['llm_service', 'o3_llm_api_endpoint'], 'https://api.example.com/o3/v1'), // Fallback if .env is empty
      primaryLlmModelName: getYamlValue(['llm_service', 'primary_llm_model_name'], 'o3'),
      secondaryLlmModelName: getYamlValue(['llm_service', 'secondary_llm_model_name'], 'o3-mini'),

      slotExtractionModel: getYamlValue(['tasks', 'slot_extraction', 'model'], 'o3-mini'),
      slotExtractionTemperature: (getYamlValue(['tasks', 'slot_extraction', 'temperature'], 0.5) as num).toDouble(),
      slotExtractionMaxTokens: getYamlValue(['tasks', 'slot_extraction', 'max_completion_tokens'], 500) as int,
      slotExtractionPromptTemplate: getYamlValue(['tasks', 'slot_extraction', 'prompt_template_asset_path'], null) as String?,


      summarizationEnabled: getYamlValue(['tasks', 'summarization', 'enabled'], true) as bool,
      summarizationModel: getYamlValue(['tasks', 'summarization', 'model'], 'o3-mini'),
      summarizationTemperature: (getYamlValue(['tasks', 'summarization', 'temperature'], 0.7) as num).toDouble(),
      summarizationMaxTokens: getYamlValue(['tasks', 'summarization', 'max_completion_tokens'], 1000) as int,
      targetSummaryTokens: getYamlValue(['tasks', 'summarization', 'target_summary_tokens'], 300) as int,
      summarizeEveryNTurns: getYamlValue(['tasks', 'summarization', 'summarize_every_n_turns'], 3) as int,
      includeSlotsInSummaryPrompt: getYamlValue(['tasks', 'summarization', 'include_slots_in_summary_prompt'], true) as bool,
      includeToolResultsInSummary: getYamlValue(['tasks', 'summarization', 'include_tool_results_in_summary'], 'brief') as String,
      summarizationPromptTemplate: getYamlValue(['tasks', 'summarization', 'prompt_template_asset_path'], null) as String?,


      toolDecisionTemperature: (getYamlValue(['tasks', 'chat_orchestration', 'tool_decision_temperature'], 0.7) as num).toDouble(),
      toolDecisionMaxTokens: getYamlValue(['tasks', 'chat_orchestration', 'tool_decision_max_completion_tokens'], 2000) as int,
      finalResponseTemperature: (getYamlValue(['tasks', 'chat_orchestration', 'final_response_temperature'], 0.7) as num).toDouble(),
      finalResponseMaxTokens: getYamlValue(['tasks', 'chat_orchestration', 'final_response_max_completion_tokens'], 2000) as int,
      maxToolIterations: getYamlValue(['tasks', 'chat_orchestration', 'max_tool_iterations'], 5) as int,

      recentKTurns: getYamlValue(['context_management', 'recent_k_turns'], 3) as int,
    );
    log.info("AppConfig loaded and initialized successfully.");
    log.fine("Loaded config details: Primary Model='${config.primaryLlmModelName}', Slot Model='${config.slotExtractionModel}'");
    return config;
  }
}