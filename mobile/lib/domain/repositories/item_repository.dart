import '../entities/item.dart';

abstract class ItemRepository {
  Stream<void> get changes;
  Future<List<Item>> getItems();
  Future<void> addItem({required String title, String notes = ''});
  Future<void> updateItem(Item item);
  Future<void> deleteItem(String id);
}
