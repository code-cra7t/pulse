import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/assistant/models/ai_assistant_preferences.dart';
import 'offline_database_factory.dart';

typedef OpenAiAssistantOfflineDatabase = Future<Database> Function();

/// Device-local privacy preference for optional hybrid Ask JotCue assistance.
///
/// This is intentionally installation-scoped rather than cloud-synced. A user
/// must opt in again on each device before Ask JotCue may contact a gateway.
class OfflineAiAssistantStore {
  OfflineAiAssistantStore({OpenAiAssistantOfflineDatabase? openDatabase})
    : _openDatabase = openDatabase ?? openPulseNotesDatabase {
    _controller = StreamController<AiAssistantPreferences>.broadcast(
      onListen: () => unawaited(_emit()),
    );
  }

  static const _recordKey = 'device';

  final OpenAiAssistantOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('ai_assistant_preferences');
  late final StreamController<AiAssistantPreferences> _controller;
  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Stream<AiAssistantPreferences> watchPreferences() => _controller.stream;

  Future<AiAssistantPreferences> readPreferences() async {
    final data = await _store.record(_recordKey).get(await _database);
    return AiAssistantPreferences.fromLocalMap(data);
  }

  Future<void> writePreferences(AiAssistantPreferences preferences) async {
    await _store
        .record(_recordKey)
        .put(await _database, preferences.toLocalMap());
    await _emit();
  }

  Future<void> clearDevice() async {
    await _store.record(_recordKey).delete(await _database);
    await _emit();
  }

  Future<void> _emit() async {
    if (_controller.isClosed) return;
    _controller.add(await readPreferences());
  }

  Future<void> dispose() async {
    await _controller.close();
    final future = _databaseFuture;
    if (future != null) await (await future).close();
  }
}
