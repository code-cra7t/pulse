import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_schedule_block_store.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineScheduleBlockStore store;

  setUp(() {
    final databaseName =
        'jotcue-schedule-test-${DateTime.now().microsecondsSinceEpoch}.db';
    store = OfflineScheduleBlockStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
    );
  });

  tearDown(() async {
    await store.dispose();
  });

  test('persists and orders accepted schedule blocks locally', () async {
    final later = _block('later', DateTime(2026, 9, 14, 14));
    final earlier = _block('earlier', DateTime(2026, 9, 14, 9));

    await store.upsert(later);
    await store.upsert(earlier);

    final blocks = await store.readBlocks('user');
    expect(blocks.map((block) => block.id), ['earlier', 'later']);
    expect(blocks.first.title, 'Task earlier');
  });

  test('updates status without changing the visible block title', () async {
    final block = _block('block', DateTime(2026, 9, 14, 9));
    await store.upsert(block);
    await store.upsert(
      block.copyWith(
        status: ScheduleBlockStatus.completed,
        updatedAt: DateTime(2026, 9, 14, 10),
      ),
    );

    final stored = (await store.readBlocks('user')).single;
    expect(stored.status, ScheduleBlockStatus.completed);
    expect(stored.title, 'Task block');
  });

  test('clearUser removes only that user schedule blocks', () async {
    await store.upsert(_block('one', DateTime(2026, 9, 14, 9)));
    await store.upsert(
      ScheduleBlock(
        id: 'two',
        userId: 'other',
        taskId: 'task-two',
        title: 'Other task',
        startsAt: DateTime(2026, 9, 14, 11),
        endsAt: DateTime(2026, 9, 14, 12),
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      ),
    );

    await store.clearUser('user');

    expect(await store.readBlocks('user'), isEmpty);
    expect(await store.readBlocks('other'), hasLength(1));
  });
}

ScheduleBlock _block(String id, DateTime start) {
  return ScheduleBlock(
    id: id,
    userId: 'user',
    taskId: 'task-$id',
    title: 'Task $id',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    createdAt: DateTime(2026, 9, 13),
    updatedAt: DateTime(2026, 9, 13),
  );
}
