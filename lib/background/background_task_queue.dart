// lib/background/background_task_queue.dart
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/config/app_config.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart';
import 'package:decathlon_demo_app/background/isolate_setup_data.dart';
import 'package:decathlon_demo_app/features/chat/providers/chat_providers.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:decathlon_demo_app/core/models/llm_models.dart'; // ResponseFormat 포함
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'dart:developer' as developer;

// backgroundTaskQueueProvider 정의는 이전과 동일 (변경 없음)
final backgroundTaskQueueProvider = Provider<BackgroundTaskQueue>((ref) {
  final appConfigAsync = ref.watch(appConfigProvider);
  final envService = ref.watch(envServiceProvider);

  if (appConfigAsync is AsyncData<AppConfig>) {
    final appConfig = appConfigAsync.value;
    return BackgroundTaskQueue(ref, appConfig, envService);
  }
  Logger('BGTQueueProvider').info(
      'AppConfig not yet ready or in error state for BGTQueueProvider. Queue will be created but needs AppConfig for initialization.');
  return BackgroundTaskQueue(ref, null, envService);
});


class BackgroundTaskQueue {
  // ... (이전과 동일한 멤버 변수 및 생성자, initialize, _handleIsolateError, _handleIsolateResult, _ensureInitialized, requestSlotExtraction, requestSummarization, _cleanupIsolateResources, dispose 메서드들 - 변경 없음) ...
  // (길이 관계상 이전 답변의 코드를 그대로 사용한다고 가정, 여기서는 _isolateEntrypoint 와 _callLlmApiInIsolate 만 집중적으로 표시)
  final Ref _ref;
  AppConfig? _appConfig;
  final EnvService _envService;
  final _log = Logger('BGTQueue_Main');

  Isolate? _isolate;
  SendPort? _sendPortToIsolate;
  ReceivePort? _receivePortFromIsolate;
  StreamSubscription? _portSubscription;

  bool _isInitialized = false;
  bool _isInitializing = false;
  Completer<void> _initializeCompleter = Completer<void>();

  BackgroundTaskQueue(this._ref, this._appConfig, this._envService) {
    _log.info("BackgroundTaskQueue instance created.");
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      _log.info('BackgroundTaskQueue is already initialized.');
      return;
    }
    if (_isInitializing) {
      _log.info('BackgroundTaskQueue initialization already in progress. Waiting for current attempt...');
      return _initializeCompleter.future;
    }

    _isInitializing = true;
    if (_initializeCompleter.isCompleted) {
      _initializeCompleter = Completer<void>();
    }
    _log.info('Attempting to initialize BackgroundTaskQueue...');

    final currentAppConfig = _appConfig ?? _ref.read(appConfigProvider).value;
    if (currentAppConfig == null) {
      final errorMsg = 'AppConfig is not available. BackgroundTaskQueue cannot be initialized.';
      _log.severe(errorMsg);
      _isInitializing = false;
      if (!_initializeCompleter.isCompleted) {
        _initializeCompleter.completeError(Exception(errorMsg));
      }
      return _initializeCompleter.future;
    }
    _appConfig = currentAppConfig;

    _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.idle;

    final setupData = IsolateSetupData.fromServices(_appConfig!, _envService);
    _log.fine("IsolateSetupData created. Full API Endpoint for Isolate: ${setupData.o3LlmApiFullEndpoint}");


    await _portSubscription?.cancel();
    _receivePortFromIsolate?.close();
    _isolate?.kill(priority: Isolate.immediate);

    _receivePortFromIsolate = ReceivePort();
    _log.info('New ReceivePort created for Isolate communication.');

    try {
      _log.info('Spawning Isolate (BackgroundTaskIsolate)...');
      final errorPort = ReceivePort();
      final exitPort = ReceivePort();

      errorPort.listen((errorData) {
        _log.severe('[MainIsolate] Error from Isolate (errorPort): $errorData');
        if (errorData is List && errorData.length == 2) {
          _handleIsolateError(Exception(errorData[0]), StackTrace.fromString(errorData[1]));
        } else {
          _handleIsolateError(Exception("Unknown error from Isolate: $errorData"), StackTrace.current);
        }
      });

      exitPort.listen((exitData) {
        _log.warning('[MainIsolate] Isolate exited (exitPort): $exitData');
        _handleIsolateError(Exception("Isolate exited unexpectedly."), StackTrace.current);
      });

      _isolate = await Isolate.spawn(
        _isolateEntrypoint,
        {'port': _receivePortFromIsolate!.sendPort, 'setupData': setupData},
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        debugName: 'BackgroundTaskIsolate',
      );
      _log.info('Isolate spawn command issued. Waiting for SendPort from Isolate...');
    } catch (e, s) {
      _log.severe('Failed to spawn Isolate.', e, s);
      _handleIsolateError(e,s);
      return _initializeCompleter.future;
    }

    _portSubscription = _receivePortFromIsolate!.listen(
          (dynamic message) {
        _log.fine('[MainIsolate] Received from Isolate: ${message.runtimeType} - ${message.toString().substring(0, (message.toString().length > 250 ? 250 : message.toString().length))}');
        if (message is SendPort) {
          _sendPortToIsolate = message;
          _isInitialized = true;
          _isInitializing = false;
          if (!_initializeCompleter.isCompleted) {
            _initializeCompleter.complete();
          }
          _log.info('BackgroundTaskQueue initialized SUCCESSFULLY. Isolate handshake complete.');
        } else if (message is Map<String, dynamic>) {
          _handleIsolateResult(message['type'] as String?, message['payload'], message['error'] as String?);
        } else {
          _log.warning('[MainIsolate] Unhandled message type from Isolate: ${message.runtimeType} - $message');
        }
      },
      onError: (error, stackTrace) {
        _log.severe('[MainIsolate] Error listening to Isolate ReceivePort.', error, stackTrace);
        _handleIsolateError(error, stackTrace);
      },
      onDone: () {
        _log.warning('[MainIsolate] Isolate ReceivePort stream closed (onDone). This might indicate Isolate exited.');
        if (_isInitializing && !_isInitialized) {
          _handleIsolateError(Exception("Isolate exited before handshake completed."), StackTrace.current);
        }
      },
      cancelOnError: true,
    );

    try {
      await _initializeCompleter.future.timeout(const Duration(seconds: 15));
      _log.info("Isolate handshake completed within timeout.");
    } on TimeoutException catch (e,s) {
      _log.severe("Isolate handshake timed out after 15 seconds.", e, s);
      _handleIsolateError(e,s);
      _isolate?.kill(priority: Isolate.immediate);
    } catch (e,s) {
      _log.severe("Error during Isolate handshake wait: $e", e, s);
      _handleIsolateError(e,s);
    }
    return _initializeCompleter.future;
  }

  void _handleIsolateError(Object error, StackTrace stackTrace) {
    _log.severe('Isolate-related error occurred: $error', error, stackTrace);
    _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.error;
    _ref.read(backgroundTaskErrorProvider.notifier).state = 'Isolate error: $error';

    _isInitializing = false;
    _isInitialized = false;
    if (!_initializeCompleter.isCompleted) {
      _initializeCompleter.completeError(error, stackTrace);
    }
    _cleanupIsolateResources();
  }

  void _handleIsolateResult(String? type, dynamic payload, String? error) {
    if (error != null) {
      _log.severe('Error message received from Isolate for task type $type: $error');
      _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.error;
      _ref.read(backgroundTaskErrorProvider.notifier).state = 'Isolate task error ($type): $error';
      return;
    }
    if (type == null || payload == null) {
      _log.warning('Received result from Isolate with null type or payload. Type: $type');
      return;
    }

    _log.info('Handling Isolate result for type: $type');
    switch (type) {
      case 'slotExtractionResult':
        if (payload is Map<String, dynamic>) {
          _ref.read(lastExtractedSlotsProvider.notifier).state = payload;
          _log.fine('Slots updated in provider: $payload');
        } else {
          _log.warning('Invalid payload for slotExtractionResult: ${payload.runtimeType}');
        }
        _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.idle;
        break;
      case 'summarizationResult':
        if (payload is String) {
          _ref.read(currentChatSummaryProvider.notifier).state = payload;
          _log.fine('Summary updated in provider: ${payload.substring(0, (payload.length > 70 ? 70 : payload.length))}...');
        } else {
          _log.warning('Invalid payload for summarizationResult: ${payload.runtimeType}');
        }
        _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.idle;
        break;
      case 'taskError':
        _log.severe('Task error explicitly reported from Isolate: $payload');
        _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.error;
        _ref.read(backgroundTaskErrorProvider.notifier).state = payload as String?;
        break;
      default:
        _log.warning('Unknown result type from Isolate: $type');
        _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.idle;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _log.info('Queue not initialized. Attempting to initialize now...');
      if (_isInitializing) {
        _log.info('Initialization already in progress, awaiting completion...');
        await _initializeCompleter.future.timeout(const Duration(seconds: 20),
            onTimeout: () {
              _log.severe("Timeout waiting for ongoing initialization to complete before task request.");
              throw TimeoutException("Timeout waiting for ongoing initialization.");
            }
        );
      } else {
        await initialize().timeout(const Duration(seconds: 20),
            onTimeout: () {
              _log.severe("Timeout during explicit initialization before task request.");
              throw TimeoutException("Timeout during explicit initialization.");
            }
        );
      }
      if (!_isInitialized) {
        final errorMsg = 'Queue failed to initialize after explicit attempt. Cannot process task.';
        _log.severe(errorMsg);
        _ref.read(backgroundTaskErrorProvider.notifier).state = errorMsg;
        _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.error;
        throw Exception(errorMsg);
      }
    }
  }

  Future<void> requestSlotExtraction(String userInput) async {
    try {
      await _ensureInitialized();
    } catch (e) {
      _log.severe('Slot Extraction: Initialization check failed. Cannot request.', e);
      return;
    }
    _log.info('Requesting slot extraction for input: ${userInput.substring(0, (userInput.length > 50 ? 50 : userInput.length))}...');
    _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.slotExtracting;
    _sendPortToIsolate!.send({'type': 'extractSlots', 'payload': userInput});
  }

  Future<void> requestSummarization(List<Map<String, dynamic>> historyForIsolate, String? previousSummary) async {
    try {
      await _ensureInitialized();
    } catch (e) {
      _log.severe('Summarization: Initialization check failed. Cannot request.', e);
      return;
    }
    _log.info('Requesting conversation summarization. History (map) length: ${historyForIsolate.length}');
    _ref.read(backgroundTaskStatusProvider.notifier).state = BackgroundTaskState.summarizing;

    _sendPortToIsolate!.send({
      'type': 'summarizeConversation',
      'payload': {
        'history': historyForIsolate, // ChatMessage.toJsonForApi() 결과의 List
        'previousSummary': previousSummary,
      }
    });
  }

  void _cleanupIsolateResources() {
    _log.info("Cleaning up Isolate resources...");
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPortToIsolate = null;

    _portSubscription?.cancel();
    _portSubscription = null;
    _receivePortFromIsolate?.close();
    _receivePortFromIsolate = null;

    _isInitialized = false;
    _isInitializing = false;

    if (!_initializeCompleter.isCompleted) {
      _initializeCompleter.completeError(Exception("Isolate resources cleaned up or initialization aborted."));
      _log.warning("Completed _initializeCompleter with error due to resource cleanup during active initialization.");
    }
    _log.info("Isolate resources cleanup finished.");
  }

  void dispose() {
    _log.info('Disposing BackgroundTaskQueue and killing Isolate.');
    _cleanupIsolateResources();
  }
}

// --- Isolate Entrypoint ---
Future<void> _isolateEntrypoint(dynamic initialMessage) async {
  SendPort? sendPortToMain;
  final ReceivePort receivePortFromMain = ReceivePort();
  Logger? _isoLog;

  try {
    final isolateId = Isolate.current.debugName ?? developer.Service.getIsolateId(Isolate.current) ?? 'UnknownID';
    _isoLog = Logger('BGTIsolate[$isolateId]');
    _isoLog.info('Isolate entrypoint started successfully.');

    if (initialMessage == null || initialMessage is! Map<String, dynamic>) {
      _isoLog.severe('Initial message is null or not a Map. Cannot proceed.');
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }

    sendPortToMain = initialMessage['port'] as SendPort?;
    if (sendPortToMain == null) {
      _isoLog.severe('SendPort to main isolate is missing in initialMessage.');
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }

    final IsolateSetupData setupData = initialMessage['setupData'] as IsolateSetupData;
    _isoLog.info('IsolateSetupData received. Primary model: ${setupData.appConfig.primaryLlmModelName}. Full Endpoint for Isolate: ${setupData.o3LlmApiFullEndpoint}');
    final String apiKeyForLog = setupData.o3LlmApiKey;
    String apiKeyHint = "API_KEY_EMPTY_OR_NOT_SET";
    if (apiKeyForLog.isNotEmpty) {
      apiKeyHint = apiKeyForLog.length > 5 ? "${apiKeyForLog.substring(0, 5)}..." : apiKeyForLog;
    }
    _isoLog.fine('API Key Hint: $apiKeyHint');

    sendPortToMain.send(receivePortFromMain.sendPort);
    _isoLog.info('Isolate sent its SendPort to main isolate. Waiting for tasks...');

    await for (final dynamic msgFromMain in receivePortFromMain) {
      if (msgFromMain is Map<String, dynamic>) {
        final type = msgFromMain['type'] as String;
        final payload = msgFromMain['payload'];
        _isoLog.info('Isolate received task: $type');
        final AppConfig cfg = setupData.appConfig; // AppConfig를 setupData에서 가져옴

        try {
          if (type == 'extractSlots') {
            final userInput = payload as String;
            String slotExtractionPrompt;

            // AppConfig에서 슬롯 추출 프롬프트 템플릿 사용
            if (cfg.slotExtractionPromptTemplate != null && cfg.slotExtractionPromptTemplate!.isNotEmpty) {
              slotExtractionPrompt = cfg.slotExtractionPromptTemplate!.replaceAll('{user_input}', userInput);
              _isoLog.fine("Using slot extraction prompt from AppConfig template.");
            } else {
              // Fallback 프롬프트
              slotExtractionPrompt = """Extract key entities (slots) from the following user input. Respond strictly in JSON format. Example slots: "product_category", "brand_mentioned", "user_preference", "size_info". If no specific slots are found, return an empty JSON object. User input: "$userInput" """;
              _isoLog.fine("Using default slot extraction prompt.");
            }
            _isoLog.finest("Slot Extraction Prompt for LLM:\n$slotExtractionPrompt");

            final messagesForLlm = [{'role': 'user', 'content': slotExtractionPrompt}];

            final llmResponse = await _callLlmApiInIsolate(
                messages: messagesForLlm,
                modelName: cfg.slotExtractionModel, // AppConfig에서 모델명 사용
                temperature: cfg.slotExtractionTemperature, // AppConfig에서 온도 사용
                maxTokens: cfg.slotExtractionMaxTokens, // AppConfig에서 최대 토큰 사용
                responseFormat: const ResponseFormat(type: "json_object"), // 슬롯 추출 시 JSON 응답 형식 강제
                setupData: setupData,
                isoLog: _isoLog
            );

            if (llmResponse.containsKey('error')) {
              final errorDetails = llmResponse['details'] != null ? "Details: ${llmResponse['details']}" : "";
              _isoLog.severe("Slot extraction LLM call failed: ${llmResponse['error']} $errorDetails");
              sendPortToMain.send({'type': 'taskError', 'payload': 'Slot extraction LLM call failed: ${llmResponse['error']} $errorDetails'});
            } else {
              final choices = llmResponse['choices'] as List<dynamic>?;
              if (choices != null && choices.isNotEmpty) {
                final message = choices.first['message'] as Map<String, dynamic>?;
                final content = message?['content'] as String?;
                if (content != null) {
                  try {
                    final extractedSlots = jsonDecode(content) as Map<String, dynamic>;
                    _isoLog.fine("Slots extracted in Isolate: $extractedSlots");
                    sendPortToMain.send({'type': 'slotExtractionResult', 'payload': extractedSlots});
                  } catch (e) {
                    _isoLog.warning('Failed to parse slot extraction LLM content as JSON: $content. Error: $e');
                    sendPortToMain.send({'type': 'taskError', 'payload': 'Slot extraction result JSON parsing failed: $e. Raw content: $content'});
                  }
                } else {
                  _isoLog.warning('No content in slot extraction LLM response message.');
                  sendPortToMain.send({'type': 'taskError', 'payload': 'No content in slot extraction LLM response'});
                }
              } else {
                _isoLog.warning('No choices in slot extraction LLM response.');
                sendPortToMain.send({'type': 'taskError', 'payload': 'No choices in slot extraction LLM response'});
              }
            }
          } else if (type == 'summarizeConversation') {
            final Map<String, dynamic> summaryPayload = payload as Map<String, dynamic>;
            // history는 List<Map<String, dynamic>> 형태로 전달됨 (ChatMessage.toJsonForApi()의 결과)
            final List<Map<String, dynamic>> historyJsonList = (summaryPayload['history'] as List<dynamic>).cast<Map<String, dynamic>>();
            final String? previousSummary = summaryPayload['previousSummary'] as String?;
            String summarizationPrompt;

            // AppConfig에서 요약 프롬프트 템플릿 사용
            if (cfg.summarizationPromptTemplate != null && cfg.summarizationPromptTemplate!.isNotEmpty) {
              // conversation_history를 문자열로 변환
              String historyStrForPrompt = historyJsonList.map((m) {
                String role = m['role'] ?? 'unknown';
                String content = m['content'] ?? '(내용 없음)';
                if (content.length > 200) content = "${content.substring(0,197)}..."; // 너무 길면 자르기
                return "$role: $content";
              }).join("\n");

              summarizationPrompt = cfg.summarizationPromptTemplate!
                  .replaceAll('{previous_summary}', previousSummary ?? "제공된 이전 요약 없음.")
                  .replaceAll('{conversation_history}', historyStrForPrompt)
                  .replaceAll('{target_summary_tokens}', cfg.targetSummaryTokens.toString());
              _isoLog.fine("Using summarization prompt from AppConfig template.");
            } else {
              // Fallback 프롬프트
              String historyStr = historyJsonList.map((m) => "${m['role']}: ${m['content'] ?? '(내용 없음)'}").join("\n");
              summarizationPrompt = "다음은 이전 대화 요약과 최근 대화 기록입니다. 이 전체 대화를 간결하게 요약해주세요. 사용자 프로필 정보나 시스템 지침은 제외하고 순수 대화 내용만 요약합니다. 한국어로 작성해주세요.\n\n[이전 요약]:\n${previousSummary ?? "제공된 이전 요약 없음."}\n\n[최근 대화 기록]:\n$historyStr\n\n[요청사항]: 위 대화 내용을 바탕으로 전체 대화의 핵심 내용을 ${cfg.targetSummaryTokens} 토큰 내외로 요약해주세요.";
              _isoLog.fine("Using default summarization prompt.");
            }
            _isoLog.finest("Summarization Prompt for LLM:\n$summarizationPrompt");

            final messagesForLlm = [{'role': 'user', 'content': summarizationPrompt}];
            final llmResponse = await _callLlmApiInIsolate(
                messages: messagesForLlm,
                modelName: cfg.summarizationModel, // AppConfig에서 모델명 사용
                temperature: cfg.summarizationTemperature, // AppConfig에서 온도 사용
                maxTokens: cfg.summarizationMaxTokens, // AppConfig에서 최대 토큰 사용
                // responseFormat은 요약 시 보통 불필요 (기본 텍스트)
                setupData: setupData,
                isoLog: _isoLog
            );

            if (llmResponse.containsKey('error')) {
              final errorDetails = llmResponse['details'] != null ? "Details: ${llmResponse['details']}" : "";
              _isoLog.severe("Summarization LLM call failed: ${llmResponse['error']} $errorDetails");
              sendPortToMain.send({'type': 'taskError', 'payload': 'Summarization LLM call failed: ${llmResponse['error']} $errorDetails'});
            } else {
              final choices = llmResponse['choices'] as List<dynamic>?;
              if (choices != null && choices.isNotEmpty) {
                final message = choices.first['message'] as Map<String, dynamic>?;
                final summaryText = message?['content'] as String?;
                if (summaryText != null && summaryText.isNotEmpty) {
                  _isoLog.fine("Summary generated in Isolate: ${summaryText.substring(0, (summaryText.length > 70 ? 70 : summaryText.length))}...");
                  sendPortToMain.send({'type': 'summarizationResult', 'payload': summaryText.trim()});
                } else {
                  _isoLog.warning('No content or empty content in summarization LLM response.');
                  sendPortToMain.send({'type': 'taskError', 'payload': 'Empty content in summarization LLM response'});
                }
              } else {
                _isoLog.warning('No choices in summarization LLM response.');
                sendPortToMain.send({'type': 'taskError', 'payload': 'No choices in summarization LLM response'});
              }
            }
          }
        } catch (e, s) {
          _isoLog.severe('Error processing task $type in Isolate: $e', e, s);
          sendPortToMain?.send({'type': 'taskError', 'payload': 'Error in Isolate processing task $type: $e'});
        }
      } else {
        _isoLog.warning("Isolate received non-Map message from Main: ${msgFromMain.runtimeType}");
      }
    }
  } catch (e, s) {
    _isoLog?.severe('FATAL error in _isolateEntrypoint: $e', e, s);
    sendPortToMain?.send({'type': 'taskError', 'payload': 'Isolate critical init error: $e'});
  } finally {
    _isoLog?.info('Isolate receivePort listener finished. Isolate is exiting.');
    receivePortFromMain.close();
  }
}

Future<Map<String, dynamic>> _callLlmApiInIsolate({
  required List<Map<String, dynamic>> messages,
  required String modelName,
  required double temperature,
  required int maxTokens,
  ResponseFormat? responseFormat,
  required IsolateSetupData setupData,
  required Logger isoLog,
}) async {
  isoLog.fine('Calling LLM in Isolate. Model: $modelName, Msgs: ${messages.length}, Temp: $temperature, MaxTokens: $maxTokens, Endpoint: ${setupData.o3LlmApiFullEndpoint}');

  Map<String, dynamic> requestBodyMap = {
    'model': modelName,
    'messages': messages,
    'temperature': temperature,
  };
  // 모델명에 따라 max_tokens 또는 max_completion_tokens 사용
  if (modelName.toLowerCase().startsWith('o3')) {
    requestBodyMap['max_completion_tokens'] = maxTokens;
  } else {
    requestBodyMap['max_tokens'] = maxTokens;
  }
  if (responseFormat != null) {
    requestBodyMap['response_format'] = responseFormat.toJson();
  }

  final String bodyJson = jsonEncode(requestBodyMap);
  isoLog.finest("LLM Request Body (Isolate): ${bodyJson.substring(0, bodyJson.length > 200 ? 200 : bodyJson.length)}");

  try {
    final response = await http.post(
      Uri.parse(setupData.o3LlmApiFullEndpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${setupData.o3LlmApiKey}',
      },
      body: bodyJson,
    ).timeout(const Duration(seconds: 90));

    final responseBodyString = utf8.decode(response.bodyBytes);
    isoLog.fine('LLM API response status (Isolate): ${response.statusCode}');
    isoLog.finest('LLM API response body (Isolate preview): ${responseBodyString.substring(0, (responseBodyString.length > 200 ? 200 : responseBodyString.length))}...');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decodedBody = jsonDecode(responseBodyString);
      return decodedBody as Map<String, dynamic>;
    } else {
      isoLog.severe('LLM API Error (Isolate): ${response.statusCode} - $responseBodyString');
      return {'error': 'API Error: ${response.statusCode}', 'details': responseBodyString};
    }
  } on TimeoutException catch (e,s) {
    isoLog.severe('LLM API call timed out (Isolate): $e', e, s);
    return {'error': 'API TimeoutException (Isolate): $e'};
  } catch (e, s) {
    isoLog.severe('Exception during LLM API call (Isolate): $e', e, s);
    return {'error': 'Exception during HTTP call (Isolate): $e'};
  }
}