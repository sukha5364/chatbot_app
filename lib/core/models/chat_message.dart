// 파일 경로: lib/core/models/chat_message.dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

// Helper functions for toolCalls serialization
List<ToolCall>? _toolCallListFromJson(List<dynamic>? json) =>
    json?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>)).toList();

List<Map<String, dynamic>>? _toolCallListToJson(List<ToolCall>? list) =>
    list?.map((e) => e.toJson()).toList();


String _messageRoleToJson(MessageRole role) => role.name.toLowerCase();
MessageRole _messageRoleFromJson(String roleStr) =>
    MessageRole.values.firstWhere((e) => e.name.toLowerCase() == roleStr.toLowerCase(),
        orElse: () => MessageRole.system);

@freezed
class ChatMessage with _$ChatMessage {
  const ChatMessage._();

  const factory ChatMessage({
    @JsonKey(
        name: 'role',
        toJson: _messageRoleToJson,
        fromJson: _messageRoleFromJson
    )
    required MessageRole role,
    @JsonKey(includeIfNull: false) String? content,
    @JsonKey(
      name: 'tool_calls',
      includeIfNull: false,
      fromJson: _toolCallListFromJson,
      toJson: _toolCallListToJson,
    )
    List<ToolCall>? toolCalls,
    @JsonKey(name: 'tool_call_id', includeIfNull: false) String? toolCallId,
    @JsonKey(includeIfNull: false) String? name,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  Map<String, dynamic> toJsonForApi() {
    final Map<String, dynamic> jsonOutput = {
      'role': _messageRoleToJson(role),
    };
    if (content != null) {
      jsonOutput['content'] = content;
    }
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      jsonOutput['tool_calls'] = _toolCallListToJson(toolCalls);
    }
    if (toolCallId != null) {
      jsonOutput['tool_call_id'] = toolCallId;
    }
    if (name != null) {
      jsonOutput['name'] = name;
    }
    return jsonOutput;
  }
}

enum MessageRole {
  system,
  user,
  assistant,
  tool,
}

@freezed
class ToolCall with _$ToolCall {
  const factory ToolCall({
    required String id,
    required String type,
    required FunctionCallData function,
  }) = _ToolCall;

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      _$ToolCallFromJson(json);
}

@freezed
class FunctionCallData with _$FunctionCallData {
  const factory FunctionCallData({
    required String name,
    required String arguments,
  }) = _FunctionCallData;

  factory FunctionCallData.fromJson(Map<String, dynamic> json) =>
      _$FunctionCallDataFromJson(json);
}