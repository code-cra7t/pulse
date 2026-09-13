import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ask_jotcue_engine.dart';

final askJotCueEngineProvider = Provider<AskJotCueEngine>((ref) {
  return const AskJotCueEngine();
});
