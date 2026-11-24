import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/item.dart';
import '../models/item_mapper.dart';
import 'item_local_store.dart';
import 'merge_rules.dart';

class SqfliteItemLocalStore implements ItemLocalStore {
  SqfliteItemLocalStore(this._db);
  final Database _db;
  static const _cursorKey = 'pull_cursor';

  static Future<SqfliteItemLocalStore> open() async {
    final path = p.join(await getDatabasesPath(), 'offline_sync.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            updated_at INTEGER, 
            is_deleted INTEGER NOT NULL DEFAULT 0,
            sync_status INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_items_sync ON items (sync_status, updated_at)',
        );
        await db.execute(
          'CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    return SqfliteItemLocalStore(db);
  }

  @override
  Future<List<Item>> getVisible() async {
    final rows = await _db.query(
      'items',
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(itemFromRow).toList();
  }

  @override
  Future<Item?> getById(String id) async {
    final rows = await _db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : itemFromRow(rows.first);
  }

  @override
  Future<void> upsert(Item item) async {
    await _db.insert(
      'items',
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Item>> getPending({required int limit}) async {
    final rows = await _db.query(
      'items',
      where: 'sync_status = 0',
      orderBy: 'updated_at ASC',
      limit: limit,
    );
    return rows.map(itemFromRow).toList();
  }

  @override
  Future<void> markSynced(String id, DateTime sentUpdatedAt) async {
    await _db.update(
      'items',
      {'sync_status': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, sentUpdatedAt.toUtc().millisecondsSinceEpoch],
    );
  }

  @override
  Future<int> pendingCount() async {
    final rows = await _db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [_cursorKey],
    );
    return rows.isEmpty ? 0 : int.parse(rows.first['value'] as String);
  }

  @override
  Future<int> getPullCursor() async {
    final rows = await _db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [_cursorKey],
    );
    return rows.isEmpty ? 0 : int.parse(rows.first['value'] as String);
  }

  @override
  Future<void> applyRemoteChanges(List<Item> changes, int newCursor) async {
    await _db.transaction((txn) async {
      for (final remote in changes) {
        final rows = await txn.query(
          'items',
          where: 'id = ?',
          whereArgs: [remote.id],
          limit: 1,
        );

        final local = rows.isEmpty ? null : itemFromRow(rows.first);

        if (shouldApplyRemote(local: local, remote: remote)) {
          await txn.insert(
            'items',
            remote.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await txn.insert('sync_meta', {
        'key': _cursorKey,
        'value': '$newCursor',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
