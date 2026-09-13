import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/pending_schedule_block_mutation.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_block_sync_conflict.dart';

void main() {
  test('schedule block local round-trip preserves cloud revision', () {
    final block = _block('one', 7);
    final restored = ScheduleBlock.fromLocalMap(block.toLocalMap());

    expect(restored.id, block.id);
    expect(restored.revision, 7);
    expect(restored.startsAt, block.startsAt);
  });

  test('pending mutation and conflict round-trip retain revision context', () {
    final block = _block('one', 4);
    final mutation = PendingScheduleBlockMutation(
      id: 'mutation',
      userId: 'user',
      blockId: block.id,
      type: PendingScheduleBlockMutationType.upsert,
      baseRevision: 4,
      payload: block.toLocalMap(),
      createdAt: DateTime(2026, 9, 13, 10),
    );
    final restoredMutation = PendingScheduleBlockMutation.fromLocalMap(
      mutation.toLocalMap(),
    );
    expect(restoredMutation.baseRevision, 4);

    final conflict = ScheduleBlockSyncConflict(
      id: 'conflict',
      userId: 'user',
      blockId: block.id,
      kind: ScheduleBlockSyncConflictKind.remoteChanged,
      detectedAt: DateTime(2026, 9, 13, 11),
      localBlock: block,
      remoteBlock: block.copyWith(revision: 5),
    );
    final restoredConflict = ScheduleBlockSyncConflict.fromLocalMap(
      conflict.toLocalMap(),
    );
    expect(restoredConflict.localBlock?.revision, 4);
    expect(restoredConflict.remoteBlock?.revision, 5);
  });
}

ScheduleBlock _block(String id, int revision) => ScheduleBlock(
  id: id,
  userId: 'user',
  taskId: 'task-$id',
  title: 'Task $id',
  startsAt: DateTime(2026, 9, 14, 9),
  endsAt: DateTime(2026, 9, 14, 10),
  createdAt: DateTime(2026, 9, 13, 8),
  updatedAt: DateTime(2026, 9, 13, 9),
  revision: revision,
);
