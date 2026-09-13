class AiGatewayToolCall {
  const AiGatewayToolCall({required this.name, required this.arguments});

  final String name;
  final Map<String, Object?> arguments;
}

class AiGatewayResponse {
  const AiGatewayResponse({this.answer, this.toolCall});

  final String? answer;
  final AiGatewayToolCall? toolCall;

  bool get hasUsableContent =>
      (answer?.trim().isNotEmpty ?? false) || toolCall != null;
}
