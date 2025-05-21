// 파일 경로: lib/features/chat/presentation/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/features/auth/providers/auth_providers.dart';
import 'package:decathlon_demo_app/features/chat/providers/chat_providers.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:decathlon_demo_app/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:decathlon_demo_app/features/chat/presentation/widgets/qr_display_dialog.dart';
import 'package:decathlon_demo_app/features/auth/presentation/login_screen.dart'; // 로그아웃 시 이동
import 'package:decathlon_demo_app/core/constants/app_constants.dart'; // <--- 추가된 import
import 'package:logging/logging.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final _log = Logger('ChatScreen');

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 채팅 초기화 (첫 인사 메시지 등)
    // 위젯이 빌드된 후에 ref를 사용해야 안전합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 현재 사용자 프로필 확인
      final currentUser = ref.read(currentUserProfileProvider);
      if (currentUser == null) {
        _log.warning("ChatScreen loaded but user is null. Redirecting to login.");
        // 안전하게 로그인 화면으로 리디렉션
        if (mounted) { // initState에서 context 사용 시 mounted 확인
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
          );
        }
        return;
      }
      // 채팅 오케스트레이터에게 채팅 초기화 요청
      ref.read(chatOrchestrationServiceProvider).initializeChat();
      _log.info("ChatScreen initialized and requested chat initialization.");
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // 약간의 지연을 주어 리스트가 업데이트된 후 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;
    _log.info("User sending message: $text");
    ref.read(chatOrchestrationServiceProvider).processUserMessage(text);
    // 메시지 전송 후 즉시 스크롤 (사용자 메시지 표시용)
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final currentUser = ref.watch(currentUserProfileProvider);

    // QR 코드 데이터가 변경되면 다이얼로그 표시
    ref.listen<String?>(qrCodeDataProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        _log.info("QR code data received, showing dialog: $next");
        showQrDialog(context, next, "주문 QR 코드");
        // 다이얼로그 표시 후 상태 초기화 (선택적: 사용자가 직접 닫도록 둘 수도 있음)
        // ref.read(qrCodeDataProvider.notifier).state = null;
      }
    });

    // 메시지 목록이 변경될 때마다 스크롤 (챗봇 응답 포함)
    ref.listen<List<ChatMessage>>(chatMessagesProvider, (_, __) {
      _scrollToBottom();
    });

    if (currentUser == null) {
      // initState에서 리디렉션하지만, 빌드 중에도 한번 더 체크
      _log.warning("Build: currentUser is null, showing loading or placeholder.");
      // 로그인 화면으로 리디렉션하는 것이 더 나을 수 있지만, 일단 로딩으로 표시
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentUser.name.isNotEmpty ? "${currentUser.name}님과의 대화" : AppConstants.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "로그아웃",
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
              // 채팅 메시지 초기화
              ref.read(chatMessagesProvider.notifier).clearMessages();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messages.isEmpty
                ? Center(
              child: Text(
                "무엇을 도와드릴까요?",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: MessageBubble(
                    message: message,
                    isCurrentUser: message.role == MessageRole.user,
                  ),
                );
              },
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(minHeight: 2), // 좀 더 얇은 로딩 바
            ),
          ChatInputField(
            onSendMessage: _handleSendMessage,
            focusNode: _inputFocusNode,
          ),
        ],
      ),
    );
  }
}