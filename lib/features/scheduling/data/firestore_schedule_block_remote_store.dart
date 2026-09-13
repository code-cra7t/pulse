import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/schedule_block.dart';
import 'schedule_block_remote_store.dart';

class FirestoreScheduleBlockRemoteStore implements ScheduleBlockRemoteStore {
  FirestoreScheduleBlockRemoteStore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('scheduleBlocks');
  }

  @override
  Stream<List<ScheduleBlock>> watchBlocks(String userId) {
    return _collection(userId)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.isFromCache)
        .map(
          (snapshot) => snapshot.docs
              .map(ScheduleBlock.fromFirestore)
              .where((block) => block.isValid && block.userId == userId)
              .toList(growable: false),
        );
  }

  @override
  Future<List<ScheduleBlock>> readBlocks(String userId) async {
    final snapshot = await _collection(
      userId,
    ).get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map(ScheduleBlock.fromFirestore)
        .where((block) => block.isValid && block.userId == userId)
        .toList(growable: false);
  }

  @override
  Future<ScheduleBlock> upsert({
    required ScheduleBlock block,
    required int baseRevision,
  }) {
    final reference = _collection(block.userId).doc(block.id);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      ScheduleBlock? remote;
      if (snapshot.exists) {
        remote = ScheduleBlock.fromFirestore(snapshot);
      }

      if (baseRevision == 0) {
        if (remote != null) {
          throw ScheduleBlockRemoteConflict(
            blockId: block.id,
            baseRevision: baseRevision,
            remoteBlock: remote,
          );
        }
      } else if (remote == null || remote.revision != baseRevision) {
        throw ScheduleBlockRemoteConflict(
          blockId: block.id,
          baseRevision: baseRevision,
          remoteBlock: remote,
        );
      }

      final canonical = block.copyWith(revision: baseRevision + 1);
      transaction.set(reference, canonical.toRemoteMap());
      return canonical;
    });
  }

  @override
  Future<void> delete({
    required String userId,
    required String blockId,
    required int baseRevision,
  }) async {
    final reference = _collection(userId).doc(blockId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        // The desired end state already exists. Treat an already-remote-deleted
        // block as a successful idempotent delete.
        return;
      }
      final remote = ScheduleBlock.fromFirestore(snapshot);
      if (baseRevision <= 0 || remote.revision != baseRevision) {
        throw ScheduleBlockRemoteConflict(
          blockId: blockId,
          baseRevision: baseRevision,
          remoteBlock: remote,
        );
      }
      transaction.delete(reference);
    });
  }
}
