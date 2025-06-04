// lib/features/chat/services/chat_orchestration_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/core/models/llm_models.dart';
import 'package:decathlon_demo_app/core/models/user_profile.dart';
import 'package:decathlon_demo_app/core/models/api_models.dart' as api_models;
import 'package:decathlon_demo_app/core/services/o3_llm_service.dart';
import 'package:decathlon_demo_app/core/services/mock_api_service.dart'; // 직접 사용하지 않음 (ToolRegistry 통해)
import 'package:decathlon_demo_app/features/chat/providers/chat_providers.dart';
import 'package:decathlon_demo_app/core/config/app_config.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart';
import 'package:decathlon_demo_app/background/background_task_queue.dart';
import 'package:decathlon_demo_app/tool_layer/tool_registry.dart';
import 'package:decathlon_demo_app/tool_layer/mock_api_tool_runners.dart';
import 'package:decathlon_demo_app/shared/utils/image_utils.dart'; // ADDED
import 'package:logging/logging.dart';

class ChatOrchestrationService {
  final Ref _ref;
  final O3LlmService _o3LlmService;
  // final MockApiService _mockApiService; // ToolRegistry를 통해 사용하므로 직접 주입 제거 가능
  final UserProfile? _currentUserProfile;
  final AppConfig _appConfig;
  final ToolRegistry _toolRegistry;
  final _log = Logger('ChatOrchestrationService');

  int _currentConversationTurn = 0;
  ToolCall? _pendingToolCallForConfirmation;
  String? _originalUserMessageBeforeConfirmation;

  // 임시로 다음 어시스턴트 메시지에 추가할 이미지 경로 저장
  String? _imagePathForNextAssistantMessage;


  ChatOrchestrationService({
    required Ref ref,
    required O3LlmService o3LlmService,
    required MockApiService mockApiService, // ToolRegistry에 필요하므로 일단 유지 (또는 ToolRegistry가 직접 ref로 접근)
    required AppConfig appConfig,
    required UserProfile? currentUserProfile,
  })  : _ref = ref,
        _o3LlmService = o3LlmService,
  // _mockApiService = mockApiService, // 제거
        _appConfig = appConfig,
        _currentUserProfile = currentUserProfile,
        _toolRegistry = ToolRegistry() {
    _toolRegistry.registerRunners(getAllMockApiToolRunners());
    _log.info("ToolRegistry initialized and all mock API tool runners registered.");
    _log.info("ChatOrchestrationService initialized with ${appConfig.toolDefinitions.length} tool definitions from AppConfig.");
  }

  List<ChatMessage> _buildSystemMessages() {
    _log.fine("Building system messages...");
    String userInfoForPrompt = "현재 사용자는 다음과 같습니다: ";
    if (_currentUserProfile != null) {
      userInfoForPrompt +=
      "ID '${_currentUserProfile.id}', 이름 '${_currentUserProfile.name}', 나이 ${_currentUserProfile.age}세, 성별 '${_currentUserProfile.gender}'. ";
      if (_currentUserProfile.preferredSports.isNotEmpty) {
        userInfoForPrompt +=
        "선호 스포츠는 ${_currentUserProfile.preferredSports.join(', ')} 입니다. ";
      }
      if (_currentUserProfile.otherInfo != null &&
          _currentUserProfile.otherInfo!.isNotEmpty) {
        userInfoForPrompt += "기타 정보: ${_currentUserProfile.otherInfo}. ";
      }
    } else {
      userInfoForPrompt += "비로그인 사용자 또는 정보 없음. ";
    }
    userInfoForPrompt += "모든 답변은 한국어로, 사용자 맞춤형으로 친절하고 상세하게 안내해주세요.";

    final int recentKTurns = _appConfig.recentKTurns;
    final String? currentSummary = _ref.read(currentChatSummaryProvider);
    final Map<String, dynamic>? currentSlots = _ref.read(lastExtractedSlotsProvider);
    final List<ChatMessage> fullHistory = _ref.read(chatMessagesProvider);
    String contextBlock = "\n\n--- 대화 맥락 시작 ---\n";

    if (currentSummary != null && currentSummary.isNotEmpty) {
      contextBlock += "[현재까지 대화 요약]:\n$currentSummary\n\n";
      _log.finest("Added summary to system prompt: ${currentSummary.substring(0, (currentSummary.length > 70 ? 70 : currentSummary.length))}...");
    } else {
      contextBlock += "[현재까지 대화 요약]: 제공된 요약 없음.\n\n";
    }

    if (currentSlots != null && currentSlots.isNotEmpty) {
      try {
        final slotsJson = jsonEncode(currentSlots);
        contextBlock += "[현재까지 추출된 주요 정보 (Slots)]:\n$slotsJson\n\n";
        _log.finest("Added slots to system prompt: $slotsJson");
      } catch (e) {
        _log.warning("Failed to encode slots for system prompt: $e");
        contextBlock += "[현재까지 추출된 주요 정보 (Slots)]: (슬롯 정보 처리 중 오류 발생)\n\n";
      }
    } else {
      contextBlock += "[현재까지 추출된 주요 정보 (Slots)]: 현재 없음.\n\n";
    }

    if (fullHistory.isNotEmpty && recentKTurns > 0) {
      final int messagesToTake = recentKTurns * 3; // user, assistant, tool messages for k turns
      final List<ChatMessage> recentMessages = fullHistory.length > messagesToTake
          ? fullHistory.sublist(fullHistory.length - messagesToTake)
          : fullHistory;
      if (recentMessages.isNotEmpty) {
        contextBlock += "[최근 대화 기록 (${recentMessages.length}개 메시지, 시간순)]:\n";
        for (var msg in recentMessages) {
          if (msg.role == MessageRole.system) continue;
          String roleDisplay = msg.role.name;
          String contentDisplay = msg.content ?? "";
          if (msg.role == MessageRole.tool) {
            String toolName = msg.name ?? "unknown_tool";
            try {
              var toolContentMap = jsonDecode(contentDisplay);
              String resultSummary = "결과 받음";
              if(toolContentMap is Map) {
                if (toolContentMap.containsKey('found')) {
                  resultSummary = toolContentMap['found'] == true ? "정보 찾음" : "정보 없음";
                } else if (toolContentMap.containsKey('success')) {
                  resultSummary = toolContentMap['success'] == true ? "성공" : "실패";
                } else if (toolContentMap.containsKey('coupons') && toolContentMap['coupons'] is List) {
                  resultSummary = "${(toolContentMap['coupons'] as List).length}개 쿠폰";
                } else if (toolContentMap.containsKey('error')) {
                  resultSummary = "오류: ${toolContentMap['error']}";
                }
              }
              contentDisplay = "Tool($toolName) $resultSummary";
            } catch (e) {
              contentDisplay = "Tool($toolName) 결과 (파싱 불가)";
            }
          } else if (msg.role == MessageRole.assistant && msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
            final callsSummary = msg.toolCalls!.map((tc) => tc.function.name).join(', ');
            contentDisplay = contentDisplay.isNotEmpty ? "$contentDisplay (Tool 호출 요청: $callsSummary)" : "(Tool 호출 요청: $callsSummary)";
          }

          if (contentDisplay.length > 150) {
            contentDisplay = "${contentDisplay.substring(0, 150)}...";
          }
          contextBlock += "$roleDisplay: $contentDisplay\n";
        }
        _log.finest("Added recent ${recentMessages.length} messages to system prompt's context block.");
      }
    } else {
      contextBlock += "[최근 대화 기록]: 없음.\n";
    }
    contextBlock += "--- 대화 맥락 끝 ---\n";
    String baseSystemPrompt = """
당신은 '데카트론 코리아'의 전문 AI 상담원입니다. 당신의 주요 목표는 고객이 스포츠 활동 및 일상 생활에 필요한 최적의 데카트론 제품을 찾도록 돕는 것입니다.
모든 답변은 한국어로 공손하게 제공해야 합니다.
당신은 아래에 정의된 함수(Tools)들을 사용하여 고객에게 필요한 정보를 제공하거나 요청을 처리할 수 있습니다.
제공된 함수들의 설명을 잘 읽고, 사용자의 질문 의도에 가장 적합한 함수를 선택하여 호출해야 합니다.
함수 호출 시에는 'parameters'에 정의된 모든 'required' 인자들을 반드시 포함해야 하며, 각 인자의 타입과 설명을 준수해야 합니다.
만약 여러 단계의 함수 호출이 필요하다면, 순차적으로 호출하고 그 결과를 종합하여 최종 답변을 생성해주세요.
'displayImage' 파라미터가 있는 함수의 경우, 제품 이미지를 보여주는 것이 사용자에게 도움이 된다고 판단되면 해당 파라미터를 true로 설정하여 호출할 수 있습니다.
결제(generateOrderQRCode) 등 민감한 작업 전에는 사용자에게 내용을 요약하여 채팅창에서 텍스트로 재확인 질문을 하고, 사용자의 긍정적인 답변('네', '맞아요' 등)을 받은 후에 해당 함수를 호출하도록 유도해야 합니다. (주의: 당신이 직접 함수를 호출하는 것이 아니라, 사용자에게 확인을 요청하는 메시지를 생성해야 합니다.)

$userInfoForPrompt
$contextBlock
사용자의 현재 질문에 대해 답변해주세요.
    """;
    return [ChatMessage(role: MessageRole.system, content: baseSystemPrompt.trim())];
  }

  Future<void> processUserMessage(String userInput) async {
    if (_currentUserProfile == null) {
      _ref.read(chatMessagesProvider.notifier).addMessage(const ChatMessage(role: MessageRole.assistant, content: "로그인 정보가 없습니다. 먼저 로그인해주세요.", timestamp: null));
      return;
    }

    _ref.read(chatLoadingProvider.notifier).state = true;
    final userMessage = ChatMessage(role: MessageRole.user, content: userInput, timestamp: DateTime.now());
    _ref.read(chatMessagesProvider.notifier).addMessage(userMessage);
    _currentConversationTurn++;

    if (_pendingToolCallForConfirmation != null) {
      await _handlePendingConfirmation(userInput, userMessage);
      _ref.read(chatLoadingProvider.notifier).state = false;
      return;
    }

    final BackgroundTaskQueue queue = _ref.read(backgroundTaskQueueProvider);
    bool bgtQueueReady = false;
    try {
      await queue.initialize().timeout(const Duration(seconds: 20));
      bgtQueueReady = true;
      await queue.requestSlotExtraction(userInput);
      _log.info("Requested slot extraction in background for: $userInput");
    } on TimeoutException catch(e,s) {
      _log.severe("Timeout initializing BackgroundTaskQueue or requesting slot extraction. Proceeding without slot extraction for this turn.", e, s);
      _ref.read(backgroundTaskErrorProvider.notifier).state = "백그라운드 작업 초기화 시간 초과. 슬롯 추출이 지연될 수 있습니다.";
    } catch (e,s) {
      _log.severe("Failed to initialize BackgroundTaskQueue or request slot extraction. Proceeding without slot extraction for this turn.", e, s);
      _ref.read(backgroundTaskErrorProvider.notifier).state = "백그라운드 작업 오류. 슬롯 추출이 지연될 수 있습니다.";
    }

    List<ChatMessage> messagesForLlm = _ref.read(chatMessagesProvider);
    List<ChatMessage> systemAndContextMessages = _buildSystemMessages();
    messagesForLlm = [...systemAndContextMessages, ...messagesForLlm.where((m) => m.role != MessageRole.system)];

    List<ToolDefinition> availableTools = _appConfig.toolDefinitions;
    _log.fine("Using ${availableTools.length} tool definitions from AppConfig for LLM call.");


    for (int i = 0; i < _appConfig.maxToolIterations; i++) {
      _log.info("Sending request to LLM (Iteration ${i + 1}/${_appConfig.maxToolIterations}). Message count for LLM: ${messagesForLlm.length}");
      _log.finest("Messages for LLM (Iter ${i+1}): ${messagesForLlm.map((m) => '${m.role.name}: ${m.content?.substring(0, (m.content?.length ?? 0) > 70 ? 70 : (m.content?.length ?? 0))}...').toList()}");
      LlmApiResponse llmResponse;
      try {
        llmResponse = await _o3LlmService.getChatCompletion(
          conversationHistory: messagesForLlm,
          tools: availableTools,
          toolChoice: "auto",
          usePrimaryModel: true,
          temperature: (i == 0) ? _appConfig.toolDecisionTemperature : _appConfig.finalResponseTemperature,
          maxCompletionTokensOverride: (i == 0) ? _appConfig.toolDecisionMaxTokens : _appConfig.finalResponseMaxTokens,
        );
      } catch (e, stackTrace) {
        _log.severe("LLM API call failed in iteration ${i+1}: $e", e, stackTrace);
        _addAssistantErrorMessage("죄송합니다, 현재 서비스와 연결할 수 없습니다. (오류 ID: ${_currentConversationTurn}-${i+1})");
        _ref.read(chatLoadingProvider.notifier).state = false;
        return;
      }
      if (llmResponse.error != null) {
        _log.warning("LLM API returned an error in iteration ${i+1}: ${llmResponse.error?.message}");
        _addAssistantErrorMessage("죄송합니다, 요청 처리 중 오류가 발생했습니다. (LLM: ${llmResponse.error?.message})");
        break;
      }

      if (llmResponse.choices == null || llmResponse.choices!.isEmpty) {
        _log.warning("LLM returned no choices in iteration ${i+1}.");
        _addAssistantErrorMessage("죄송합니다, 답변을 생성할 수 없습니다. 다른 질문을 해주시겠어요?");
        break;
      }

      final LlmChoice firstChoice = llmResponse.choices!.first;
      ChatMessage assistantMessageFromLlm = firstChoice.message.copyWith(timestamp: DateTime.now());


      if (firstChoice.finishReason == "tool_calls" && assistantMessageFromLlm.toolCalls != null && assistantMessageFromLlm.toolCalls!.isNotEmpty) {
        _log.info("LLM requested ${assistantMessageFromLlm.toolCalls!.length} tool call(s) in iteration ${i + 1}.");
        _ref.read(chatMessagesProvider.notifier).addMessage(assistantMessageFromLlm); // Add assistant message requesting tool call
        messagesForLlm.add(assistantMessageFromLlm);

        List<ChatMessage> toolResultMessages = [];
        bool confirmationRequested = false;

        for (ToolCall toolCall in assistantMessageFromLlm.toolCalls!) {
          _log.info("Processing tool call: ID='${toolCall.id}', Function='${toolCall.function.name}'");
          _log.fine("Function arguments: ${toolCall.function.arguments}");

          Map<String, dynamic> toolCallArgumentsMap;
          try {
            toolCallArgumentsMap = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          } catch (e) {
            _log.severe("Failed to parse tool call arguments for ${toolCall.function.name}: $e");
            toolResultMessages.add(ChatMessage(
              role: MessageRole.tool,
              toolCallId: toolCall.id,
              name: toolCall.function.name,
              content: jsonEncode({"error": "Argument parsing failed: $e", "raw_arguments": toolCall.function.arguments}),
              timestamp: DateTime.now(),
            ));
            continue;
          }

          // Check for displayImage flag in tool call arguments
          bool llmWantsImageDisplay = toolCallArgumentsMap['displayImage'] == true;

          if (toolCall.function.name == "generateOrderQRCode") {
            _log.info("Confirmation required for 'generateOrderQRCode'. Storing tool call and requesting confirmation message from LLM.");
            _pendingToolCallForConfirmation = toolCall;
            _originalUserMessageBeforeConfirmation = userInput;

            final String orderDetailsSummary = _summarizeOrderForConfirmation(toolCall.function.arguments);

            List<ChatMessage> confirmationPromptMessages = List.from(messagesForLlm);
            confirmationPromptMessages.add(ChatMessage(
                role: MessageRole.user,
                content: "방금 요청한 'generateOrderQRCode' 함수 실행 전에 사용자에게 다음 내용으로 QR 코드 생성을 진행할지 확인하는 질문을 해주세요: \"$orderDetailsSummary\". 사용자가 '네' 또는 '아니오'로 답변하도록 유도해주세요.",
                timestamp: DateTime.now()
            ));
            LlmApiResponse confirmationQuestionResponse;
            try {
              confirmationQuestionResponse = await _o3LlmService.getChatCompletion(
                conversationHistory: confirmationPromptMessages,
                tools: const [], // No tools for this confirmation question
                toolChoice: "none",
                usePrimaryModel: true,
                temperature: _appConfig.finalResponseTemperature,
                maxCompletionTokensOverride: _appConfig.finalResponseMaxTokens,
              );
            } catch (e, s) {
              _log.severe("LLM call for confirmation question failed.", e, s);
              _addAssistantErrorMessage("주문 확인 중 오류가 발생했습니다. 다시 시도해주세요.");
              _clearPendingConfirmation();
              confirmationRequested = true;
              break;
            }

            if (confirmationQuestionResponse.choices != null && confirmationQuestionResponse.choices!.isNotEmpty) {
              final confirmationMsgContent = confirmationQuestionResponse.choices!.first.message.content;
              if (confirmationMsgContent != null && confirmationMsgContent.isNotEmpty) {
                _addAssistantMessage(confirmationMsgContent);
              } else {
                _addAssistantErrorMessage("주문 내용을 확인해주세요. 진행하시겠습니까? (네/아니오)");
              }
            } else {
              _addAssistantErrorMessage("주문 내용을 확인해주세요. 진행하시겠습니까? (네/아니오)");
            }
            confirmationRequested = true;
            break;
          }

          String toolResultJson;
          Map<String, dynamic> toolResultData;
          try {
            toolResultData = await _toolRegistry.executeTool(toolCall.function.name, toolCall.function.arguments, _ref);
            toolResultJson = jsonEncode(toolResultData);

            if (toolCall.function.name == "generateOrderQRCode") {
              final qrResponse = api_models.GenerateOrderQRCodeResponse.fromJson(toolResultData);
              if (qrResponse.success && qrResponse.qrCodeData != null) {
                _ref.read(qrCodeDataProvider.notifier).state = qrResponse.qrCodeData;
              }
            }
            // If LLM requested image display and the tool is product-related, try to get image path
            if (llmWantsImageDisplay && (toolCall.function.name == 'getProductInfo' || toolCall.function.name == 'recommendProductsByFeatures')) {
              String? imageIdentifier;
              if (toolCall.function.name == 'getProductInfo') {
                var productInfo = api_models.GetProductInfoResponse.fromJson(toolResultData);
                imageIdentifier = productInfo.imageUrl; // imageUrl from API response is the key
              } else if (toolCall.function.name == 'recommendProductsByFeatures') {
                var recommendations = api_models.RecommendProductsByFeaturesResponse.fromJson(toolResultData);
                if (recommendations.products.isNotEmpty) {
                  imageIdentifier = recommendations.products.first.imageUrl; // imageUrl from API response is the key
                }
              }
              if (imageIdentifier != null) {
                _imagePathForNextAssistantMessage = getProductImagePath(imageIdentifier);
                _log.info("Image path determined for next message: $_imagePathForNextAssistantMessage based on identifier: $imageIdentifier");
              }
            }

          } catch (e, stackTrace) {
            _log.severe("Error executing tool via ToolRegistry ${toolCall.function.name}: $e", e, stackTrace);
            toolResultJson = jsonEncode({"error": "ToolRegistry execution failed: $e", "function_name": toolCall.function.name});
          }

          _log.fine("Tool '${toolCall.function.name}' (ID: ${toolCall.id}) result: ${toolResultJson.substring(0, (toolResultJson.length > 100 ? 100 : toolResultJson.length))}...");
          toolResultMessages.add(ChatMessage(
            role: MessageRole.tool,
            toolCallId: toolCall.id,
            name: toolCall.function.name,
            content: toolResultJson,
            timestamp: DateTime.now(),
          ));
        }

        if (confirmationRequested) {
          _ref.read(chatLoadingProvider.notifier).state = false;
          return;
        }

        if (toolResultMessages.isNotEmpty) {
          _ref.read(chatMessagesProvider.notifier).addMessages(toolResultMessages);
          messagesForLlm.addAll(toolResultMessages);
        }

      } else if (assistantMessageFromLlm.content != null && assistantMessageFromLlm.content!.isNotEmpty) {
        _log.info("LLM provided final text response in iteration ${i + 1}.");
        // Add the image path to this final assistant message if it was determined from a previous tool call
        final finalAssistantMessage = assistantMessageFromLlm.copyWith(
            localImagePath: _imagePathForNextAssistantMessage,
            timestamp: DateTime.now() // Ensure timestamp is fresh
        );
        _ref.read(chatMessagesProvider.notifier).addMessage(finalAssistantMessage);
        _imagePathForNextAssistantMessage = null; // Reset the flag
        break;
      } else {
        _log.warning("LLM response in iteration ${i + 1} had neither tool_calls nor content. Finishing turn with a generic message.");
        _addAssistantErrorMessage("음... 제가 어떻게 도와드려야 할지 잘 모르겠어요. 다시 한번 말씀해주시겠어요?");
        _imagePathForNextAssistantMessage = null; // Reset
        break;
      }

      if (i == _appConfig.maxToolIterations - 1) {
        _log.warning("Max tool iterations reached without satisfactory answer. Sending to CS.");
        _addAssistantErrorMessage("죄송합니다. 즉시 답변을 드리지 못했습니다. 이 내용을 CS 센터로 전달하여, 담당자가 확인 후 연락드리도록 하겠습니다.\nCS 담당자 번호 : XXX-XXXX-XXXX");
        _imagePathForNextAssistantMessage = null; // Reset
        try {
          final userId = _currentUserProfile!.id;
          final apiResponse = await _ref.read(mockApiServiceProvider).reportUnresolvedQuery( // Use ref.read to get MockApiService
            userId: userId,
            userQuestion: userInput,
          );
          final reportPayload = apiResponse.toJson();
          _ref.read(chatMessagesProvider.notifier).addMessage(
            ChatMessage(
              role: MessageRole.tool,
              toolCallId: "reportUnresolvedQuery", // Consistent ID
              name: "reportUnresolvedQuery",
              content: jsonEncode(reportPayload),
              timestamp: DateTime.now(),
            ),
          );
        } catch (e, s) {
          _log.severe("Error calling reportUnresolvedQuery API: $e", e, s);
          _addAssistantErrorMessage("CS 문의 접수 중 오류가 발생했습니다. 다시 시도해주세요.");
        }
      }
    }

    if (bgtQueueReady &&
        _appConfig.summarizationEnabled &&
        _currentConversationTurn > 0 &&
        _currentConversationTurn % _appConfig.summarizeEveryNTurns == 0) {
      _log.info("Requesting conversation summarization in background (Turn: $_currentConversationTurn).");
      try {
        final historyForSummary = List<ChatMessage>.from(_ref.read(chatMessagesProvider))
            .where((m) => m.role != MessageRole.system)
            .map((m) => m.toJsonForApi())
            .toList();
        final previousSummaryForIsolate = _ref.read(currentChatSummaryProvider);
        await queue.requestSummarization(historyForSummary, previousSummaryForIsolate);
      } catch (e,s) {
        _log.severe("Failed to request conversation summarization (possibly due to BGTQ re-init issue). Summarization might be skipped.", e, s);
        _ref.read(backgroundTaskErrorProvider.notifier).state = "백그라운드 작업 오류. 요약 작업이 지연될 수 있습니다.";
      }
    }
    _ref.read(chatLoadingProvider.notifier).state = false;
  }

  Future<void> _handlePendingConfirmation(String userInput, ChatMessage userMessage) async {
    _log.info("Handling user confirmation for pending tool: ${_pendingToolCallForConfirmation?.function.name}. User input: $userInput");
    final pendingCall = _pendingToolCallForConfirmation!;
    final originalToolCallArguments = jsonDecode(pendingCall.function.arguments) as Map<String, dynamic>; // Keep original args
    _clearPendingConfirmation();

    final positiveKeywords = ["네", "네.", "응", "그래", "맞아", "진행", "해주세요", "yes", "ok", "okay", "proceed"];
    final negativeKeywords = ["아니오", "아니요", "아뇨", "취소", "중단", "no", "cancel", "stop"];

    bool confirmed = positiveKeywords.any((kw) => userInput.toLowerCase().contains(kw));
    bool cancelled = negativeKeywords.any((kw) => userInput.toLowerCase().contains(kw));

    List<ChatMessage> messagesForLlm = _ref.read(chatMessagesProvider);
    // Ensure system messages are always prepended for context
    List<ChatMessage> systemAndContextMessages = _buildSystemMessages();
    messagesForLlm = [...systemAndContextMessages, ...messagesForLlm.where((m) => m.role != MessageRole.system)];


    if (confirmed) {
      _log.info("User confirmed tool execution for: ${pendingCall.function.name}");
      _addAssistantMessage("${pendingCall.function.name} 요청을 진행합니다...");

      String toolResultJson;
      Map<String, dynamic> toolResultData;
      try {
        // Execute with original arguments
        toolResultData = await _toolRegistry.executeTool(pendingCall.function.name, jsonEncode(originalToolCallArguments), _ref);
        toolResultJson = jsonEncode(toolResultData);

        if (pendingCall.function.name == "generateOrderQRCode") {
          final qrResponse = api_models.GenerateOrderQRCodeResponse.fromJson(toolResultData);
          if (qrResponse.success && qrResponse.qrCodeData != null) {
            _ref.read(qrCodeDataProvider.notifier).state = qrResponse.qrCodeData;
          } else {
            // Ensure error information is properly propagated if QR generation failed
            toolResultJson = jsonEncode({...toolResultData, "error": qrResponse.message ?? "QR code generation failed but no specific message."});
          }
        }
        // Check if this confirmed tool call should also lead to an image display
        bool llmWantsImageDisplay = originalToolCallArguments['displayImage'] == true;
        if (llmWantsImageDisplay && (pendingCall.function.name == 'getProductInfo' || pendingCall.function.name == 'recommendProductsByFeatures')) {
          String? imageIdentifier;
          if (pendingCall.function.name == 'getProductInfo') {
            var productInfo = api_models.GetProductInfoResponse.fromJson(toolResultData);
            imageIdentifier = productInfo.imageUrl;
          } else if (pendingCall.function.name == 'recommendProductsByFeatures') {
            var recommendations = api_models.RecommendProductsByFeaturesResponse.fromJson(toolResultData);
            if (recommendations.products.isNotEmpty) {
              imageIdentifier = recommendations.products.first.imageUrl;
            }
          }
          if (imageIdentifier != null) {
            _imagePathForNextAssistantMessage = getProductImagePath(imageIdentifier);
            _log.info("Image path determined for confirmed tool call: $_imagePathForNextAssistantMessage");
          }
        }


      } catch (e, stackTrace) {
        _log.severe("Error executing confirmed tool via ToolRegistry ${pendingCall.function.name}: $e", e, stackTrace);
        toolResultJson = jsonEncode({"error": "ToolRegistry execution failed after confirmation: $e", "function_name": pendingCall.function.name});
      }

      final toolResultMessage = ChatMessage(
        role: MessageRole.tool,
        toolCallId: pendingCall.id,
        name: pendingCall.function.name,
        content: toolResultJson,
        timestamp: DateTime.now(),
      );
      _ref.read(chatMessagesProvider.notifier).addMessage(toolResultMessage);
      messagesForLlm.add(toolResultMessage); // Add to current context for LLM
      // Pass the existing _imagePathForNextAssistantMessage to _continueLlmInteraction
      await _continueLlmInteraction(messagesForLlm, "Tool ${pendingCall.function.name} 실행 결과를 바탕으로 사용자에게 안내해주세요.", preDeterminedImagePath: _imagePathForNextAssistantMessage);
      _imagePathForNextAssistantMessage = null; // Reset after use
    } else if (cancelled) {
      _log.info("User cancelled tool execution for: ${pendingCall.function.name}");
      _addAssistantMessage("${pendingCall.function.name} 요청이 취소되었습니다.");
    } else {
      _log.info("User confirmation unclear for ${pendingCall.function.name}. Input: $userInput. Requesting clarification.");
      _addAssistantMessage("죄송합니다, 이해하지 못했습니다. '${_originalUserMessageBeforeConfirmation ?? '이전 요청'}'에 대한 진행 여부를 '네' 또는 '아니오'로 다시 한번 말씀해주시겠어요?");
      // Preserve _pendingToolCallForConfirmation for the next user input
    }
  }

  Future<void> _continueLlmInteraction(List<ChatMessage> messages, String? overrideUserContent, {String? preDeterminedImagePath}) async {
    List<ChatMessage> currentMessages = List.from(messages);
    if(overrideUserContent != null){
      currentMessages.add(ChatMessage(role: MessageRole.user, content: overrideUserContent, timestamp: DateTime.now()));
    }

    _ref.read(chatLoadingProvider.notifier).state = true;

    List<ChatMessage> systemAndContextMessages = _buildSystemMessages();
    List<ChatMessage> messagesForLlm = [...systemAndContextMessages, ...currentMessages.where((m) => m.role != MessageRole.system)];
    LlmApiResponse llmResponse;
    try {
      llmResponse = await _o3LlmService.getChatCompletion(
        conversationHistory: messagesForLlm,
        tools: const [], // Typically no tools expected when just generating a final response
        toolChoice: "none",
        usePrimaryModel: true,
        temperature: _appConfig.finalResponseTemperature,
        maxCompletionTokensOverride: _appConfig.finalResponseMaxTokens,
      );
    } catch (e, stackTrace) {
      _log.severe("LLM API call failed during _continueLlmInteraction: $e", e, stackTrace);
      _addAssistantErrorMessage("죄송합니다, 응답을 생성하는 중 오류가 발생했습니다.");
      _ref.read(chatLoadingProvider.notifier).state = false;
      return;
    }

    if (llmResponse.error != null) {
      _log.warning("LLM API returned an error during _continueLlmInteraction: ${llmResponse.error?.message}");
      _addAssistantErrorMessage("응답 생성 중 오류: ${llmResponse.error?.message}");
    } else if (llmResponse.choices != null && llmResponse.choices!.isNotEmpty) {
      final choice = llmResponse.choices!.first;
      final assistantResponseContent = choice.message.content;

      if (assistantResponseContent != null && assistantResponseContent.isNotEmpty) {
        final finalAssistantMessage = ChatMessage(
            role: MessageRole.assistant,
            content: assistantResponseContent,
            localImagePath: preDeterminedImagePath ?? _imagePathForNextAssistantMessage, // Use pre-determined if available
            timestamp: DateTime.now()
        );
        _ref.read(chatMessagesProvider.notifier).addMessage(finalAssistantMessage);
      } else {
        _addAssistantErrorMessage("응답 내용을 받지 못했습니다.");
      }
    } else {
      _addAssistantErrorMessage("죄송합니다, 명확한 답변을 생성하지 못했습니다.");
    }
    _imagePathForNextAssistantMessage = null; // Always reset after an attempt to use it
    _ref.read(chatLoadingProvider.notifier).state = false;
  }


  String _summarizeOrderForConfirmation(String argsJson) {
    try {
      final args = jsonDecode(argsJson) as Map<String, dynamic>;
      final productName = args['productName'] as String? ?? '알 수 없는 제품';
      final quantity = (args['quantity'] as num?)?.toInt() ?? 1;
      final size = args['size'] as String? ?? '사이즈 미지정';
      final color = args['color'] as String? ?? '색상 미지정';
      final storeName = args['storeName'] as String? ?? '알 수 없는 매장';
      final couponId = args['couponId'] as String?;
      String summary = "$productName ($size/$color) ${quantity}개를 $storeName 매장에서 주문합니다.";
      if (couponId != null && couponId.isNotEmpty) {
        summary += " $couponId 쿠폰을 사용합니다.";
      }
      return summary;
    } catch (e) {
      _log.warning("Failed to summarize order for confirmation: $e. Raw args: $argsJson");
      return "요청하신 주문";
    }
  }

  void _clearPendingConfirmation() {
    _pendingToolCallForConfirmation = null;
    _originalUserMessageBeforeConfirmation = null;
  }

  void _addAssistantMessage(String content) {
    final messageToAdd = ChatMessage(
        role: MessageRole.assistant,
        content: content,
        localImagePath: _imagePathForNextAssistantMessage, // Check if an image path needs to be added
        timestamp: DateTime.now()
    );
    _ref.read(chatMessagesProvider.notifier).addMessage(messageToAdd);
    if (_imagePathForNextAssistantMessage != null) {
      _imagePathForNextAssistantMessage = null; // Reset after use
    }
  }
  void _addAssistantErrorMessage(String content) {
    _log.warning("Adding assistant error message: $content");
    final messageToAdd = ChatMessage(
        role: MessageRole.assistant,
        content: content,
        localImagePath: _imagePathForNextAssistantMessage, // Errors generally shouldn't have images
        timestamp: DateTime.now()
    );
    _ref.read(chatMessagesProvider.notifier).addMessage(messageToAdd);
    if (_imagePathForNextAssistantMessage != null) {
      _imagePathForNextAssistantMessage = null; // Reset
    }
  }

  void initializeChat() {
    _ref.read(chatMessagesProvider.notifier).clearMessages();
    _ref.read(lastExtractedSlotsProvider.notifier).state = null;
    _ref.read(currentChatSummaryProvider.notifier).state = null;
    _ref.read(qrCodeDataProvider.notifier).state = null;
    _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.idle;
    _ref.read(backgroundTaskErrorProvider.notifier).state = null;
    _currentConversationTurn = 0;
    _clearPendingConfirmation();
    _imagePathForNextAssistantMessage = null; // Reset on init

    if (_currentUserProfile != null) {
      _log.info("Chat initialized for user: ${_currentUserProfile.name} (ID: ${_currentUserProfile.id})");
      _addAssistantMessage("안녕하세요, ${_currentUserProfile.name}님! 데카트론 AI 챗봇입니다. 무엇을 도와드릴까요?");
    } else {
      _log.warning("Chat initialized but current user is null. Displaying generic welcome.");
      _addAssistantMessage("안녕하세요! 데카트론 AI 챗봇입니다. 무엇을 도와드릴까요?");
    }
  }
}