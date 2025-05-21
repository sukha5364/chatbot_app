// 파일 경로: lib/features/chat/presentation/widgets/chat_input_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/features/chat/providers/chat_providers.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt; // STT 구현 시 필요

class ChatInputField extends ConsumerStatefulWidget {
  final Function(String) onSendMessage;
  final FocusNode focusNode;

  const ChatInputField({
    super.key,
    required this.onSendMessage,
    required this.focusNode,
  });

  @override
  ConsumerState<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends ConsumerState<ChatInputField> {
  final _textController = TextEditingController();
  // final stt.SpeechToText _speech = stt.SpeechToText(); // STT 구현 시 필요
  // bool _isListening = false; // STT 구현 시 필요

  @override
  void initState() {
    super.initState();
    // _initializeSpeech(); // STT 초기화
  }


  void _handleSend() {
    if (_textController.text.trim().isNotEmpty) {
      widget.onSendMessage(_textController.text.trim());
      _textController.clear();
      widget.focusNode.requestFocus(); // 전송 후에도 포커스 유지
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isVoiceActive = ref.watch(voiceRecognitionActiveProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withAlpha((255 * 0.05).round()), // withOpacity 대체
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: <Widget>[
            IconButton(
              icon: Icon(isVoiceActive ? Icons.mic_off : Icons.mic_none_outlined, color: theme.colorScheme.primary),
              onPressed: () {
                // TODO: STT 기능 연결 (Phase 7)
                ref.read(voiceRecognitionActiveProvider.notifier).update((state) => !state);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar( // const 추가
                      content: Text("음성 인식 기능은 추후 구현 예정입니다."),
                      duration: Duration(seconds: 2),
                    )
                );
              },
              tooltip: "음성 입력",
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: const InputDecoration( // const 추가
                  hintText: '메시지를 입력하세요...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: theme.textTheme.bodyLarge,
                maxLines: 5,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.send, color: theme.colorScheme.primary),
              onPressed: _handleSend,
              tooltip: "전송",
            ),
          ],
        ),
      ),
    );
  }
}