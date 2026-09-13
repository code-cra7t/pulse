import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/automation/models/automation_audit_entry.dart';
import 'offline_database_factory.dart';

typedef OpenAutomationAuditOfflineDatabase = Future<Database> Function();

class OfflineAutomationAuditStore {
  OfflineAutomationAuditStore({
    OpenAutomationAuditOfflineDatabase? openDatabase,
    this.maxEntriesPerUser = 100,
  }) : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenAutomationAuditOfflineDatabase _openDatabase;
  final int maxEntriesPerUser;
  final StoreRef<String, Map<String, dynamic>> _store = stringMapStoreFactory
      .store('automation_audit');
  final Map<String, StreamController<List<AutomationAuditEntry>>> _controllers =
      {};

  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  String _key(String userId, String entryId) => '$userId::$entryId';

  Stream<List<AutomationAuditEntry>> watchEntries(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<List<AutomationAuditEntry>>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );
    unawaited(_emit(userId));
    return controller.stream;
  }

  Future<List<AutomationAuditEntry>> readEntries(String userId) async {
    final database = await _database;
    final snapshots = await _store.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('executedAtMs', false)],
      ),
    );
    return snapshots
        .map((snapshot) => AutomationAuditEntry.fromLocalMap(snapshot.value))
        .where((entry) => entry.id.isNotEmpty && entry.userId == userId)
        .toList(growable: false);
  }

  Future<void> upsert(AutomationAuditEntry entry) async {
    if (entry.id.isEmpty || entry.userId.isEmpty) {
      throw ArgumentError('Automation audit entries require IDs and a user.');
    }
    final database = await _database;
    await _store
        .record(_key(entry.userId, entry.id))
        .put(database, entry.toLocalMap());
    await _trim(database, entry.userId);
    await _emit(entry.userId);
  }

  Future<void> clearUser(String userId) async {
    final database = await _database;
    await _store.delete(
      database,
      finder: Finder(filter: Filter.equals('userId', userId)),
    );
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

  Future<void> _trim(Database database, String userId) async {
    if (maxEntriesPerUser <= 0) {
      return;
    }
    final snapshots = await _store.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('executedAtMs', false)],
      ),
    );
    if (snapshots.length <= maxEntriesPerUser) {
      return;
    }
    for (final snapshot in snapshots.skip(maxEntriesPerUser)) {
      await _store.record(snapshot.key).delete(database);
    }
  }

  Future<void> _emit(String userId) async {
    final controller = _controllers[userId];
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(await readEntries(userId));
  }
}
