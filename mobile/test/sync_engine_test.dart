import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sync/data/local/item_local_store.dart';
import 'package:offline_sync/data/local/merge_rules.dart';
import 'package:offline_sync/data/remote/sync_api.dart';
import 'package:offline_sync/domain/entities/item.dart';
import 'package:offline_sync/sync/retry_policy.dart';
import 'package:offline_sync/sync/sync_engine.dart';
import 'package:offline_sync/sync/sync_state.dart';

// In-memory phone database
class FakeLocalStore implements ItemLocalStore {
  final Map<String, Item> rows = {};
  int cursor = 0;

  @override
  Future<List<Item>> getVisible() async =>
      rows.values.where((e) => !e.isDeleted).toList();

  @override
  Future<Item?> getById(String id) async => rows[id];

  @override
  Future<void> upsert(Item item) async => rows[item.id] = item;

  @override
  Future<List<Item>> getPending({required int limit}) async {
    final pending = rows.values.where((e) => e.isPending).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return pending.take(limit).toList();
  }

  @override
  Future<void> markSynced(String id, DateTime sentUpdatedAt) async {
    final e = rows[id];
    if (e != null && e.updatedAt == sentUpdatedAt) {
      rows[id] = e.copyWith(syncStatus: SyncStatus.synced);
    }
  }

  @override
  Future<int> pendingCount() async =>
      rows.values.where((e) => e.isPending).length;

  @override
  Future<int> getPullCursor() async => cursor;

  @override
  Future<void> applyRemoteChanges(List<Item> changes, int newCursor) async {
    for (final remote in changes) {
      if (shouldApplyRemote(local: rows[remote.id], remote: remote)) {
        rows[remote.id] = remote;
      }
    }
    cursor = newCursor;
  }
}

// In-memory server that follows the same rules as your .NET SyncService
class FakeServer implements SyncApi {
  final Map<String, Item> rows = {};
  final Map<String, int> versions = {};
  int _version = 0;

  bool offline = false;
  int failNextCalls = 0;
  int pushCalls = 0;
  Future<void> Function()? duringPush;

  void _maybeFail() {
    if (offline) throw SyncException('offline', retryable: true);
    if (failNextCalls > 0) {
      failNextCalls--;
      throw SyncException('flaky network', retryable: true);
    }
  }

  @override
  Future<PushResult> push(List<Item> changes) async {
    pushCalls++;
    _maybeFail();
    await duringPush?.call();

    for (final c in changes) {
      final existing = rows[c.id];
      if (existing == null || c.updatedAt.isAfter(existing.updatedAt)) {
        rows[c.id] = c.copyWith(syncStatus: SyncStatus.synced);
        versions[c.id] = ++_version;
      } else if (c.updatedAt.isBefore(existing.updatedAt)) {
        versions[c.id] = ++_version;
      }
    }
    return PushResult(accepted: changes.map((c) => c.id).toSet());
  }

  @override
  Future<PullResult> pull(int since) async {
    _maybeFail();
    final changed = rows.values.where((e) => versions[e.id]! > since).toList()
      ..sort((a, b) => versions[a.id]!.compareTo(versions[b.id]!));
    return PullResult(
      changes: changed,
      cursor: changed.isEmpty ? since : versions[changed.last.id]!,
    );
  }
}

Item makeItem(String id, {String title = 'Item', int minute = 0}) => Item(
  id: id,
  title: title,
  updatedAt: DateTime.utc(2026, 11, 23, 10, minute),
);

void main() {
  late FakeLocalStore local;
  late FakeServer server;
  late List<Duration> sleeps;
  late SyncEngine engine;

  setUp(() {
    local = FakeLocalStore();
    server = FakeServer();
    sleeps = [];
    engine = SyncEngine(
      local: local,
      api: server,
      batchSize: 2,
      retryPolicy: RetryPolicy(
        random: Random(1),
        sleep: (d) async => sleeps.add(d),
      ),
    );
  });

  test('pushes pending changes in batches and marks them synced', () async {
    for (var i = 0; i < 5; i++) {
      await local.upsert(makeItem('id-$i', minute: i));
    }

    await engine.sync();

    expect(server.rows.length, 5);
    expect(await local.pendingCount(), 0);
    expect(server.pushCalls, 3);
    expect(engine.state.value.phase, SyncPhase.idle);
  });

  test(
    'offline: nothing is lost, items stay pending, and sync later succeeds',
    () async {
      await local.upsert(makeItem('a'));
      server.offline = true;

      await engine.sync();

      expect(engine.state.value.phase, SyncPhase.offline);
      expect(await local.pendingCount(), 1);
      expect(server.rows, isEmpty);

      server.offline = false;
      await engine.sync();

      expect(await local.pendingCount(), 0);
      expect(server.rows.containsKey('a'), isTrue);
    },
  );

  test('retries transient failures with exponential backoff', () async {
    await local.upsert(makeItem('a'));
    server.failNextCalls = 2;

    await engine.sync();

    expect(await local.pendingCount(), 0);
    expect(sleeps.length, 2);
    expect(sleeps[0].inMilliseconds, inInclusiveRange(250, 500));
    expect(sleeps[1].inMilliseconds, inInclusiveRange(500, 1000));
  });

  test('an edit made while a push is in flight stays pending', () async {
    await local.upsert(makeItem('a', title: 'Original', minute: 0));

    server.duringPush = () async {
      server.duringPush = null;
      await local.upsert(makeItem('a', title: 'Edited', minute: 5));
    };

    await engine.sync();
    expect(local.rows['a']!.title, 'Edited');
    expect(local.rows['a']!.isPending, isTrue);
  });

  test('pulls changes made on another device', () async {
    await server.push([makeItem('from-laptop', title: 'From laptop')]);
    await engine.sync();
    expect(local.rows['from-laptop']!.title, 'From laptop');
    expect(local.rows['from-laptop']!.isPending, isFalse);
    expect(local.cursor, 1);
  });

  test('a losing edit is replaced by the newer server copy', () async {
    await local.upsert(makeItem('a', title: 'Original', minute: 0));
    await engine.sync();

    await server.push([makeItem('a', title: 'Newer on laptop', minute: 30)]);
    await local.upsert(makeItem('a', title: 'Older on phone', minute: 10));

    await engine.sync();

    expect(server.rows['a']!.title, 'Newer on laptop');
    expect(local.rows['a']!.title, 'Newer on laptop');
    expect(local.rows['a']!.isPending, isFalse);
  });

  test('deletes sync as tombstones and disappear from the list', () async {
    await local.upsert(makeItem('a'));
    await engine.sync();

    await local.upsert(
      local.rows['a']!.copyWith(
        isDeleted: true,
        updatedAt: DateTime.utc(2026, 11, 23, 11),
        syncStatus: SyncStatus.pending,
      ),
    );
    await engine.sync();

    expect(server.rows['a']!.isDeleted, isTrue);
    expect(await local.getVisible(), isEmpty);
  });

  group('shouldApplyRemote', () {
    final remote = makeItem(
      'a',
      minute: 5,
    ).copyWith(syncStatus: SyncStatus.synced);

    test('applies when there is no local copy', () {
      expect(shouldApplyRemote(local: null, remote: remote), isTrue);
    });

    test('keeps a newer unsent local edit', () {
      final local = makeItem('a', minute: 9);
      expect(shouldApplyRemote(local: local, remote: remote), isFalse);
    });

    test('takes the server copy when it is newer than the local edit', () {
      final local = makeItem('a', minute: 1);
      expect(shouldApplyRemote(local: local, remote: remote), isTrue);
    });
  });
}
