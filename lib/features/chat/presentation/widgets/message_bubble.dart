// 파일 경로: lib/features/chat/presentation/widgets/message_bubble.dart
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:flutter/material.dart';
// import 'package:decathlon_demo_app/core/theme/app_theme.dart'; // 사용되지 않아 삭제

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isCurrentUser
        ? theme.colorScheme.primary
    // : theme.colorScheme.surfaceVariant; // 이전 코드
        : theme.colorScheme.surfaceContainerHighest; // surfaceVariant -> surfaceContainerHighest
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimary
    // : theme.colorScheme.onSurfaceVariant; // onSurfaceVariant 는 onSurfaceContainerHighest 와 쌍이 아닐 수 있음
        : theme.colorScheme.onSurface; // onSurfaceContainerHighest의 텍스트는 보통 onSurface

    Widget messageContent;

    if (message.role == MessageRole.tool) {
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🛠️ Function Call: ${message.name ?? 'N/A'}",
            style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withAlpha((255 * 0.8).round()), // withOpacity 대체
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Text(
            message.content ?? '(No content for tool message)',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor.withAlpha((255 * 0.9).round())), // withOpacity 대체
          ),
        ],
      );
    } else if (message.toolCalls != null && message.toolCalls!.isNotEmpty) {
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.content != null && message.content!.isNotEmpty) ...[
            Text(message.content!, style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
            const SizedBox(height: 6),
          ],
          Text(
            "Function Calls Requested:",
            style: theme.textTheme.labelSmall?.copyWith(color: textColor.withAlpha((255 * 0.8).round())), // withOpacity 대체
          ),
          ...message.toolCalls!.map((tc) => Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 8.0),
            child: Text("  - ${tc.function.name}(...)", style: theme.textTheme.labelSmall?.copyWith(color: textColor, fontStyle: FontStyle.italic)),
          )),
        ],
      );
    }
    else {
      messageContent = Text(
        message.content ?? '(메시지 내용 없음)',
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      );
    }

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isCurrentUser ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isCurrentUser ? const Radius.circular(4) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.05).round()), // withOpacity 대체
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ]
          ),
          child: messageContent,
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            _roleToDisplayString(message.role),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha((255 * 0.6).round())), // onBackground -> onSurface, withOpacity 대체
          ),
        )
      ],
    );
  }

  String _roleToDisplayString(MessageRole role) {
    switch (role) {
      case MessageRole.user: return "나";
      case MessageRole.assistant: return "데카트론 AI";
      case MessageRole.tool: return "Function Result";
      case MessageRole.system: return "System";
    // 모든 MessageRole 열거형 값이 case로 처리되었으므로 default는 제거 (unreachable_switch_default 경고 해결)
    }
  }
}