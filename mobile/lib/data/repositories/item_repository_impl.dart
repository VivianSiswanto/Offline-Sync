import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../core/clock.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../local/item_local_store.dart';

class ItemRepositoryImpl implements ItemRepository {
  ItemRepositoryImpl(this._local);
  final ItemLocalStore _local;
  final _changes = StreamController<void>.broadcast();
  final _uuid = const Uuid();

  void Function()? onLocalWrite;
  void notifyChanged() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<Item>> getItems() => _local.getVisible();

  @override
  Future<void> addItem({required String title, String notes = ''}) async {
    await _save(
      Item(
        id: _uuid.v4(),
        title: title.trim(),
        notes: notes.trim(),
        updatedAt: nowUtc(),
      ),
    );
  }

  @override
  Future<void> updateItem(Item item) async {
    await _save(
      item.copyWith(updatedAt: nowUtc(), syncStatus: SyncStatus.pending),
    );
  }

  @override
  Future<void> deleteItem(String id) async {
    final existing = await _local.getById(id);
    if (existing == null) return;
    await _save(
      existing.copyWith(
        isDeleted: true,
        updatedAt: nowUtc(),
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  Future<void> _save(Item item) async {
    await _local.upsert(item);
    notifyChanged();
    onLocalWrite?.call();
  }
}
