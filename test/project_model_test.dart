import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/projects/models/project.dart';

void main() {
  test('project local serialization round-trips planning fields', () {
    final project = Project(
      id: 'project-1',
      userId: 'user-1',
      name: 'Life insurance exam',
      description: 'Prepare for the October exam',
      status: ProjectStatus.active,
      priority: PriorityLevel.critical,
      deadline: DateTime(2026, 10, 2),
      targetMinutesPerWeek: 600,
      createdAt: DateTime(2026, 9, 12, 10),
      updatedAt: DateTime(2026, 9, 12, 11),
    );

    final restored = Project.fromLocalMap(project.toLocalMap());

    expect(restored.id, project.id);
    expect(restored.userId, project.userId);
    expect(restored.name, project.name);
    expect(restored.description, project.description);
    expect(restored.status, ProjectStatus.active);
    expect(restored.priority, PriorityLevel.critical);
    expect(restored.deadline, project.deadline);
    expect(restored.targetMinutesPerWeek, 600);
    expect(restored.createdAt, project.createdAt);
    expect(restored.updatedAt, project.updatedAt);
  });

  test(
    'project Firestore payload uses timestamps and nullable planning fields',
    () {
      final project = Project(
        id: 'project-2',
        userId: 'user-1',
        name: 'Agency',
        description: 'Build first-client system',
        status: ProjectStatus.paused,
        priority: PriorityLevel.high,
        createdAt: DateTime(2026, 9, 12, 10),
        updatedAt: DateTime(2026, 9, 12, 11),
      );

      final map = project.toMap();

      expect(map['userId'], 'user-1');
      expect(map['name'], 'Agency');
      expect(map['status'], 'paused');
      expect(map['priority'], 'high');
      expect(map['deadline'], isNull);
      expect(map['targetMinutesPerWeek'], isNull);
      expect(map['createdAt'], isNotNull);
      expect(map['updatedAt'], isNotNull);
    },
  );
}
