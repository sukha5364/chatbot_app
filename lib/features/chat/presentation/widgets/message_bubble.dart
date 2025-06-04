// 파일 경로: lib/features/chat/presentation/widgets/message_bubble.dart
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:flutter/material.dart';

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
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    Widget messagePrimaryContent;

    // Tool call messages
    if (message.role == MessageRole.tool) {
      messagePrimaryContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🛠️ Function Call Result: ${message.name ?? 'N/A'}",
            style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withAlpha((255 * 0.8).round()),
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Text(
            message.content ?? '(No content for tool message)',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor.withAlpha((255 * 0.9).round())),
          ),
        ],
      );
    }
    // Assistant requests for tool calls
    else if (message.toolCalls != null && message.toolCalls!.isNotEmpty) {
      messagePrimaryContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.content != null && message.content!.isNotEmpty) ...[
            Text(message.content!, style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
            const SizedBox(height: 6),
          ],
          Text(
            "Function Calls Requested:",
            style: theme.textTheme.labelSmall?.copyWith(color: textColor.withAlpha((255 * 0.8).round())),
          ),
          ...message.toolCalls!.map((tc) => Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 8.0),
            child: Text("  - ${tc.function.name}(...)", style: theme.textTheme.labelSmall?.copyWith(color: textColor, fontStyle: FontStyle.italic)),
          )),
        ],
      );
    }
    // Regular text content
    else {
      messagePrimaryContent = Text(
        message.content ?? '(메시지 내용 없음)',
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      );
    }

    // Image display logic
    Widget? imageWidget;
    if (message.localImagePath != null && message.localImagePath!.isNotEmpty) {
      try {
        imageWidget = Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6, // 이미지 최대 너비
              maxHeight: 200, // 이미지 최대 높이
            ),
            child: ClipRRect( // 이미지 모서리 둥글게
              borderRadius: BorderRadius.circular(12.0),
              child: Image.asset(
                message.localImagePath!,
                fit: BoxFit.cover, // 이미지가 영역에 맞게 채워지도록
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 50,
                    color: Colors.grey[300],
                    child: Center(
                      child: Text(
                        '이미지 로드 실패',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      } catch (e) {
        // Log error or handle appropriately
        imageWidget = Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('[이미지 표시 오류: ${e.toString()}]', style: TextStyle(color: Colors.red[700], fontSize: 12)),
        );
      }
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
                  color: Colors.black.withAlpha((255 * 0.05).round()),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ]
          ),
          child: Column( // Image and text content arranged vertically
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // Align content to the start
            children: [
              if (imageWidget != null) imageWidget,
              messagePrimaryContent,
            ],
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            _roleToDisplayString(message.role),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha((255 * 0.6).round())),
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
    }
  }
}