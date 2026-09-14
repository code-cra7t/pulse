import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/assistant/data/ai_gateway_client.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_engine.dart';
import 'package:pulse/features/assistant/data/hybrid_ask_jotcue_service.dart';
import 'package:pulse/features/assistant/models/ai_assistant_preferences.dart';
import 'package:pulse/features/assistant/models/ai_gateway.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10);
  const pulse = PulseOverview(
    focusItems: [],
    cues: [],
    upcomingProjects: [],
    openTaskCount: 1,
    overdueCount: 0,
    dueTodayCount: 0,
    focusEstimatedMinutes: 0,
  );
  final task = Task(
    id: 'task',
    userId: 'user',
    title: 'Revise chapter 4',
    isCompleted: false,
    sourceNoteId: 'note',
    sourceLineIndex: 0,
  );
  late final context = AskJotCueContext(
    now: now,
    userId: 'user',
    pulse: pulse,
    dailyLoop: DailyPulseLoop.build(now: now, pulse: pulse, blocks: const []),
    tasks: [task],
    projects: const [],
    blocks: const [],
  );

  test('local deterministic answer wins before gateway', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(answer: 'Remote answer'),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'What should I do now?',
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect(gateway.calls, 0);
    expect(answer.usedRemoteAi, isFalse);
  });

  test('local-only mode never calls gateway for unknown request', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(answer: 'A remote joke'),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'Tell me a joke',
      context: context,
      preferences: const AiAssistantPreferences(),
    );
    expect(gateway.calls, 0);
    expect(answer.usedRemoteAi, isFalse);
    expect(answer.text, contains('I don’t safely understand'));
  });

  test('hybrid mode stays local when gateway is not configured', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(answer: 'Should not be used'),
      configured: false,
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'Tell me a joke',
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect(gateway.calls, 0);
    expect(answer.usedRemoteAi, isFalse);
    expect(answer.text, contains('I don’t safely understand'));
  });

  test('oversized unknown query is never sent remotely', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(answer: 'Should not be used'),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: List.filled(2100, 'x').join(),
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect(gateway.calls, 0);
    expect(answer.text, contains('too long'));
  });

  test('hybrid mode may return an ephemeral prose answer', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(answer: 'Here is a bounded answer.'),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'Explain how to approach this week',
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect(gateway.calls, 1);
    expect(answer.usedRemoteAi, isTrue);
    expect(answer.text, 'Here is a bounded answer.');
  });

  test('explicit local capture wins before the gateway', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(answer: 'Should not be used'),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'Add task Buy groceries by Friday',
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );

    expect(gateway.calls, 0);
    expect(answer.actionProposal?.kind, AskJotCueActionKind.structuredCapture);
    expect(answer.usedRemoteAi, isFalse);
  });

  test(
    'hybrid capture tool still becomes an approval-gated local proposal',
    () async {
      final gateway = _FakeGateway(
        response: const AiGatewayResponse(
          toolCall: AiGatewayToolCall(
            name: 'capture.create',
            arguments: {'text': 'Submit HPC report by Sep 30'},
          ),
        ),
      );
      final service = HybridAskJotCueService(
        localEngine: const AskJotCueEngine(),
        gateway: gateway,
      );
      final answer = await service.answer(
        query: 'Please make sure I remember the HPC report',
        context: context,
        preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
      );

      expect(gateway.calls, 1);
      expect(answer.usedRemoteAi, isTrue);
      expect(
        answer.actionProposal?.kind,
        AskJotCueActionKind.structuredCapture,
      );
    },
  );

  test('hybrid tool response becomes ordinary local action proposal', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(
        toolCall: AiGatewayToolCall(
          name: 'task.set_completion',
          arguments: {'taskId': 'task', 'completed': true},
        ),
      ),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'Could you take care of chapter four for me?',
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect(answer.usedRemoteAi, isTrue);
    expect(answer.actionProposal?.kind, AskJotCueActionKind.taskCompletion);
  });

  test('malformed or unsupported tool fails closed without action', () async {
    final gateway = _FakeGateway(
      response: const AiGatewayResponse(
        toolCall: AiGatewayToolCall(
          name: 'email.send',
          arguments: {'to': 'someone@example.com'},
        ),
      ),
    );
    final service = HybridAskJotCueService(
      localEngine: const AskJotCueEngine(),
      gateway: gateway,
    );
    final answer = await service.answer(
      query: 'Send this to my lecturer',
      context: context,
      preferences: const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect(answer.actionProposal, isNull);
    expect(answer.text, contains('could not be safely used'));
  });
}

class _FakeGateway implements AiGatewayClient {
  _FakeGateway({required this.response, this.configured = true});

  final AiGatewayResponse response;
  final bool configured;
  int calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<AiGatewayResponse> respond({
    required String query,
    required Map<String, Object?> context,
    required List<Map<String, Object?>> allowedTools,
  }) async {
    calls += 1;
    return response;
  }
}
