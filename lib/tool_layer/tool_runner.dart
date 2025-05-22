// lib/tool_layer/tool_runner.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ToolRunner {
  String get name; // Tool의 이름 (LLM이 호출하는 함수명과 일치)

  /// Executes the tool with the given arguments.
  ///
  /// [argsJson] is a JSON string of arguments provided by the LLM.
  /// [ref] is the Riverpod Ref, allowing access to other providers/services if needed.
  /// Returns a [Map<String, dynamic>] which is the JSON-serializable result of the tool execution.
  Future<Map<String, dynamic>> run(String argsJson, Ref ref);
}