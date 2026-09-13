import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/providers/notes_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../data/capture_service.dart';
import '../data/natural_language_capture_parser.dart';

final naturalLanguageCaptureParserProvider =
    Provider<NaturalLanguageCaptureParser>(
      (ref) => NaturalLanguageCaptureParser(),
    );

final captureServiceProvider = Provider<CaptureService>((ref) {
  return CaptureService(
    ref.watch(notesServiceProvider),
    ref.watch(projectsRepositoryProvider),
  );
});
