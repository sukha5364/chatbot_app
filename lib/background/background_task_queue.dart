// lib/background/background_task_queue.dart
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/config/app_config.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart';
import 'package:decathlon_demo_app/background/isolate_setup_data.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:decathlon_demo_app/core/models/llm_models.dart';
import 'package:decathlon_demo_app/core/services/env_service.dart';
import 'dart:developer' as developer;

final backgroundTaskQueueProvider = Provider<BackgroundTaskQueue>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  final envService = ref.watch(envServiceProvider);

  return appConfig.when(
    data: (config) => BackgroundTaskQueue(ref, config, envService),
    loading: () => BackgroundTaskQueue(ref, null, envService),
    error: (err, stack) {
      Logger('BGTQueueProvider').severe('Error loading AppConfig for BGTQueueProvider', err, stack);
      return BackgroundTaskQueue(ref, null, envService);
    },
  );
});


class BackgroundTaskQueue {
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
    if (_appConfig == null) {
      _log.info("AppConfig was null during BGTQueue construction, will attempt to (re)load in initialize if not already an error.");
    }
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

    if (_appConfig == null) {
      try {
        _appConfig = await _ref.read(appConfigProvider.future);
        _log.info('AppConfig successfully loaded/retrieved for BGTQueue initialization via ref.read(provider.future).');
      } catch (e,s) {
        _log.severe('Failed to load AppConfig for BGTQueue via ref.read(provider.future): $e', e,s);
        _isInitializing = false;
        if (!_initializeCompleter.isCompleted) {
          _initializeCompleter.completeError(Exception('AppConfig load failed for BGTQueue: $e'));
        }
        return _initializeCompleter.future;
      }
    }

    if (_appConfig == null) {
      final errorMsg = 'AppConfig is not available after attempting load. BackgroundTaskQueue cannot be initialized.';
      _log.severe(errorMsg);
      _isInitializing = false;
      if (!_initializeCompleter.isCompleted) {
        _initializeCompleter.completeError(Exception(errorMsg));
      }
      return _initializeCompleter.future;
    }

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
    final lastExtractedSlotsProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
    final currentChatSummaryProvider = StateProvider<String?>((ref) => null);

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
        'history': historyForIsolate,
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
    final AppConfig cfg = setupData.appConfig;

    _isoLog.info('IsolateSetupData received. Primary model: ${cfg.primaryLlmModelName}. Full Endpoint: ${setupData.o3LlmApiFullEndpoint}');
    final String apiKeyForLog = setupData.o3LlmApiKey;
    String apiKeyHint = "API_KEY_EMPTY_OR_NOT_SET";
    if (apiKeyForLog.isNotEmpty) {
      apiKeyHint = apiKeyForLog.length > 5 ? "${apiKeyForLog.substring(0, 5)}..." : apiKeyForLog;
    }
    _isoLog.fine('API Key Hint (from setupData): $apiKeyHint');

    sendPortToMain.send(receivePortFromMain.sendPort);
    _isoLog.info('Isolate sent its SendPort to main isolate. Waiting for tasks...');

    await for (final dynamic msgFromMain in receivePortFromMain) {
      if (msgFromMain is Map<String, dynamic>) {
        final type = msgFromMain['type'] as String;
        final payload = msgFromMain['payload'];
        _isoLog.info('Isolate received task: $type');

        try {
          if (type == 'extractSlots') {
            final userInput = payload as String;
            String slotExtractionPrompt = cfg.slotExtractionPromptTemplateString.replaceAll('{user_input}', userInput);
            _isoLog.fine("Using slot extraction prompt string from AppConfig.");
            _isoLog.finest("Slot Extraction Prompt for LLM:\n$slotExtractionPrompt");

            final messagesForLlm = [{'role': 'user', 'content': slotExtractionPrompt}];

            final llmResponse = await _callLlmApiInIsolate(
                messages: messagesForLlm,
                modelName: cfg.slotExtractionModel,
                // Use the temperature from AppConfig for this specific task
                temperature: cfg.slotExtractionTemperature,
                maxTokens: cfg.slotExtractionMaxTokens,
                responseFormat: const ResponseFormat(type: "json_object"),
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
            final List<Map<String, dynamic>> historyJsonList = (summaryPayload['history'] as List<dynamic>).cast<Map<String, dynamic>>();
            final String? previousSummary = summaryPayload['previousSummary'] as String?;

            String historyStrForPrompt = historyJsonList.map((m) {
              String role = m['role'] ?? 'unknown';
              String content = m['content'] ?? '(내용 없음)';
              if (content.length > 200) content = "${content.substring(0,197)}...";
              return "$role: $content";
            }).join("\n");
            String summarizationPrompt = cfg.summarizationPromptTemplateString
                .replaceAll('{previous_summary}', previousSummary ?? "제공된 이전 요약 없음.")
                .replaceAll('{conversation_history}', historyStrForPrompt)
                .replaceAll('{target_summary_tokens}', cfg.targetSummaryTokens.toString());
            _isoLog.fine("Using summarization prompt string from AppConfig.");
            _isoLog.finest("Summarization Prompt for LLM:\n$summarizationPrompt");

            final messagesForLlm = [{'role': 'user', 'content': summarizationPrompt}];
            final llmResponse = await _callLlmApiInIsolate(
                messages: messagesForLlm,
                modelName: cfg.summarizationModel,
                // Use the temperature from AppConfig for this specific task
                temperature: cfg.summarizationTemperature,
                maxTokens: cfg.summarizationMaxTokens,
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
  required double temperature, // Temperature is now always passed from AppConfig
  required int maxTokens,
  ResponseFormat? responseFormat,
  required IsolateSetupData setupData,
  required Logger isoLog,
}) async {
  isoLog.fine('Calling LLM in Isolate. Model: $modelName, Msgs: ${messages.length}, Temp: $temperature, MaxTokens: $maxTokens, Endpoint: ${setupData.o3LlmApiFullEndpoint}');

  Map<String, dynamic> requestBodyMap = {
    'model': modelName,
    'messages': messages,
    // 'temperature': temperature, // Temporarily removed for testing, see below
  };

  // Conditionally add temperature based on the model name
  // This addresses the "Unsupported parameter: 'temperature'" for "o3-mini"
  // The error log states "Unsupported parameter: 'temperature' is not supported with THIS MODEL."
  // This implies that for the model used in slot extraction (cfg.slotExtractionModel),
  // the `temperature` parameter itself is not allowed by the API.
  // Note: The AppConfig DOES provide a temperature for slot_extraction (0.5 for o3-mini).
  // This solution respects the API error by omitting temperature for the specific model if it's "o3-mini".
  // If other models *do* support it, this is a specific fix.
  // A more robust system might involve the API advertising capabilities or a config flag per model.
  if (modelName.toLowerCase() != "o3-mini") { // Or use `setupData.appConfig.slotExtractionModel.toLowerCase()` if more dynamic
    requestBodyMap['temperature'] = temperature;
  } else {
    isoLog.info("Omitting 'temperature' parameter for model '$modelName' as it has been reported as unsupported for this model.");
  }


  if (modelName.toLowerCase().startsWith('o3')) { // Ensure correct token parameter name
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
      // Return the actual error structure from the API if possible
      try {
        final errorJson = jsonDecode(responseBodyString);
        if (errorJson is Map<String, dynamic> && errorJson.containsKey('error')) {
          return {'error': 'API Error: ${response.statusCode}', 'details_map': errorJson};
        }
      } catch (_) { /* Ignore if response body is not JSON */ }
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