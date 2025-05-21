// 파일 경로: lib/features/chat/services/chat_orchestration_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/chat_message.dart';
import 'package:decathlon_demo_app/core/models/llm_models.dart';
import 'package:decathlon_demo_app/core/models/user_profile.dart';
import 'package:decathlon_demo_app/core/models/api_models.dart' as api_models;
import 'package:decathlon_demo_app/core/services/o3_llm_service.dart';
import 'package:decathlon_demo_app/core/services/mock_api_service.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'package:decathlon_demo_app/features/chat/providers/chat_providers.dart';
import 'package:decathlon_demo_app/core/constants/app_constants.dart';
import 'package:logging/logging.dart';

class ChatOrchestrationService {
  final Ref _ref;
  final O3LlmService _o3LlmService;
  final MockApiService _mockApiService;
  final UserProfile? _currentUserProfile;
  final _log = Logger('ChatOrchestrationService');

  ChatOrchestrationService({
    required Ref ref,
    required O3LlmService o3LlmService,
    required MockApiService mockApiService,
    required EnvService envService,
    required UserProfile? currentUserProfile,
  })  : _ref = ref,
        _o3LlmService = o3LlmService,
        _mockApiService = mockApiService,
        _currentUserProfile = currentUserProfile;

  List<ToolDefinition> _getToolDefinitions() {
    return [
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getUserCoupons",
        description: "로그인한 사용자가 현재 보유하고 있거나 발급 가능한 쿠폰 목록과 상세 정보를 반환합니다. 쿠폰 관련 문의 또는 결제 시 사용됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "userId": const FunctionParameterProperty(type: "string", description: "쿠폰 정보를 조회할 사용자의 ID (현재 로그인한 사용자 ID)"),
        }, required: const ["userId"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getProductInfo",
        description: "제품명(필수)과 브랜드명(선택)으로 제품의 상세 정보(설명, 가격, 사용 가능한 사이즈/색상, 이미지 URL 등) 또는 '제품 없음' 정보를 반환합니다. 제품 문의나 비교 시 사용됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "productName": const FunctionParameterProperty(type: "string", description: "정보를 조회할 제품의 정확한 한글 전체 제품명"),
          "brandName": const FunctionParameterProperty(type: "string", description: "조회할 제품의 브랜드명 (선택 사항)"),
        }, required: const ["productName"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getStoreStock",
        description: "제품명과 매장명을 필수로 입력받고, 선택적으로 사이즈나 색상을 지정하여 특정 매장의 제품 재고 상황을 반환합니다. 사이즈/색상 미지정 시 해당 제품의 모든 가용 옵션별 재고 리스트를 반환합니다. 구매 가능 여부 확인 시 사용됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "productName": const FunctionParameterProperty(type: "string", description: "재고를 조회할 제품의 정확한 한글 전체 제품명"),
          "storeName": const FunctionParameterProperty(type: "string", description: "재고를 조회할 데카트론 매장명 (예: '데카트론 강남점')"),
          "size": const FunctionParameterProperty(type: "string", description: "조회할 제품의 사이즈 (선택 사항, 예: '270mm', 'M', '95')"),
          "color": const FunctionParameterProperty(type: "string", description: "조회할 제품의 색상 (선택 사항, 예: '블랙', '네이비')"),
        }, required: const ["productName", "storeName"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getProductLocationInStore",
        description: "제품명 또는 카테고리(둘 중 하나 필수)와 매장명을 입력받아, 매장 내 제품의 위치 정보(구역, 통로 등) 또는 '정보 없음'을 반환합니다. 매장 내에서 제품을 찾을 때 사용됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "productName": const FunctionParameterProperty(type: "string", description: "위치를 찾을 제품의 정확한 한글 전체 제품명 (카테고리와 둘 중 하나 필수)"),
          "category": const FunctionParameterProperty(type: "string", description: "위치를 찾을 제품의 카테고리 (예: '캠핑텐트', '러닝화') (제품명과 둘 중 하나 필수)"),
          "storeName": const FunctionParameterProperty(type: "string", description: "제품 위치를 조회할 데카트론 매장명"),
        }, required: const ["storeName"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getStoreInfo",
        description: "특정 매장명(필수)으로 해당 데카트론 매장의 일반 정보(주소, 운영 시간, 전화번호, 제공 서비스 등) 또는 '매장 정보 없음'을 반환합니다. 매장 정보 문의 시 사용됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "storeName": const FunctionParameterProperty(type: "string", description: "정보를 조회할 데카트론 매장명"),
        }, required: const ["storeName"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getUserPurchaseHistory",
        description: "로그인한 사용자의 과거 구매 내역을 반환합니다. 재구매 제안이나 과거 구매 제품 관련 문의 시 참고 정보로 활용됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "userId": const FunctionParameterProperty(type: "string", description: "구매 내역을 조회할 사용자의 ID (현재 로그인한 사용자 ID)"),
        }, required: const ["userId"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getProductReviews",
        description: "특정 제품의 사용자 리뷰 요약 및 일부 주요 리뷰 목록, 또는 '리뷰 없음' 정보를 반환합니다. 제품 선택 시 참고 정보로 제공됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "productName": const FunctionParameterProperty(type: "string", description: "리뷰를 조회할 제품의 정확한 한글 전체 제품명"),
        }, required: const ["productName"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "generateOrderQRCode",
        description: "사용자 최종 확인 후 호출됩니다. 주문 정보(제품, 수량, 사이즈, 색상, 구매 매장, 사용 쿠폰 ID(선택))를 받아 계산대 제시용 QR 코드 데이터를 생성합니다. 실제 결제는 계산대에서 QR 스캔 후 진행됩니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "userId": const FunctionParameterProperty(type: "string", description: "주문하는 사용자의 ID (현재 로그인한 사용자 ID)"),
          "productName": const FunctionParameterProperty(type: "string", description: "주문할 제품의 정확한 한글 전체 제품명. 여러 제품일 경우 '가족나들이세트' 와 같이 대표명 사용 가능."),
          "quantity": const FunctionParameterProperty(type: "integer", description: "주문할 제품의 수량"),
          "size": const FunctionParameterProperty(type: "string", description: "주문할 제품의 사이즈 (예: '270mm', 'M', '4인용')"),
          "color": const FunctionParameterProperty(type: "string", description: "주문할 제품의 색상 (예: '블랙', '카키', '혼합')"),
          "storeName": const FunctionParameterProperty(type: "string", description: "구매를 진행할 데카트론 매장명"),
          "couponId": const FunctionParameterProperty(type: "string", description: "적용할 쿠폰의 ID (선택 사항)"),
        }, required: const ["userId", "productName", "quantity", "size", "color", "storeName"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "getConversationHistory",
        description: "현재 사용자의 이전 대화 맥락이 필요할 때 호출합니다. 시스템에 사전 설정된 요약 주기 및 최근 K턴 설정을 기준으로, 해당 채팅방의 가장 최근 요약본과 그 요약 이후부터 가장 최근 K턴까지의 대화 기록 청크를 반환합니다. 사용자가 '저번에 말했던 거', '아까 그거' 등 이전 대화 내용을 언급하거나, 챗봇이 맥락 이해를 위해 필요하다고 판단할 경우 사용합니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "userId": const FunctionParameterProperty(type: "string", description: "대화 기록을 조회할 사용자의 ID (현재 로그인한 사용자 ID)"),
          "currentTurnCount": const FunctionParameterProperty(type: "integer", description: "현재 대화의 총 턴 수. 시스템 프롬프트와 사용자 입력이 각각 1턴으로 간주될 수 있으나, 여기서는 사용자-챗봇 상호작용 1회를 1턴으로 가정하고 증가된 값을 전달."),
          "summaryInterval": const FunctionParameterProperty(type: "integer", description: "대화 요약이 생성되는 주기 (예: 5턴마다). 이 값은 시스템 설정값일 수 있으며, LLM이 임의로 지정하지 않습니다."),
          "recentKTurns": const FunctionParameterProperty(type: "integer", description: "요약 이후 가져올 최근 대화의 턴 수. 이 값은 시스템 설정값일 수 있으며, LLM이 임의로 지정하지 않습니다."),
        }, required: const ["userId", "currentTurnCount", "summaryInterval", "recentKTurns"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "findNearbyStores",
        description: "현재 지역명(예: '강남구', '해운대구')과 최대 결과 수(선택 사항, 기본 3개)를 입력받아, 근처 데카트론 매장 목록(이름, 주소, 대략적 거리) 또는 '주변 매장 없음' 정보를 반환합니다. 특정 매장에 재고가 없을 때 연계하여 사용될 수 있습니다.",
        parameters: const FunctionParameters(type: "object", properties: { // const 추가
          "currentLocation": const FunctionParameterProperty(type: "string", description: "주변 매장을 검색할 기준 지역명 (예: '강남구', '인천 연수구')"),
          "maxResults": const FunctionParameterProperty(type: "integer", description: "반환받을 최대 매장 수 (선택 사항, 기본값은 3)"),
        }, required: const ["currentLocation"]),
      )),
      const ToolDefinition(type: "function", function: const FunctionDefinition( // const 추가
        name: "recommendProductsByFeatures",
        description: "사용자가 원하는 제품의 여러 특징들(예: '가벼움', '방수', '발목보호'), 선택적 카테고리, 최대 결과 수(선택 사항, 기본 3개)를 입력받아, 해당 특징에 부합하는 추천 제품 목록(제품명, 간단 설명, 가격) 또는 '추천 제품 없음' 정보를 반환합니다. '어떤 거 추천해줘' 와 같은 사용자 질문에 사용됩니다.",
        parameters: FunctionParameters(type: "object", properties: { // FunctionParameters 내부 List<String>은 const 불가
          "features": FunctionParameterProperty(type: "array", items: const FunctionParameterItems(type: "string"), description: "사용자가 원하는 제품의 특징 목록 (예: ['방수', '경량', '편안함'])"),
          "category": const FunctionParameterProperty(type: "string", description: "추천받고 싶은 제품의 카테고리 (예: '러닝화', '캠핑텐트', '축구공') (선택 사항)"),
          "maxResults": const FunctionParameterProperty(type: "integer", description: "추천받을 최대 제품 수 (선택 사항, 기본값은 3)"),
        }, required: const ["features"]), // required: ["features"] 는 const List<String>이므로 const 추가
      )),
    ];
  }

  List<ChatMessage> _buildSystemMessages() {
    String userInfoForPrompt = "현재 사용자는 다음과 같습니다: ";
    if (_currentUserProfile != null) {
      userInfoForPrompt += "이름 '${_currentUserProfile.name}', 나이 ${_currentUserProfile.age}세, 성별 '${_currentUserProfile.gender}'. ";
      if (_currentUserProfile.preferredSports.isNotEmpty) {
        userInfoForPrompt += "선호 스포츠는 ${_currentUserProfile.preferredSports.join(', ')} 입니다. ";
      }
      if (_currentUserProfile.otherInfo != null && _currentUserProfile.otherInfo!.isNotEmpty) {
        userInfoForPrompt += "기타 정보: ${_currentUserProfile.otherInfo}. ";
      }
    } else {
      userInfoForPrompt += "비로그인 사용자 또는 정보 없음. ";
    }
    userInfoForPrompt += "사용자 맞춤형으로 친절하고 상세하게 안내해주세요.";

    String baseSystemPrompt = """
당신은 '데카트론 코리아'의 전문 AI 상담원입니다. 당신의 주요 목표는 고객이 스포츠 활동 및 일상 생활에 필요한 최적의 데카트론 제품을 찾도록 돕는 것입니다.
모든 답변은 한국어로 공손하게 제공해야 합니다.
당신은 아래에 정의된 함수(Tools)들을 사용하여 고객에게 필요한 정보를 제공하거나 요청을 처리할 수 있습니다.
제공된 함수들의 설명을 잘 읽고, 사용자의 질문 의도에 가장 적합한 함수를 선택하여 호출해야 합니다.
함수 호출 시에는 'parameters'에 정의된 모든 'required' 인자들을 반드시 포함해야 하며, 각 인자의 타입과 설명을 준수해야 합니다.
만약 여러 단계의 함수 호출이 필요하다면, 순차적으로 호출하고 그 결과를 종합하여 최종 답변을 생성해주세요.
결제나 개인정보 활용 등 민감한 작업 전에는 반드시 사용자에게 내용을 요약하여 채팅창에서 텍스트로 재확인 질문을 하고, 사용자의 긍정적인 답변('네', '맞아요' 등)을 받은 후에 해당 함수를 호출하세요.

$userInfoForPrompt

사용자의 이전 대화 맥락이 필요하다고 판단되면 'getConversationHistory' 함수를 호출하여 이전 대화 내용을 참고하세요.
    """;
    return [ChatMessage(role: MessageRole.system, content: baseSystemPrompt.trim())];
  }

  int _currentConversationTurn = 0;

  Future<void> processUserMessage(String userInput) async {
    if (_currentUserProfile == null) {
      _ref.read(chatMessagesProvider.notifier).addMessage(const ChatMessage(role: MessageRole.assistant, content: "로그인 정보가 없습니다. 먼저 로그인해주세요."));
      return;
    }

    _ref.read(chatLoadingProvider.notifier).state = true;
    _ref.read(chatMessagesProvider.notifier).addMessage(ChatMessage(role: MessageRole.user, content: userInput));
    _currentConversationTurn++;

    List<ChatMessage> currentConversation = List.from(_ref.read(chatMessagesProvider));
    List<ChatMessage> messagesForLlm = [..._buildSystemMessages(), ...currentConversation];

    List<ToolDefinition> availableTools = _getToolDefinitions();

    for (int i = 0; i < AppConstants.maxToolIterations; i++) {
      _log.info("Sending request to LLM (Iteration ${i + 1}). Message count: ${messagesForLlm.length}");

      LlmApiResponse llmResponse;
      try {
        llmResponse = await _o3LlmService.getChatCompletion(
          conversationHistory: messagesForLlm,
          tools: availableTools,
          toolChoice: "auto",
          usePrimaryModel: true,
          temperature: 0.7,
          maxCompletionTokensOverride: 2000,
        );
      } catch (e, stackTrace) {
        _log.severe("LLM API call failed: $e", e, stackTrace);
        _ref.read(chatMessagesProvider.notifier).addMessage(ChatMessage(role: MessageRole.assistant, content: "죄송합니다, 현재 서비스와 연결할 수 없습니다. 잠시 후 다시 시도해주세요. (오류: $e)"));
        _ref.read(chatLoadingProvider.notifier).state = false;
        return;
      }

      if (llmResponse.error != null) {
        _log.warning("LLM API returned an error: ${llmResponse.error?.message}");
        _ref.read(chatMessagesProvider.notifier).addMessage(ChatMessage(role: MessageRole.assistant, content: "죄송합니다, 요청을 처리하는 중 오류가 발생했습니다. (LLM: ${llmResponse.error?.message})"));
        break;
      }

      if (llmResponse.choices == null || llmResponse.choices!.isEmpty) {
        _log.warning("LLM returned no choices.");
        _ref.read(chatMessagesProvider.notifier).addMessage(const ChatMessage(role: MessageRole.assistant, content: "죄송합니다, 답변을 생성할 수 없습니다. 다른 질문을 해주시겠어요?"));
        break;
      }

      final LlmChoice firstChoice = llmResponse.choices!.first;
      final ChatMessage assistantMessageFromLlm = firstChoice.message;

      messagesForLlm.add(assistantMessageFromLlm);
      _ref.read(chatMessagesProvider.notifier).addMessage(assistantMessageFromLlm);

      if (firstChoice.finishReason == "tool_calls" && assistantMessageFromLlm.toolCalls != null && assistantMessageFromLlm.toolCalls!.isNotEmpty) {
        _log.info("LLM requested tool calls: ${assistantMessageFromLlm.toolCalls!.length} call(s)");

        List<ChatMessage> toolResponses = [];
        for (ToolCall toolCall in assistantMessageFromLlm.toolCalls!) {
          _log.info("Processing tool call: ID='${toolCall.id}', Function='${toolCall.function.name}'");
          _log.fine("Function arguments: ${toolCall.function.arguments}");

          Map<String, dynamic> argumentsMap = {};
          try {
            argumentsMap = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          } catch (e) {
            _log.severe("Failed to parse tool call arguments for ${toolCall.function.name}: $e");
            toolResponses.add(ChatMessage(
              role: MessageRole.tool,
              toolCallId: toolCall.id,
              name: toolCall.function.name,
              content: jsonEncode({"error": "Argument parsing failed: $e"}),
            ));
            continue;
          }

          String toolResultJson;
          try {
            final mockResponse = await _executeMockApi(toolCall.function.name, argumentsMap);
            toolResultJson = jsonEncode(mockResponse);
          } catch (e, stackTrace) {
            _log.severe("Error executing mock API ${toolCall.function.name}: $e", e, stackTrace);
            toolResultJson = jsonEncode({"error": "Mock API execution failed: $e", "function_name": toolCall.function.name});
          }

          _log.fine("Tool '${toolCall.function.name}' result: $toolResultJson");
          toolResponses.add(ChatMessage(
            role: MessageRole.tool,
            toolCallId: toolCall.id,
            name: toolCall.function.name,
            content: toolResultJson,
          ));
        }
        messagesForLlm.addAll(toolResponses);
        _ref.read(chatMessagesProvider.notifier).addMessages(toolResponses);

        final qrToolCall = assistantMessageFromLlm.toolCalls!.firstWhere(
                (tc) => tc.function.name == "generateOrderQRCode", orElse: () => const ToolCall(id: '', type: '', function: const FunctionCallData(name: '', arguments: '{}')) // const 추가
        );
        if(qrToolCall.id.isNotEmpty) {
          final matchingToolResponse = toolResponses.firstWhere(
                  (tr) => tr.toolCallId == qrToolCall.id, orElse: () => const ChatMessage(role: MessageRole.tool, content: '{}') // const 추가
          );
          if (matchingToolResponse.content != null) {
            try {
              final qrResponseData = api_models.GenerateOrderQRCodeResponse.fromJson(jsonDecode(matchingToolResponse.content!));
              if (qrResponseData.success && qrResponseData.qrCodeData != null) {
                _ref.read(qrCodeDataProvider.notifier).state = qrResponseData.qrCodeData;
              }
            } catch(e) {
              _log.warning("Failed to parse QR code data from tool response: $e");
            }
          }
        }

      } else if (assistantMessageFromLlm.content != null && assistantMessageFromLlm.content!.isNotEmpty) {
        _log.info("LLM provided final text response.");
        break;
      } else {
        _log.warning("LLM response has neither tool_calls nor content. Finishing turn.");
        _ref.read(chatMessagesProvider.notifier).addMessage(const ChatMessage(role: MessageRole.assistant, content: "음... 제가 어떻게 도와드려야 할지 잘 모르겠어요. 다시 한번 말씀해주시겠어요?"));
        break;
      }

      if (i == AppConstants.maxToolIterations - 1) {
        _log.warning("Max tool iterations reached. Sending final response attempt or error.");
        _ref.read(chatMessagesProvider.notifier).addMessage(const ChatMessage(role: MessageRole.assistant, content: "죄송합니다, 요청을 처리하는 데 예상보다 많은 단계가 필요하여 완료하지 못했습니다. 조금 더 구체적으로 질문해주시겠어요?"));
      }
    }
    _ref.read(chatLoadingProvider.notifier).state = false;
  }

  Future<dynamic> _executeMockApi(String functionName, Map<String, dynamic> arguments) async {
    if (_currentUserProfile == null) {
      throw Exception("Current user not found for Mock API call.");
    }
    String userId = _currentUserProfile.id;

    switch (functionName) {
      case "getUserCoupons":
        return (await _mockApiService.getUserCoupons(userId: arguments['userId'] ?? userId)).toJson();
      case "getProductInfo":
        return (await _mockApiService.getProductInfo(
          productName: arguments['productName'] as String,
          brandName: arguments['brandName'] as String?,
        )).toJson();
      case "getStoreStock":
        return (await _mockApiService.getStoreStock(
          productName: arguments['productName'] as String,
          storeName: arguments['storeName'] as String,
          size: arguments['size'] as String?,
          color: arguments['color'] as String?,
        )).toJson();
      case "getProductLocationInStore":
        return (await _mockApiService.getProductLocationInStore(
          productName: arguments['productName'] as String?,
          category: arguments['category'] as String?,
          storeName: arguments['storeName'] as String,
        )).toJson();
      case "getStoreInfo":
        return (await _mockApiService.getStoreInfo(storeName: arguments['storeName'] as String)).toJson();
      case "getUserPurchaseHistory":
        return (await _mockApiService.getUserPurchaseHistory(userId: arguments['userId'] ?? userId)).toJson();
      case "getProductReviews":
        return (await _mockApiService.getProductReviews(productName: arguments['productName'] as String)).toJson();
      case "generateOrderQRCode":
        return (await _mockApiService.generateOrderQRCode(
          userId: arguments['userId'] ?? userId,
          productName: arguments['productName'] as String,
          quantity: (arguments['quantity'] as num).toInt(),
          size: arguments['size'] as String,
          color: arguments['color'] as String,
          storeName: arguments['storeName'] as String,
          couponId: arguments['couponId'] as String?,
        )).toJson();
      case "getConversationHistory":
        return (await _mockApiService.getConversationHistory(
          userId: arguments['userId'] ?? userId,
          currentTurnCount: (arguments['currentTurnCount'] as num?)?.toInt() ?? _currentConversationTurn,
          summaryInterval: (arguments['summaryInterval'] as num?)?.toInt() ?? 5,
          recentKTurns: (arguments['recentKTurns'] as num?)?.toInt() ?? 3,
        )).toJson();
      case "findNearbyStores":
        return (await _mockApiService.findNearbyStores(
          currentLocation: arguments['currentLocation'] as String,
          maxResults: (arguments['maxResults'] as num?)?.toInt(),
        )).toJson();
      case "recommendProductsByFeatures":
        List<String> features = (arguments['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        return (await _mockApiService.recommendProductsByFeatures(
          features: features,
          category: arguments['category'] as String?,
          maxResults: (arguments['maxResults'] as num?)?.toInt(),
        )).toJson();
      default:
        _log.severe("Unknown function called by LLM: $functionName");
        return {"error": "Unknown function: $functionName", "found": false, "success": false};
    }
  }
  void initializeChat() {
    _ref.read(chatMessagesProvider.notifier).clearMessages();
    _currentConversationTurn = 0;
    if (_currentUserProfile != null) {
      _log.info("Chat initialized for user: ${_currentUserProfile.name}");
      _ref.read(chatMessagesProvider.notifier).addMessage(
          ChatMessage(role: MessageRole.assistant, content: "안녕하세요, ${_currentUserProfile.name}님! 데카트론 AI 챗봇입니다. 무엇을 도와드릴까요?")
      );
    } else {
      _log.warning("Chat initialized but current user is null.");
      _ref.read(chatMessagesProvider.notifier).addMessage(
          const ChatMessage(role: MessageRole.assistant, content: "안녕하세요! 데카트론 AI 챗봇입니다. 무엇을 도와드릴까요? (로그인 정보 없음)")
      );
    }
  }
}