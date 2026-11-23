enum SyncStatus { synced, pending }

class Item {
  const Item({
    required this.id,
    required this.title,
    this.notes = '',
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String title;
  final String notes;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;

  bool get isPending => syncStatus == SyncStatus.pending;

  Item copyWith({
    String? title,
    String? notes,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Item(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
