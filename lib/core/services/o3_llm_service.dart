// lib/core/services/o3_llm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/core/models/llm_models.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/core/constants/app_constants.dart';
import 'package:logging/logging.dart';

class O3LlmService {
  final EnvService _envService;
  final _log = Logger('O3LlmService');

  O3LlmService(this._envService);

  Future<LlmApiResponse> getChatCompletion({
    required List<ChatMessage> conversationHistory,
    required List<ToolDefinition> tools, // <--- 수정됨: Non-nullable로 변경 (사용자 제안 3번)
    String? toolChoice,
    bool usePrimaryModel = true,
    double temperature = 0.7,
    int? maxCompletionTokensOverride,
    ResponseFormat? responseFormat,
  }) async {
    final apiKey = _envService.o3LlmApiKey;
    final modelName = usePrimaryModel ? _envService.primaryLlmModelName : _envService.secondaryLlmModelName;
    final baseUrl = _envService.o3LlmApiEndpoint;

    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $apiKey',
    };

    final messagesForApi = conversationHistory.map((msg) => msg.toJsonForApi()).toList();

    int? effectiveMaxTokens;
    int? effectiveMaxCompletionTokens;

    if (modelName.toLowerCase().startsWith('o3')) {
      effectiveMaxCompletionTokens = maxCompletionTokensOverride ?? 2000;
    } else {
      effectiveMaxTokens = maxCompletionTokensOverride ?? 2000;
    }

    final requestPayload = LlmApiRequest(
      model: modelName,
      messages: messagesForApi,
      // tools 리스트가 비어있으면 null을 전달하여 API 요청에서 제외 (LlmApiRequest의 includeIfNull: false 활용)
      tools: tools.isNotEmpty ? tools : null, // <--- 수정됨
      toolChoice: toolChoice,
      temperature: temperature,
      maxTokens: effectiveMaxTokens,
      maxCompletionTokens: effectiveMaxCompletionTokens,
      responseFormat: responseFormat,
    );

    final String bodyJson = jsonEncode(requestPayload.toJson());

    _log.info("Sending request to LLM ($modelName):");
    _log.fine("Request URL: $baseUrl${AppConstants.chatCompletionsEndpoint}");
    _log.finest("Request Body: $bodyJson");

    try {
      final response = await http.post(
        Uri.parse("$baseUrl${AppConstants.chatCompletionsEndpoint}"),
        headers: headers,
        body: bodyJson,
      );

      final responseBody = utf8.decode(response.bodyBytes);
      _log.info("LLM Response Status: ${response.statusCode}");
      _log.finest("LLM Response Body: $responseBody");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedBody = jsonDecode(responseBody);
        return LlmApiResponse.fromJson(decodedBody);
      } else {
        _log.severe("LLM API request failed with status ${response.statusCode}: $responseBody");
        try {
          final decodedErrorBody = jsonDecode(responseBody);
          if (decodedErrorBody['error'] != null) {
            return LlmApiResponse.fromJson(decodedErrorBody);
          }
        } catch (e) {
          _log.warning("Failed to parse JSON error response from LLM: $e");
        }
        throw Exception(
            'LLM API request failed (Status ${response.statusCode}): $responseBody');
      }
    } catch (e, stackTrace) {
      _log.severe('Error calling LLM API or processing response: $e', e, stackTrace);
      return LlmApiResponse(
        error: LlmApiError(
          message: "Network or parsing error: $e",
          type: "client_side_error",
        ),
      );
    }
  }
}