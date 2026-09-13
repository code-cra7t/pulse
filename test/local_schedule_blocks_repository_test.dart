import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_schedule_block_store.dart';
import 'package:pulse/features/scheduling/data/local_schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineScheduleBlockStore store;
  late LocalScheduleBlocksRepository repository;

  setUp(() {
    final databaseName =
        'jotcue-schedule-repo-${DateTime.now().microsecondsSinceEpoch}.db';
    store = OfflineScheduleBlockStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
    );
    repository = LocalScheduleBlocksRepository(store);
  });

  tearDown(() async {
    await store.dispose();
  });

  test('accepts a proposal into a device-local schedule block', () async {
    final proposal = _proposal(
      'one',
      DateTime(2026, 9, 14, 9),
      DateTime(2026, 9, 14, 10),
    );

    final block = await repository.acceptProposal(
      userId: 'user',
      proposal: proposal,
    );

    expect(block.taskId, 'one');
    expect(block.title, 'Task one');
    expect(await repository.readBlocks('user'), hasLength(1));
  });

  test('rejects an accepted proposal if its time now conflicts', () async {
    await repository.acceptProposal(
      userId: 'user',
      proposal: _proposal(
        'one',
        DateTime(2026, 9, 14, 9),
        DateTime(2026, 9, 14, 10),
      ),
    );

    await expectLater(
      repository.acceptProposal(
        userId: 'user',
        proposal: _proposal(
          'two',
          DateTime(2026, 9, 14, 9, 30),
          DateTime(2026, 9, 14, 10, 30),
        ),
      ),
      throwsStateError,
    );
  });
}

ScheduleProposal _proposal(String taskId, DateTime start, DateTime end) {
  return ScheduleProposal(
    id: 'proposal-$taskId',
    taskId: taskId,
    title: 'Task $taskId',
    startsAt: start,
    endsAt: end,
    reason: 'Test',
    score: 1,
    assumedEffort: false,
  );
}
