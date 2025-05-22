// lib/tool_layer/tool_registry.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/tool_layer/tool_runner.dart';
import 'package:logging/logging.dart';

// Provider for the ToolRegistry
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  // ToolRegistry를 생성하고 여기에 모든 ToolRunner를 등록합니다.
  // 이 작업은 앱 초기화 시 한 번만 수행되는 것이 이상적입니다.
  // ChatOrchestrationServiceProvider 내에서 ToolRegistry를 생성하고 runner들을 등록할 수도 있습니다.
  // 여기서는 간단히 ToolRegistry 인스턴스만 반환하고, 등록은 사용하는 측에서 하도록 합니다.
  // 또는, 이 provider 내부에서 모든 runner를 생성하고 등록할 수 있습니다.
  // 후자의 경우, mock_api_tool_runners.dart의 runner들을 여기서 직접 생성/등록합니다.
  // 지금은 ChatOrchestrationService에서 등록한다고 가정합니다.
  return ToolRegistry();
});

class ToolRegistry {
  final _log = Logger('ToolRegistry');
  final Map<String, ToolRunner> _runners = {};

  void registerRunner(ToolRunner runner) {
    if (_runners.containsKey(runner.name)) {
      _log.warning("ToolRunner with name '${runner.name}' is already registered. It will be overwritten.");
    }
    _runners[runner.name] = runner;
    _log.info("ToolRunner registered: ${runner.name}");
  }

  void registerRunners(List<ToolRunner> runnersToRegister) {
    for (var runner in runnersToRegister) {
      registerRunner(runner);
    }
  }

  Future<Map<String, dynamic>> executeTool(String toolName, String argsJson, Ref ref) async {
    _log.info("Attempting to execute tool: '$toolName' with args: $argsJson");
    final runner = _runners[toolName];
    if (runner == null) {
      _log.severe("No ToolRunner found for tool name: '$toolName'");
      return {"error": "Tool not found: $toolName", "tool_name": toolName};
    }
    try {
      final result = await runner.run(argsJson, ref);
      _log.fine("Tool '$toolName' executed successfully. Result preview: ${jsonEncode(result).substring(0, (jsonEncode(result).length > 100 ? 100 : jsonEncode(result).length))}...");
      return result;
    } catch (e, s) {
      _log.severe("Error executing tool '$toolName': $e", e, s);
      return {"error": "Exception during tool execution: $e", "tool_name": toolName};
    }
  }
}