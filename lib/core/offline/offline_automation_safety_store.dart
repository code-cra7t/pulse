import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/automation/models/automation_safety_preferences.dart';
import 'offline_database_factory.dart';

typedef OpenAutomationSafetyOfflineDatabase = Future<Database> Function();

class OfflineAutomationSafetyStore {
  OfflineAutomationSafetyStore({
    OpenAutomationSafetyOfflineDatabase? openDatabase,
  }) : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenAutomationSafetyOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, dynamic>> _store = stringMapStoreFactory
      .store('automation_safety');
  final Map<String, StreamController<AutomationSafetyPreferences>>
  _controllers = {};

  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Stream<AutomationSafetyPreferences> watchPreferences(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<AutomationSafetyPreferences>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );
    unawaited(_emit(userId));
    return controller.stream;
  }

  Future<AutomationSafetyPreferences> readPreferences(String userId) async {
    final database = await _database;
    final data = await _store.record(userId).get(database);
    return AutomationSafetyPreferences.fromLocalMap(data);
  }

  Future<void> writePreferences(
    String userId,
    AutomationSafetyPreferences preferences,
  ) async {
    if (userId.isEmpty) {
      throw ArgumentError('Automation safety preferences require a user ID.');
    }
    final database = await _database;
    await _store.record(userId).put(database, preferences.toLocalMap());
    await _emit(userId);
  }

  Future<void> clearUser(String userId) async {
    final database = await _database;
    await _store.record(userId).delete(database);
    await _emit(userId);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();

    final databaseFuture = _databaseFuture;
    if (databaseFuture != null) {
      final database = await databaseFuture;
      await database.close();
    }
  }

  Future<void> _emit(String userId) async {
    final controller = _controllers[userId];
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(await readPreferences(userId));
  }
}
