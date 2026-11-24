import '../../domain/entities/item.dart';

abstract class ItemLocalStore {
  Future<List<Item>> getVisible();
  Future<Item?> getById(String id);
  Future<void> upsert(Item item);
  Future<List<Item>> getPending({required int limit});
  Future<void> markSynced(String id, DateTime sentUpdatedAt);
  Future<int> pendingCount();
  Future<int> getPullCursor();
  Future<void> applyRemoteChanges(List<Item> changes, int newCursor);
}
