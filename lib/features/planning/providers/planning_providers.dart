import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/planning_service.dart';

final planningServiceProvider = Provider<PlanningService>((ref) {
  return PlanningService(
    ref.watch(taskServiceProvider),
    ref.watch(projectsRepositoryProvider),
  );
});
