import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_gateway.dart';

abstract class AiGatewayClient {
  bool get isConfigured;

  Future<AiGatewayResponse> respond({
    required String query,
    required Map<String, Object?> context,
    required List<Map<String, Object?>> allowedTools,
  });
}

class DisabledAiGatewayClient implements AiGatewayClient {
  const DisabledAiGatewayClient();

  @override
  bool get isConfigured => false;

  @override
  Future<AiGatewayResponse> respond({
    required String query,
    required Map<String, Object?> context,
    required List<Map<String, Object?>> allowedTools,
  }) {
    throw StateError('No JotCue AI gateway is configured for this build.');
  }
}

class HttpAiGatewayClient implements AiGatewayClient {
  HttpAiGatewayClient({
    required String endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _endpoint = Uri.tryParse(endpoint.trim()),
       _client = client ?? http.Client();

  static const int _maxResponseBytes = 64 * 1024;

  final Uri? _endpoint;
  final http.Client _client;
  final Duration timeout;

  void close() => _client.close();

  @override
  bool get isConfigured {
    final endpoint = _endpoint;
    if (endpoint == null || !endpoint.hasScheme || endpoint.host.isEmpty) {
      return false;
    }
    if (endpoint.scheme == 'https') return true;
    if (endpoint.scheme != 'http') return false;
    return endpoint.host == 'localhost' ||
        endpoint.host == '127.0.0.1' ||
        endpoint.host == '::1';
  }

  @override
  Future<AiGatewayResponse> respond({
    required String query,
    required Map<String, Object?> context,
    required List<Map<String, Object?>> allowedTools,
  }) async {
    final endpoint = _endpoint;
    if (!isConfigured || endpoint == null) {
      throw StateError('The configured AI gateway URL is invalid.');
    }

    final response = await _client
        .post(
          endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'query': query,
            'context': context,
            'allowedTools': allowedTools,
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('AI gateway returned HTTP ${response.statusCode}.');
    }
    if (response.bodyBytes.length > _maxResponseBytes) {
      throw StateError('AI gateway response exceeded the safe size limit.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('AI gateway returned an invalid response.');
    }
    final answer = decoded['answer'];
    final tool = decoded['toolCall'];
    AiGatewayToolCall? toolCall;
    if (tool is Map<String, dynamic>) {
      final name = tool['name'];
      final arguments = tool['arguments'];
      if (name is String && arguments is Map<String, dynamic>) {
        toolCall = AiGatewayToolCall(
          name: name,
          arguments: Map<String, Object?>.from(arguments),
        );
      }
    }
    final result = AiGatewayResponse(
      answer: answer is String ? answer.trim() : null,
      toolCall: toolCall,
    );
    if (!result.hasUsableContent) {
      throw StateError('AI gateway returned no usable answer or tool call.');
    }
    return result;
  }
}
