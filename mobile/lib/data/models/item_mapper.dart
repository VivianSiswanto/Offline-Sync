import '../../domain/entities/item.dart';

extension ItemMapper on Item {
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'isDeleted': isDeleted,
  };

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'notes': notes,
    'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
    'is_deleted': isDeleted ? 1 : 0,
    'sync_status': syncStatus == SyncStatus.pending ? 0 : 1,
  };
}

Item itemFromJson(Map<String, dynamic> json) => Item(
  id: json['id'] as String,
  title: json['title'] as String,
  notes: (json['notes'] as String?) ?? '',
  updatedAt: _toMillis(DateTime.parse(json['updatedAt'] as String)),
  isDeleted: json['isDeleted'] as bool,
  syncStatus: SyncStatus.synced,
);

Item itemFromRow(Map<String, Object?> row) => Item(
  id: row['id'] as String,
  title: row['title'] as String,
  notes: row['notes'] as String,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(
    row['updated_at'] as int,
    isUtc: true,
  ),
  isDeleted: (row['is_deleted'] as int) == 1,
  syncStatus: (row['sync_status'] as int) == 0
      ? SyncStatus.pending
      : SyncStatus.synced,
);

DateTime _toMillis(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
  d.toUtc().millisecondsSinceEpoch,
  isUtc: true,
);
