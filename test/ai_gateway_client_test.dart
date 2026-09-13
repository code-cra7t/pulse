import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse/features/assistant/data/ai_gateway_client.dart';

void main() {
  test('gateway rejects ordinary insecure HTTP endpoints', () {
    final client = HttpAiGatewayClient(endpoint: 'http://example.com/ai');
    expect(client.isConfigured, isFalse);
  });

  test('localhost HTTP is allowed for development', () {
    final client = HttpAiGatewayClient(endpoint: 'http://localhost:8080/ai');
    expect(client.isConfigured, isTrue);
  });

  test('gateway sends schema and parses a strict tool response', () async {
    late Map<String, dynamic> requestBody;
    final client = HttpAiGatewayClient(
      endpoint: 'https://assistant.example.test/respond',
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'toolCall': {
              'name': 'task.set_completion',
              'arguments': {'taskId': 'task', 'completed': true},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.respond(
      query: 'finish it',
      context: const {'tasks': []},
      allowedTools: const [
        {'name': 'task.set_completion'},
      ],
    );
    expect(requestBody['schemaVersion'], 1);
    expect(requestBody['query'], 'finish it');
    expect(result.toolCall?.name, 'task.set_completion');
    expect(result.toolCall?.arguments['completed'], isTrue);
  });
}
