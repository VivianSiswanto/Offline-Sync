import 'package:flutter/foundation.dart';
import '../data/local/item_local_store.dart';
import '../data/remote/sync_api.dart';
import 'retry_policy.dart';
import 'sync_state.dart';

class SyncEngine {
  SyncEngine({
    required this.local,
    required this.api,
    RetryPolicy? retryPolicy,
    this.batchSize = 50,
    this.onDataChanged,
  }) : _retry = retryPolicy ?? RetryPolicy();

  final ItemLocalStore local;
  final SyncApi api;
  final RetryPolicy _retry;
  final int batchSize;
  final void Function()? onDataChanged;

  final ValueNotifier<SyncState> state = ValueNotifier(const SyncState());

  bool _running = false;
  bool _rerunRequested = false;

  Future<void> sync() async {
    if (_running) {
      _rerunRequested = true;
      return;
    }

    _running = true;
    state.value = state.value.copywith(phase: SyncPhase.syncing);

    try {
      do {
        _rerunRequested = false;
        await _pushPending();
        await _pullChanges();
      } while (_rerunRequested);

      state.value = SyncState(
        phase: SyncPhase.idle,
        pendingCount: await local.pendingCount(),
        lastSyncedAt: DateTime.now(),
      );
    } on SyncException catch (e) {
      state.value = SyncState(
        phase: e.retryable ? SyncPhase.offline : SyncPhase.error,
        pendingCount: await local.pendingCount(),
        lastSyncedAt: state.value.lastSyncedAt,
        message: e.message,
      );
    } catch (e) {
      state.value = SyncState(
        phase: SyncPhase.error,
        pendingCount: await local.pendingCount(),
        lastSyncedAt: state.value.lastSyncedAt,
        message: e.toString(),
      );
    } finally {
      _running = false;
    }
  }

  Future<void> refreshPendingCount() async {
    state.value = state.value.copywith(
      pendingCount: await local.pendingCount(),
    );
  }

  Future<void> _pushPending() async {
    while (true) {
      final batch = await local.getPending(limit: batchSize);
      if (batch.isEmpty) return;

      final result = await _retry.run(
        () => api.push(batch),
        retryIf: _isRetryable,
      );

      var anyAccepted = false;
      for (final item in batch) {
        if (result.accepted.contains(item.id)) {
          await local.markSynced(item.id, item.updatedAt);
          anyAccepted = true;
        }
      }
      onDataChanged?.call();

      if (!anyAccepted) {
        throw SyncException('Server accepted nothing', retryable: false);
      }

      if (batch.length < batchSize) return;
    }
  }

  Future<void> _pullChanges() async {
    var cursor = await local.getPullCursor();
    while (true) {
      final page = await _retry.run(
        () => api.pull(cursor),
        retryIf: _isRetryable,
      );

      if (page.changes.isEmpty) return;
      await local.applyRemoteChanges(page.changes, page.cursor);
      onDataChanged?.call();
      cursor = page.cursor;
    }
  }

  bool _isRetryable(Object error) => error is SyncException && error.retryable;
}
