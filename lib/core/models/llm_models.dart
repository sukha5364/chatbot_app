// 파일 경로: lib/core/models/llm_models.dart
// ignore_for_file: invalid_annotation_target
import 'package:decathlon_demo_app/core/models/chat_message.dart'; // ⬅️ 추가된 import
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_models.freezed.dart';
part 'llm_models.g.dart';

// Helper functions for List<ToolDefinition>
List<ToolDefinition>? _toolDefinitionListFromJson(List<dynamic>? json) =>
    json?.map((e) => ToolDefinition.fromJson(e as Map<String, dynamic>)).toList();

List<Map<String, dynamic>>? _toolDefinitionListToJson(List<ToolDefinition>? list) =>
    list?.map((e) => e.toJson()).toList();

// Helper functions for Map<String, FunctionParameterProperty>
Map<String, FunctionParameterProperty> _propertyMapFromJson(Map<String, dynamic> json) =>
    json.map((k, v) => MapEntry(k, FunctionParameterProperty.fromJson(v as Map<String, dynamic>)));

Map<String, dynamic> _propertyMapToJson(Map<String, FunctionParameterProperty> map) =>
    map.map((k, v) => MapEntry(k, v.toJson()));


@freezed
class LlmApiRequest with _$LlmApiRequest {
  const factory LlmApiRequest({
    required String model,
    required List<Map<String, dynamic>> messages,
    @JsonKey(
        includeIfNull: false,
        fromJson: _toolDefinitionListFromJson,
        toJson: _toolDefinitionListToJson
    )
    List<ToolDefinition>? tools,
    @JsonKey(name: 'tool_choice', includeIfNull: false) dynamic toolChoice,
    @JsonKey(includeIfNull: false) double? temperature,
    @JsonKey(name: 'max_tokens', includeIfNull: false) int? maxTokens,
    @JsonKey(name: 'max_completion_tokens', includeIfNull: false) int? maxCompletionTokens,
    @JsonKey(name: 'response_format', includeIfNull: false) ResponseFormat? responseFormat,
  }) = _LlmApiRequest;

  factory LlmApiRequest.fromJson(Map<String, dynamic> json) =>
      _$LlmApiRequestFromJson(json);
}

@freezed
class LlmApiResponse with _$LlmApiResponse {
  const factory LlmApiResponse({
    String? id,
    String? object,
    int? created,
    String? model,
    List<LlmChoice>? choices,
    Usage? usage,
    @JsonKey(name: 'system_fingerprint') String? systemFingerprint,
    LlmApiError? error,
  }) = _LlmApiResponse;

  factory LlmApiResponse.fromJson(Map<String, dynamic> json) =>
      _$LlmApiResponseFromJson(json);
}

@freezed
class LlmChoice with _$LlmChoice {
  const factory LlmChoice({
    required int index,
    required ChatMessage message,
    @JsonKey(name: 'finish_reason') String? finishReason,
    @JsonKey(name: 'logprobs', includeIfNull: false) dynamic logprobs,
  }) = _LlmChoice;

  factory LlmChoice.fromJson(Map<String, dynamic> json) =>
      _$LlmChoiceFromJson(json);
}

@freezed
class Usage with _$Usage {
  const factory Usage({
    @JsonKey(name: 'prompt_tokens') required int promptTokens,
    @JsonKey(name: 'completion_tokens') int? completionTokens,
    @JsonKey(name: 'total_tokens') required int totalTokens,
  }) = _Usage;

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);
}

@freezed
class ToolDefinition with _$ToolDefinition {
  const factory ToolDefinition({
    required String type,
    required FunctionDefinition function,
  }) = _ToolDefinition;

  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      _$ToolDefinitionFromJson(json);
}

@freezed
class FunctionDefinition with _$FunctionDefinition {
  const factory FunctionDefinition({
    required String name,
    String? description,
    @JsonKey(includeIfNull: false) FunctionParameters? parameters,
  }) = _FunctionDefinition;

  factory FunctionDefinition.fromJson(Map<String, dynamic> json) =>
      _$FunctionDefinitionFromJson(json);
}

@freezed
class FunctionParameters with _$FunctionParameters {
  const factory FunctionParameters({
    required String type,
    @JsonKey(
      fromJson: _propertyMapFromJson,
      toJson: _propertyMapToJson,
    )
    required Map<String, FunctionParameterProperty> properties,
    @Default([]) List<String> required,
  }) = _FunctionParameters;

  factory FunctionParameters.fromJson(Map<String, dynamic> json) =>
      _$FunctionParametersFromJson(json);
}

@freezed
class FunctionParameterProperty with _$FunctionParameterProperty {
  const factory FunctionParameterProperty({
    required String type,
    @JsonKey(includeIfNull: false) String? description,
    @JsonKey(name: 'enum', includeIfNull: false) List<String>? enumValues,
    @JsonKey(includeIfNull: false) FunctionParameterItems? items,
  }) = _FunctionParameterProperty;

  factory FunctionParameterProperty.fromJson(Map<String, dynamic> json) =>
      _$FunctionParameterPropertyFromJson(json);
}

@freezed
class FunctionParameterItems with _$FunctionParameterItems {
  const factory FunctionParameterItems({
    required String type,
    @JsonKey(name: 'enum', includeIfNull: false) List<String>? enumValues,
  }) = _FunctionParameterItems;

  factory FunctionParameterItems.fromJson(Map<String, dynamic> json) =>
      _$FunctionParameterItemsFromJson(json);
}

@freezed
class ResponseFormat with _$ResponseFormat {
  const factory ResponseFormat({
    required String type,
  }) = _ResponseFormat;

  factory ResponseFormat.fromJson(Map<String, dynamic> json) =>
      _$ResponseFormatFromJson(json);
}

@freezed
class LlmApiError with _$LlmApiError {
  const factory LlmApiError({
    String? message,
    String? type,
    String? param,
    String? code,
  }) = _LlmApiError;

  factory LlmApiError.fromJson(Map<String, dynamic> json) =>
      _$LlmApiErrorFromJson(json);
}

@freezed
class ToolChoiceRequest with _$ToolChoiceRequest {
  const factory ToolChoiceRequest({
    required String type,
    required ToolChoiceFunction function,
  }) = _ToolChoiceRequest;

  factory ToolChoiceRequest.fromJson(Map<String, dynamic> json) =>
      _$ToolChoiceRequestFromJson(json);
}

@freezed
class ToolChoiceFunction with _$ToolChoiceFunction {
  const factory ToolChoiceFunction({
    required String name,
  }) = _ToolChoiceFunction;

  factory ToolChoiceFunction.fromJson(Map<String, dynamic> json) =>
      _$ToolChoiceFunctionFromJson(json);
}