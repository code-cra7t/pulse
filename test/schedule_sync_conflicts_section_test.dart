import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_block_sync_conflict.dart';
import 'package:pulse/features/scheduling/presentation/widgets/schedule_sync_conflicts_section.dart';

void main() {
  testWidgets('schedule sync review stays readable at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final local = _block(DateTime(2026, 9, 14, 9), 1);
    final remote = _block(DateTime(2026, 9, 14, 11), 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleSyncConflictsSection(
              state: AsyncData([
                ScheduleBlockSyncConflict(
                  id: 'conflict',
                  userId: 'user',
                  blockId: 'block',
                  kind: ScheduleBlockSyncConflictKind.remoteChanged,
                  detectedAt: DateTime(2026, 9, 13),
                  localBlock: local,
                  remoteBlock: remote,
                ),
              ]),
              onDismiss: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Schedule sync review'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ScheduleBlock _block(DateTime start, int revision) => ScheduleBlock(
  id: 'block',
  userId: 'user',
  taskId: 'task',
  title: 'Write chapter',
  startsAt: start,
  endsAt: start.add(const Duration(hours: 1)),
  createdAt: DateTime(2026, 9, 13),
  updatedAt: DateTime(2026, 9, 13, 10),
  revision: revision,
);
