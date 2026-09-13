import 'ai_context_minimizer.dart';
import 'ai_gateway_client.dart';
import 'ai_tool_proposal_adapter.dart';
import 'ask_jotcue_engine.dart';
import '../models/ai_assistant_preferences.dart';
import '../models/ask_jotcue.dart';

class HybridAskJotCueService {
  const HybridAskJotCueService({
    required AskJotCueEngine localEngine,
    required AiGatewayClient gateway,
    this.contextMinimizer = const AiContextMinimizer(),
    this.toolAdapter = const AiToolProposalAdapter(),
  }) : _localEngine = localEngine,
       _gateway = gateway;

  final AskJotCueEngine _localEngine;
  final AiGatewayClient _gateway;
  final AiContextMinimizer contextMinimizer;
  final AiToolProposalAdapter toolAdapter;

  bool get gatewayConfigured => _gateway.isConfigured;

  Future<AskJotCueAnswer> answer({
    required String query,
    required AskJotCueContext context,
    required AiAssistantPreferences preferences,
  }) async {
    final local = _localEngine.answer(query: query, context: context);
    if (local.intent != AskJotCueIntent.unknown ||
        !preferences.usesRemoteGateway ||
        !_gateway.isConfigured) {
      return local;
    }

    if (query.runes.length > 2000) {
      return _safeFallback(
        local,
        'This request is too long to send through Hybrid assistance.',
      );
    }

    try {
      final response = await _gateway.respond(
        query: query,
        context: contextMinimizer.build(context),
        allowedTools: AiToolProposalAdapter.allowedTools,
      );
      final call = response.toolCall;
      if (call != null) {
        final proposal = toolAdapter.adapt(call, context);
        if (proposal != null) {
          return AskJotCueAnswer(
            intent: AskJotCueIntent.action,
            title: 'AI-assisted action preview',
            text:
                'Hybrid assistance interpreted your request as the change below. Nothing has changed yet.',
            actionProposal: proposal,
            usedRemoteAi: true,
          );
        }
      }
      final answer = response.answer?.trim();
      if (answer != null && answer.isNotEmpty) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.unknown,
          title: 'AI-assisted answer',
          text: answer,
          usedRemoteAi: true,
        );
      }
      return _safeFallback(local, 'The AI response could not be safely used.');
    } catch (_) {
      return _safeFallback(
        local,
        'Hybrid assistance is temporarily unavailable.',
      );
    }
  }

  AskJotCueAnswer _safeFallback(AskJotCueAnswer local, String reason) {
    return AskJotCueAnswer(
      intent: local.intent,
      title: local.title,
      text: '${local.text}\n\n$reason Nothing was changed.',
    );
  }
}
