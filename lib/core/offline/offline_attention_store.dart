import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/attention/models/attention_preferences.dart';
import 'offline_database_factory.dart';

typedef OpenAttentionOfflineDatabase = Future<Database> Function();

class AttentionDeliveryState {
  const AttentionDeliveryState({
    this.fingerprint = '',
    this.notificationIds = const <int>[],
    this.lastIssueSignature,
    this.lastIssueAlertAt,
  });

  final String fingerprint;
  final List<int> notificationIds;
  final String? lastIssueSignature;
  final DateTime? lastIssueAlertAt;

  Map<String, Object?> toMap() => {
    'fingerprint': fingerprint,
    'notificationIds': notificationIds,
    'lastIssueSignature': lastIssueSignature,
    'lastIssueAlertAt': lastIssueAlertAt?.toIso8601String(),
  };

  factory AttentionDeliveryState.fromMap(Map<String, Object?>? data) {
    if (data == null) return const AttentionDeliveryState();
    return AttentionDeliveryState(
      fingerprint: data['fingerprint'] as String? ?? '',
      notificationIds:
          (data['notificationIds'] as List?)?.whereType<int>().toList() ??
          const <int>[],
      lastIssueSignature: data['lastIssueSignature'] as String?,
      lastIssueAlertAt: DateTime.tryParse(
        data['lastIssueAlertAt'] as String? ?? '',
      ),
    );
  }
}

class OfflineAttentionStore {
  OfflineAttentionStore({OpenAttentionOfflineDatabase? openDatabase})
    : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenAttentionOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, Object?>> _preferences =
      stringMapStoreFactory.store('attention_preferences');
  final StoreRef<String, Map<String, Object?>> _delivery = stringMapStoreFactory
      .store('attention_delivery');
  final Map<String, StreamController<AttentionPreferences>> _controllers = {};
  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Stream<AttentionPreferences> watchPreferences(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<AttentionPreferences>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );
    unawaited(_emit(userId));
    return controller.stream;
  }

  Future<AttentionPreferences> readPreferences(String userId) async {
    final data = await _preferences.record(userId).get(await _database);
    return AttentionPreferences.fromLocalMap(data);
  }

  Future<void> writePreferences(
    String userId,
    AttentionPreferences value,
  ) async {
    if (userId.isEmpty || !value.isValid) {
      throw ArgumentError('Invalid attention preferences.');
    }
    await _preferences.record(userId).put(await _database, value.toLocalMap());
    await _emit(userId);
  }

  Future<AttentionDeliveryState> readDelivery(String userId) async {
    final data = await _delivery.record(userId).get(await _database);
    return AttentionDeliveryState.fromMap(data);
  }

  Future<void> writeDelivery(
    String userId,
    AttentionDeliveryState value,
  ) async {
    await _delivery.record(userId).put(await _database, value.toMap());
  }

  Future<void> clearUser(String userId) async {
    final db = await _database;
    await _preferences.record(userId).delete(db);
    await _delivery.record(userId).delete(db);
    await _emit(userId);
  }

  Future<void> _emit(String userId) async {
    final controller = _controllers[userId];
    if (controller == null || controller.isClosed) return;
    controller.add(await readPreferences(userId));
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    final future = _databaseFuture;
    if (future != null) await (await future).close();
  }
}
