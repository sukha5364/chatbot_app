// lib/core/models/chat_message.dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

// Helper functions for toolCalls serialization
List<ToolCall>? _toolCallListFromJson(List<dynamic>? json) =>
    json?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>)).toList();

List<Map<String, dynamic>>? _toolCallListToJson(List<ToolCall>? list) =>
    list?.map((e) => e.toJson()).toList();

// Helper functions for MessageRole serialization
String _messageRoleToJson(MessageRole role) => role.name.toLowerCase();
MessageRole _messageRoleFromJson(String roleStr) =>
    MessageRole.values.firstWhere((e) => e.name.toLowerCase() == roleStr.toLowerCase(),
        orElse: () => MessageRole.system); // 기본값 또는 오류 처리 필요 시 수정

@freezed
class ChatMessage with _$ChatMessage {
  const ChatMessage._(); // Private constructor for implementing toJsonForApi

  const factory ChatMessage({
    @JsonKey(
        name: 'role',
        toJson: _messageRoleToJson,
        fromJson: _messageRoleFromJson)
    required MessageRole role,
    @JsonKey(includeIfNull: false) String? content,
    @JsonKey(
        name: 'tool_calls',
        includeIfNull: false,
        fromJson: _toolCallListFromJson,
        toJson: _toolCallListToJson)
    List<ToolCall>? toolCalls,
    @JsonKey(name: 'tool_call_id', includeIfNull: false) String? toolCallId,
    @JsonKey(includeIfNull: false) String? name, // 주로 tool 역할 메시지에서 함수명으로 사용
    DateTime? timestamp, // ✨ 타임스탬프 필드 추가
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// OpenAI API 요청 형식에 맞는 JSON으로 변환합니다.
  /// Freezed가 생성하는 toJson은 모든 필드를 포함하므로, API 스펙에 맞게 선택적으로 필드를 포함하는 메서드입니다.
  Map<String, dynamic> toJsonForApi() {
    final Map<String, dynamic> jsonOutput = {
      'role': _messageRoleToJson(role),
    };
    // content는 null일 수 있지만, 빈 문자열은 아닐 경우에만 포함 (OpenAI는 content: null 허용)
    if (content != null) {
      jsonOutput['content'] = content;
    }
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      jsonOutput['tool_calls'] = _toolCallListToJson(toolCalls);
    }
    if (toolCallId != null) {
      jsonOutput['tool_call_id'] = toolCallId;
    }
    if (name != null) { // role이 'tool'일 때 주로 사용
      jsonOutput['name'] = name;
    }
    // timestamp는 API 요청 본문에는 포함되지 않으므로 여기서 제외합니다.
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
    required String id, // 각 tool_call에 대한 고유 ID
    required String type, // 현재는 "function"만 해당
    required FunctionCallData function,
  }) = _ToolCall;

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      _$ToolCallFromJson(json);
}

@freezed
class FunctionCallData with _$FunctionCallData {
  const factory FunctionCallData({
    required String name, // 호출할 함수의 이름
    required String arguments, // 함수에 전달할 인자 (JSON 문자열 형태)
  }) = _FunctionCallData;

  factory FunctionCallData.fromJson(Map<String, dynamic> json) =>
      _$FunctionCallDataFromJson(json);
}