import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/scheduling/models/schedule_block.dart';
import 'offline_database_factory.dart';

typedef OpenScheduleBlocksOfflineDatabase = Future<Database> Function();

class OfflineScheduleBlockStore {
  OfflineScheduleBlockStore({OpenScheduleBlocksOfflineDatabase? openDatabase})
    : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenScheduleBlocksOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, dynamic>> _store = stringMapStoreFactory
      .store('schedule_blocks');
  final Map<String, StreamController<List<ScheduleBlock>>> _controllers = {};

  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  String _key(String userId, String blockId) => '$userId::$blockId';

  Stream<List<ScheduleBlock>> watchBlocks(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<List<ScheduleBlock>>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );
    unawaited(_emit(userId));
    return controller.stream;
  }

  Future<List<ScheduleBlock>> readBlocks(String userId) async {
    final database = await _database;
    final snapshots = await _store.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('startsAtMs'), SortOrder('createdAtMs')],
      ),
    );
    return snapshots
        .map((snapshot) => ScheduleBlock.fromLocalMap(snapshot.value))
        .where((block) => block.isValid)
        .toList(growable: false);
  }

  Future<void> upsert(ScheduleBlock block) async {
    if (!block.isValid) {
      throw ArgumentError('Schedule block end must be after its start.');
    }
    final database = await _database;
    await _store
        .record(_key(block.userId, block.id))
        .put(database, block.toLocalMap());
    await _emit(block.userId);
  }

  Future<void> delete(String userId, String blockId) async {
    final database = await _database;
    await _store.record(_key(userId, blockId)).delete(database);
    await _emit(userId);
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

  Future<void> _emit(String userId) async {
    final controller = _controllers[userId];
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(await readBlocks(userId));
  }
}
