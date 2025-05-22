// lib/features/chat/services/chat_orchestration_service.dart
import 'dart:convert';
import 'dart:async'; // For TimeoutException
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/core/models/llm_models.dart';
import 'package:decathlon_demo_app/core/models/user_profile.dart';
import 'package:decathlon_demo_app/core/models/api_models.dart' as api_models;
import 'package:decathlon_demo_app/core/services/o3_llm_service.dart';
import 'package:decathlon_demo_app/core/services/mock_api_service.dart';
// import 'package:decathlon_demo_app/core/services/env_service.dart'; // AppConfig에 통합됨
import 'package:decathlon_demo_app/features/chat/providers/chat_providers.dart';
import 'package:decathlon_demo_app/core/config/app_config.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart';
import 'package:decathlon_demo_app/background/background_task_queue.dart';
import 'package:decathlon_demo_app/tool_layer/tool_registry.dart'; // ToolRegistry 임포트
import 'package:decathlon_demo_app/tool_layer/mock_api_tool_runners.dart'; // getAllMockApiToolRunners 임포트
import 'package:logging/logging.dart';

class ChatOrchestrationService {
  final Ref _ref;
  final O3LlmService _o3LlmService;
  // final MockApiService _mockApiService; // ToolRegistry를 통해 사용하므로 직접 참조 불필요
  final UserProfile? _currentUserProfile;
  final AppConfig _appConfig;
  final ToolRegistry _toolRegistry; // ToolRegistry 멤버 변수 추가
  final _log = Logger('ChatOrchestrationService');

  int _currentConversationTurn = 0;

  // 사용자 확인을 기다리는 Tool 호출 정보
  ToolCall? _pendingToolCallForConfirmation;
  String? _originalUserMessageBeforeConfirmation; // 확인 요청 전 사용자 메시지 (선택적)

  ChatOrchestrationService({
    required Ref ref,
    required O3LlmService o3LlmService,
    required MockApiService mockApiService, // MockApiService는 Runner 내부에서 ref.read로 접근
    // required EnvService envService, // AppConfig에 통합
    required AppConfig appConfig,
    required UserProfile? currentUserProfile,
  })  : _ref = ref,
        _o3LlmService = o3LlmService,
  // _mockApiService = mockApiService,
        _appConfig = appConfig,
        _currentUserProfile = currentUserProfile,
        _toolRegistry = ToolRegistry() { // ToolRegistry 인스턴스 생성
    // 모든 Mock API Tool Runner들을 ToolRegistry에 등록
    _toolRegistry.registerRunners(getAllMockApiToolRunners());
    _log.info("ToolRegistry initialized and all mock API tool runners registered.");
  }


  List<ToolDefinition> _getToolDefinitions() {
    // 사용자가 제공한 11개 Tool 정의 (이전과 동일)
    return [
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getUserCoupons",
        description: "로그인한 사용자가 현재 보유하고 있거나 발급 가능한 쿠폰 목록과 상세 정보를 반환합니다. 쿠폰 관련 문의 또는 결제 시 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "userId": const FunctionParameterProperty(type: "string", description: "쿠폰 정보를 조회할 사용자의 ID (현재 로그인한 사용자 ID)"),
        }, required: ["userId"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getProductInfo",
        description: "제품명(필수)과 브랜드명(선택)으로 제품의 상세 정보(설명, 가격, 사용 가능한 사이즈/색상, 이미지 URL 등) 또는 '제품 없음' 정보를 반환합니다. 제품 문의나 비교 시 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "productName": const FunctionParameterProperty(type: "string", description: "정보를 조회할 제품의 정확한 한글 전체 제품명"),
          "brandName": const FunctionParameterProperty(type: "string", description: "조회할 제품의 브랜드명 (선택 사항)"),
        }, required: ["productName"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getStoreStock",
        description: "제품명과 매장명을 필수로 입력받고, 선택적으로 사이즈나 색상을 지정하여 특정 매장의 제품 재고 상황을 반환합니다. 사이즈/색상 미지정 시 해당 제품의 모든 가용 옵션별 재고 리스트를 반환합니다. 구매 가능 여부 확인 시 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "productName": const FunctionParameterProperty(type: "string", description: "재고를 조회할 제품의 정확한 한글 전체 제품명"),
          "storeName": const FunctionParameterProperty(type: "string", description: "재고를 조회할 데카트론 매장명 (예: '데카트론 강남점')"),
          "size": const FunctionParameterProperty(type: "string", description: "조회할 제품의 사이즈 (선택 사항, 예: '270mm', 'M', '95')"),
          "color": const FunctionParameterProperty(type: "string", description: "조회할 제품의 색상 (선택 사항, 예: '블랙', '네이비')"),
        }, required: ["productName", "storeName"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getProductLocationInStore",
        description: "제품명 또는 카테고리(둘 중 하나 필수)와 매장명을 입력받아, 매장 내 제품의 위치 정보(구역, 통로 등) 또는 '정보 없음'을 반환합니다. 매장 내에서 제품을 찾을 때 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "productName": const FunctionParameterProperty(type: "string", description: "위치를 찾을 제품의 정확한 한글 전체 제품명 (카테고리와 둘 중 하나 필수)"),
          "category": const FunctionParameterProperty(type: "string", description: "위치를 찾을 제품의 카테고리 (예: '캠핑텐트', '러닝화') (제품명과 둘 중 하나 필수)"),
          "storeName": const FunctionParameterProperty(type: "string", description: "제품 위치를 조회할 데카트론 매장명"),
        }, required: ["storeName"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getStoreInfo",
        description: "특정 매장명(필수)으로 해당 데카트론 매장의 일반 정보(주소, 운영 시간, 전화번호, 제공 서비스 등) 또는 '매장 정보 없음'을 반환합니다. 매장 정보 문의 시 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "storeName": const FunctionParameterProperty(type: "string", description: "정보를 조회할 데카트론 매장명"),
        }, required: ["storeName"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getUserPurchaseHistory",
        description: "로그인한 사용자의 과거 구매 내역을 반환합니다. 재구매 제안이나 과거 구매 제품 관련 문의 시 참고 정보로 활용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "userId": const FunctionParameterProperty(type: "string", description: "구매 내역을 조회할 사용자의 ID (현재 로그인한 사용자 ID)"),
        }, required: ["userId"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getProductReviews",
        description: "특정 제품의 사용자 리뷰 요약 및 일부 주요 리뷰 목록, 또는 '리뷰 없음' 정보를 반환합니다. 제품 선택 시 참고 정보로 제공됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "productName": const FunctionParameterProperty(type: "string", description: "리뷰를 조회할 제품의 정확한 한글 전체 제품명"),
        }, required: ["productName"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "generateOrderQRCode",
        description: "사용자 최종 확인 후 호출됩니다. 주문 정보(제품, 수량, 사이즈, 색상, 구매 매장, 사용 쿠폰 ID(선택))를 받아 계산대 제시용 QR 코드 데이터를 생성합니다. 실제 결제는 계산대에서 QR 스캔 후 진행됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "userId": const FunctionParameterProperty(type: "string", description: "주문하는 사용자의 ID (현재 로그인한 사용자 ID)"),
          "productName": const FunctionParameterProperty(type: "string", description: "주문할 제품의 정확한 한글 전체 제품명. 여러 제품일 경우 '가족나들이세트' 와 같이 대표명 사용 가능."),
          "quantity": const FunctionParameterProperty(type: "integer", description: "주문할 제품의 수량"),
          "size": const FunctionParameterProperty(type: "string", description: "주문할 제품의 사이즈 (예: '270mm', 'M', '4인용')"),
          "color": const FunctionParameterProperty(type: "string", description: "주문할 제품의 색상 (예: '블랙', '카키', '혼합')"),
          "storeName": const FunctionParameterProperty(type: "string", description: "구매를 진행할 데카트론 매장명"),
          "couponId": const FunctionParameterProperty(type: "string", description: "적용할 쿠폰의 ID (선택 사항)"),
        }, required: ["userId", "productName", "quantity", "size", "color", "storeName"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "getConversationHistory",
        description: "현재 사용자의 이전 대화 맥락이 필요할 때 호출합니다. 시스템에 사전 설정된 요약 주기 및 최근 K턴 설정을 기준으로, 해당 채팅방의 가장 최근 요약본과 그 요약 이후부터 가장 최근 K턴까지의 대화 기록 청크를 반환합니다. 사용자가 '저번에 말했던 거', '아까 그거' 등 이전 대화 내용을 언급하거나, 챗봇이 맥락 이해를 위해 필요하다고 판단할 경우 사용합니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "userId": const FunctionParameterProperty(type: "string", description: "대화 기록을 조회할 사용자의 ID (현재 로그인한 사용자 ID)"),
          "currentTurnCount": const FunctionParameterProperty(type: "integer", description: "현재 대화의 총 턴 수. 시스템 프롬프트와 사용자 입력이 각각 1턴으로 간주될 수 있으나, 여기서는 사용자-챗봇 상호작용 1회를 1턴으로 가정하고 증가된 값을 전달."),
          "summaryInterval": const FunctionParameterProperty(type: "integer", description: "대화 요약이 생성되는 주기 (예: 5턴마다). 이 값은 시스템 설정값일 수 있으며, LLM이 임의로 지정하지 않습니다."),
          "recentKTurns": const FunctionParameterProperty(type: "integer", description: "요약 이후 가져올 최근 대화의 턴 수. 이 값은 시스템 설정값일 수 있으며, LLM이 임의로 지정하지 않습니다."),
        }, required: ["userId", "currentTurnCount", "summaryInterval", "recentKTurns"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "findNearbyStores",
        description: "현재 지역명(예: '강남구', '해운대구')과 최대 결과 수(선택 사항, 기본 3개)를 입력받아, 근처 데카트론 매장 목록(이름, 주소, 대략적 거리) 또는 '주변 매장 없음' 정보를 반환합니다. 특정 매장에 재고가 없을 때 연계하여 사용될 수 있습니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "currentLocation": const FunctionParameterProperty(type: "string", description: "주변 매장을 검색할 기준 지역명 (예: '강남구', '인천 연수구')"),
          "maxResults": const FunctionParameterProperty(type: "integer", description: "반환받을 최대 매장 수 (선택 사항, 기본값은 3)"),
        }, required: ["currentLocation"]),
      )),
      const ToolDefinition(type: "function", function: FunctionDefinition(
        name: "recommendProductsByFeatures",
        description: "사용자가 원하는 제품의 여러 특징들(예: '가벼움', '방수', '발목보호'), 선택적 카테고리, 최대 결과 수(선택 사항, 기본 3개)를 입력받아, 해당 특징에 부합하는 추천 제품 목록(제품명, 간단 설명, 가격) 또는 '추천 제품 없음' 정보를 반환합니다. '어떤 거 추천해줘' 와 같은 사용자 질문에 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: {
          "features": const FunctionParameterProperty(type: "array", items: FunctionParameterItems(type: "string"), description: "사용자가 원하는 제품의 특징 목록 (예: ['방수', '경량', '편안함'])"),
          "category": const FunctionParameterProperty(type: "string", description: "추천받고 싶은 제품의 카테고리 (예: '러닝화', '캠핑텐트', '축구공') (선택 사항)"),
          "maxResults": const FunctionParameterProperty(type: "integer", description: "추천받을 최대 제품 수 (선택 사항, 기본값은 3)"),
        }, required: ["features"]),
      )),
    ];
  }

  List<ChatMessage> _buildSystemMessages() {
    // (이전과 동일 - 변경 없음)
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
      final int messagesToTake = recentKTurns * 3;
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
결제(generateOrderQRCode) 등 민감한 작업 전에는 사용자에게 내용을 요약하여 채팅창에서 텍스트로 재확인 질문을 하고, 사용자의 긍정적인 답변('네', '맞아요' 등)을 받은 후에 해당 함수를 호출하도록 유도해야 합니다. (주의: 당신이 직접 함수를 호출하는 것이 아니라, 사용자에게 확인을 요청하는 메시지를 생성해야 합니다.)

$userInfoForPrompt
$contextBlock
사용자의 현재 질문에 대해 답변해주세요.
    """; // generateOrderQRCode 호출 유도 문구 수정
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

    // --- 1. 사용자 확인 대기 중인 Tool 처리 ---
    if (_pendingToolCallForConfirmation != null) {
      await _handlePendingConfirmation(userInput, userMessage);
      _ref.read(chatLoadingProvider.notifier).state = false;
      return;
    }

    // --- 2. 일반 메시지 처리 흐름 ---
    final BackgroundTaskQueue queue = _ref.read(backgroundTaskQueueProvider);
    bool bgtQueueReady = false;
    try {
      await queue.initialize().timeout(const Duration(seconds: 20));
      bgtQueueReady = true;
      // 슬롯 추출은 사용자 입력 직후 바로 요청 (LLM 응답 전에 시작)
      // 다만, LLM 프롬프트에는 이 시점의 슬롯이 아니라 이전 턴의 슬롯이 들어갈 수 있음
      // 또는, 슬롯 추출 완료 후 LLM 호출을 시작하는 것도 방법임 (현재는 병렬적)
      await queue.requestSlotExtraction(userInput);
      _log.info("Requested slot extraction in background for: $userInput");
    } on TimeoutException catch(e,s) {
      _log.severe("Timeout initializing BackgroundTaskQueue or requesting slot extraction. Proceeding without slot extraction for this turn.", e, s);
      _ref.read(backgroundTaskErrorProvider.notifier).state = "백그라운드 작업 초기화 시간 초과. 슬롯 추출이 지연될 수 있습니다.";
    } catch (e,s) {
      _log.severe("Failed to initialize BackgroundTaskQueue or request slot extraction. Proceeding without slot extraction for this turn.", e, s);
      _ref.read(backgroundTaskErrorProvider.notifier).state = "백그라운드 작업 오류. 슬롯 추출이 지연될 수 있습니다.";
    }

    List<ChatMessage> messagesForLlm = _ref.read(chatMessagesProvider); // 항상 최신 전체 대화 목록 사용
    List<ChatMessage> systemAndContextMessages = _buildSystemMessages();
    messagesForLlm = [...systemAndContextMessages, ...messagesForLlm.where((m) => m.role != MessageRole.system)];


    List<ToolDefinition> availableTools = _getToolDefinitions();

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
          temperature: (i == 0) ? _appConfig.toolDecisionTemperature : _appConfig.finalResponseTemperature, // 첫 호출과 이후 호출 온도 다르게 적용 가능
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
      final ChatMessage assistantMessageFromLlm = firstChoice.message.copyWith(timestamp: DateTime.now());

      // 어시스턴트 메시지를 대화 목록에 추가 (tool_calls가 있더라도 content가 있을 수 있음)
      _ref.read(chatMessagesProvider.notifier).addMessage(assistantMessageFromLlm);
      messagesForLlm.add(assistantMessageFromLlm);

      if (firstChoice.finishReason == "tool_calls" && assistantMessageFromLlm.toolCalls != null && assistantMessageFromLlm.toolCalls!.isNotEmpty) {
        _log.info("LLM requested ${assistantMessageFromLlm.toolCalls!.length} tool call(s) in iteration ${i + 1}.");

        List<ChatMessage> toolResultMessages = [];
        bool confirmationRequested = false;

        for (ToolCall toolCall in assistantMessageFromLlm.toolCalls!) {
          _log.info("Processing tool call: ID='${toolCall.id}', Function='${toolCall.function.name}'");
          _log.fine("Function arguments: ${toolCall.function.arguments}");

          // --- 사용자 재확인 로직 (generateOrderQRCode) ---
          if (toolCall.function.name == "generateOrderQRCode") {
            _log.info("Confirmation required for 'generateOrderQRCode'. Storing tool call and requesting confirmation message from LLM.");
            _pendingToolCallForConfirmation = toolCall;
            _originalUserMessageBeforeConfirmation = userInput; // 현재 사용자 입력 저장

            // LLM에게 사용자 확인 질문 생성을 요청
            // 이전 대화에 assistantMessageFromLlm (tool_calls 포함)은 이미 추가됨
            // 이제 "사용자에게 ~~~ 내용으로 QR 생성할지 물어보세요" 라는 요청을 LLM에 보내야 함
            final String orderDetailsSummary = _summarizeOrderForConfirmation(toolCall.function.arguments); // 주문 내용 요약 함수 (아래 추가)

            List<ChatMessage> confirmationPromptMessages = List.from(messagesForLlm); // 현재까지의 대화 포함
            confirmationPromptMessages.add(ChatMessage(
                role: MessageRole.user, // 시스템 또는 사용자 역할로 LLM에게 지시
                content: "방금 요청한 'generateOrderQRCode' 함수 실행 전에 사용자에게 다음 내용으로 QR 코드 생성을 진행할지 확인하는 질문을 해주세요: \"$orderDetailsSummary\". 사용자가 '네' 또는 '아니오'로 답변하도록 유도해주세요.",
                timestamp: DateTime.now()
            ));

            LlmApiResponse confirmationQuestionResponse;
            try {
              confirmationQuestionResponse = await _o3LlmService.getChatCompletion(
                conversationHistory: confirmationPromptMessages,
                tools: [], // 이 단계에서는 tool 호출 안함
                toolChoice: "none", // 텍스트 응답 강제
                usePrimaryModel: true, // 확인 질문은 주 모델 사용
                temperature: _appConfig.finalResponseTemperature, // 일반 응답 온도
                maxCompletionTokensOverride: _appConfig.finalResponseMaxTokens,
              );
            } catch (e, s) {
              _log.severe("LLM call for confirmation question failed.", e, s);
              _addAssistantErrorMessage("주문 확인 중 오류가 발생했습니다. 다시 시도해주세요.");
              _clearPendingConfirmation();
              confirmationRequested = true; // 오류가 났지만 확인 요청 시도는 했음
              break; // 현재 tool_calls 루프 중단
            }

            if (confirmationQuestionResponse.choices != null && confirmationQuestionResponse.choices!.isNotEmpty) {
              final confirmationMsgContent = confirmationQuestionResponse.choices!.first.message.content;
              if (confirmationMsgContent != null && confirmationMsgContent.isNotEmpty) {
                _addAssistantMessage(confirmationMsgContent); // LLM이 생성한 확인 질문을 UI에 표시
              } else {
                _addAssistantErrorMessage("주문 내용을 확인해주세요. 진행하시겠습니까? (네/아니오)"); // Fallback
              }
            } else {
              _addAssistantErrorMessage("주문 내용을 확인해주세요. 진행하시겠습니까? (네/아니오)"); // Fallback
            }
            confirmationRequested = true;
            break; // 현재 tool_calls 루프를 중단하고 사용자 응답 대기
          }
          // --- 사용자 재확인 로직 끝 ---

          // 일반 Tool 실행
          Map<String, dynamic> argumentsMap;
          try {
            argumentsMap = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          } catch (e) {
            _log.severe("Failed to parse tool call arguments for ${toolCall.function.name}: $e");
            toolResultMessages.add(ChatMessage(
              role: MessageRole.tool,
              toolCallId: toolCall.id,
              name: toolCall.function.name,
              content: jsonEncode({"error": "Argument parsing failed: $e", "raw_arguments": toolCall.function.arguments}),
              timestamp: DateTime.now(),
            ));
            continue; // 다음 tool_call 처리
          }

          String toolResultJson;
          try {
            // ToolRegistry를 사용하여 Tool 실행
            final mockResponse = await _toolRegistry.executeTool(toolCall.function.name, toolCall.function.arguments, _ref);
            toolResultJson = jsonEncode(mockResponse);

            // QR 코드 데이터 처리 (generateOrderQRCode가 직접 실행된 경우 - 재확인 로직에서는 여기로 오지 않음)
            if (toolCall.function.name == "generateOrderQRCode") {
              final qrResponse = api_models.GenerateOrderQRCodeResponse.fromJson(mockResponse);
              if (qrResponse.success && qrResponse.qrCodeData != null) {
                _ref.read(qrCodeDataProvider.notifier).state = qrResponse.qrCodeData;
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
        } // end for toolCall in toolCalls

        if (confirmationRequested) {
          // 사용자 확인 질문이 나갔으므로, 현재 LLM 반복은 여기서 종료하고 사용자 입력을 기다림
          _ref.read(chatLoadingProvider.notifier).state = false;
          return;
        }

        if (toolResultMessages.isNotEmpty) {
          _ref.read(chatMessagesProvider.notifier).addMessages(toolResultMessages);
          messagesForLlm.addAll(toolResultMessages);
          // Tool 실행 결과를 받았으므로, 다시 LLM에게 전달하여 최종 응답 생성 (루프 계속)
        }

      } else if (assistantMessageFromLlm.content != null && assistantMessageFromLlm.content!.isNotEmpty) {
        _log.info("LLM provided final text response in iteration ${i + 1}.");
        break;
      } else {
        _log.warning("LLM response in iteration ${i + 1} had neither tool_calls nor content. Finishing turn with a generic message.");
        _addAssistantErrorMessage("음... 제가 어떻게 도와드려야 할지 잘 모르겠어요. 다시 한번 말씀해주시겠어요?");
        break;
      }

      if (i == _appConfig.maxToolIterations - 1) {
        _log.warning("Max tool iterations reached. LLM did not provide a final text response.");
        if (assistantMessageFromLlm.toolCalls != null && assistantMessageFromLlm.toolCalls!.isNotEmpty) {
          _addAssistantErrorMessage("죄송합니다, 요청을 처리하는 데 예상보다 많은 단계가 필요하여 완료하지 못했습니다. 조금 더 구체적으로 질문해주시겠어요? (최대 반복 도달)");
        }
        break;
      }
    } // end for loop (LLM iterations)

    // 주기적 대화 요약 요청 (bgtQueue가 준비된 경우에만)
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

  // 사용자 확인 처리 로직
  Future<void> _handlePendingConfirmation(String userInput, ChatMessage userMessage) async {
    _log.info("Handling user confirmation for pending tool: ${_pendingToolCallForConfirmation?.function.name}. User input: $userInput");
    final pendingCall = _pendingToolCallForConfirmation!;
    _clearPendingConfirmation(); // 일단 처리 시작하면 보류 상태 해제

    // 간단한 키워드 기반으로 사용자 응답 판단 (실제로는 더 정교한 NLU/LLM 판단 필요 가능)
    final positiveKeywords = ["네", "네.", "응", "그래", "맞아", "진행", "해주세요", "yes", "ok", "okay", "proceed"];
    final negativeKeywords = ["아니오", "아니요", "아뇨", "취소", "중단", "no", "cancel", "stop"];

    bool confirmed = positiveKeywords.any((kw) => userInput.toLowerCase().contains(kw));
    bool cancelled = negativeKeywords.any((kw) => userInput.toLowerCase().contains(kw));

    List<ChatMessage> messagesForLlm = _ref.read(chatMessagesProvider); // userMessage는 이미 추가된 상태
    List<ChatMessage> systemAndContextMessages = _buildSystemMessages();
    messagesForLlm = [...systemAndContextMessages, ...messagesForLlm.where((m) => m.role != MessageRole.system)];


    if (confirmed) {
      _log.info("User confirmed tool execution for: ${pendingCall.function.name}");
      _addAssistantMessage("${pendingCall.function.name} 요청을 진행합니다...");

      String toolResultJson;
      try {
        final mockResponse = await _toolRegistry.executeTool(pendingCall.function.name, pendingCall.function.arguments, _ref);
        toolResultJson = jsonEncode(mockResponse);

        if (pendingCall.function.name == "generateOrderQRCode") {
          final qrResponse = api_models.GenerateOrderQRCodeResponse.fromJson(mockResponse);
          if (qrResponse.success && qrResponse.qrCodeData != null) {
            _ref.read(qrCodeDataProvider.notifier).state = qrResponse.qrCodeData;
            // QR 코드 생성 성공 메시지는 LLM이 생성하도록 유도
          } else {
            toolResultJson = jsonEncode({...mockResponse, "error": qrResponse.message ?? "QR code generation failed but no specific message."});
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
      messagesForLlm.add(toolResultMessage);

      // Tool 실행 결과를 바탕으로 LLM에게 최종 응답 생성 요청
      // (processUserMessage의 메인 루프와 유사하게 다시 LLM 호출)
      // 여기서는 간략화하여 바로 다음 LLM 호출로 이어지지 않고, 다음 사용자 입력 시 새로운 흐름으로 처리되도록 할 수도 있음.
      // 또는, 아래처럼 바로 이어서 LLM 호출하여 응답 생성:
      await _continueLlmInteraction(messagesForLlm, "Tool ${pendingCall.function.name} 실행 결과를 바탕으로 사용자에게 안내해주세요.");

    } else if (cancelled) {
      _log.info("User cancelled tool execution for: ${pendingCall.function.name}");
      _addAssistantMessage("${pendingCall.function.name} 요청이 취소되었습니다.");
    } else {
      _log.info("User confirmation unclear for ${pendingCall.function.name}. Input: $userInput. Requesting clarification.");
      // 현재 사용자 메시지는 이미 추가된 상태. 여기에 어시스턴트가 재질문.
      // 또는, LLM에게 "사용자 답변이 모호하니 다시 한번 명확히 물어봐주세요" 요청 가능
      _addAssistantMessage("죄송합니다, 이해하지 못했습니다. '${_originalUserMessageBeforeConfirmation ?? '이전 요청'}'에 대한 진행 여부를 '네' 또는 '아니오'로 다시 한번 말씀해주시겠어요?");
      // 다시 확인 상태로 돌려놓을 수 있음 (하지만 복잡도 증가)
      // _pendingToolCallForConfirmation = pendingCall;
    }
  }

  // LLM 상호작용을 계속하는 내부 함수
  Future<void> _continueLlmInteraction(List<ChatMessage> messages, String? overrideUserContent) async {
    // 이 함수는 processUserMessage의 LLM 호출 루프와 유사하게 동작
    // overrideUserContent는 LLM에게 특정 지시를 내리고 싶을 때 사용
    List<ChatMessage> currentMessages = List.from(messages);
    if(overrideUserContent != null){
      currentMessages.add(ChatMessage(role: MessageRole.user, content: overrideUserContent, timestamp: DateTime.now()));
    }

    _ref.read(chatLoadingProvider.notifier).state = true; // 로딩 시작 명시

    // messagesForLlm 구성 (시스템 메시지 + 현재 대화)
    List<ChatMessage> systemAndContextMessages = _buildSystemMessages(); // 최신 컨텍스트로 다시 빌드
    List<ChatMessage> messagesForLlm = [...systemAndContextMessages, ...currentMessages.where((m) => m.role != MessageRole.system)];


    LlmApiResponse llmResponse;
    try {
      llmResponse = await _o3LlmService.getChatCompletion(
        conversationHistory: messagesForLlm,
        tools: _getToolDefinitions(), // Tool은 계속 제공
        toolChoice: "none", // 일반적으로 Tool 실행 후에는 텍스트 응답 기대
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
      final assistantResponse = choice.message.copyWith(timestamp: DateTime.now());
      // 여기서 tool_calls가 또 나오면 재귀적 호출이나 반복 제한 필요 (현재는 단순 텍스트 응답 기대)
      if (assistantResponse.content != null && assistantResponse.content!.isNotEmpty) {
        _ref.read(chatMessagesProvider.notifier).addMessage(assistantResponse);
      } else if (assistantResponse.toolCalls != null && assistantResponse.toolCalls!.isNotEmpty) {
        _log.warning("_continueLlmInteraction: LLM requested further tool calls. This scenario needs more handling.");
        // 일단 첫번째 tool_call 요청 메시지만 표시 (간단 처리)
        _ref.read(chatMessagesProvider.notifier).addMessage(assistantResponse);
        // TODO: 이 경우 다시 processUserMessage의 메인 루프와 유사한 처리가 필요할 수 있음
        _addAssistantErrorMessage("추가 작업이 요청되었으나, 현재 이 흐름에서는 처리되지 않습니다. 다시 질문해주세요.");
      }
      else {
        _addAssistantErrorMessage("응답 내용을 받지 못했습니다.");
      }
    } else {
      _addAssistantErrorMessage("죄송합니다, 명확한 답변을 생성하지 못했습니다.");
    }
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
      return "요청하신 주문"; // Fallback
    }
  }

  void _clearPendingConfirmation() {
    _pendingToolCallForConfirmation = null;
    _originalUserMessageBeforeConfirmation = null;
  }

  void _addAssistantMessage(String content) {
    _ref.read(chatMessagesProvider.notifier).addMessage(
        ChatMessage(role: MessageRole.assistant, content: content, timestamp: DateTime.now())
    );
  }
  void _addAssistantErrorMessage(String content) {
    _log.warning("Adding assistant error message: $content");
    _ref.read(chatMessagesProvider.notifier).addMessage(
        ChatMessage(role: MessageRole.assistant, content: content, timestamp: DateTime.now())
    );
  }


  Future<dynamic> _executeMockApi(String functionName, Map<String, dynamic> arguments) async {
    // 이 메서드는 이제 ToolRegistry를 통해 실행되므로 ChatOrchestrationService에서는 직접 사용하지 않음.
    // 다만, ToolRunner 구현체 내부에서 MockApiService를 호출하는 형태로 이미 사용되고 있음.
    // 혼동을 피하기 위해 이 메서드는 주석 처리하거나 삭제 가능.
    // 여기서는 삭제하지 않고 남겨두지만, 직접 호출되지 않음을 인지.
    _log.info("DEPRECATED: _executeMockApi called directly. Should use ToolRegistry.");
    if (_currentUserProfile == null) {
      _log.severe("Current user is null. Cannot execute mock API call for $functionName.");
      return {"error": "User not logged in", "found": false, "success": false};
    }
    // ... (기존 _executeMockApi 로직) ...
    // 실제로는 ToolRegistry에 위임해야 함.
    return await _toolRegistry.executeTool(functionName, jsonEncode(arguments), _ref);
  }

  void initializeChat() {
    _ref.read(chatMessagesProvider.notifier).clearMessages();
    _ref.read(lastExtractedSlotsProvider.notifier).state = null;
    _ref.read(currentChatSummaryProvider.notifier).state = null;
    _ref.read(qrCodeDataProvider.notifier).state = null;
    _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.idle;
    _ref.read(backgroundTaskErrorProvider.notifier).state = null;
    _currentConversationTurn = 0;
    _clearPendingConfirmation(); // 보류 중인 확인 상태 초기화

    final initialTimestamp = DateTime.now();

    if (_currentUserProfile != null) {
      _log.info("Chat initialized for user: ${_currentUserProfile.name} (ID: ${_currentUserProfile.id})");
      _addAssistantMessage("안녕하세요, ${_currentUserProfile.name}님! 데카트론 AI 챗봇입니다. 무엇을 도와드릴까요?");
    } else {
      _log.warning("Chat initialized but current user is null. Displaying generic welcome.");
      _addAssistantMessage("안녕하세요! 데카트론 AI 챗봇입니다. 무엇을 도와드릴까요?");
    }
  }
}