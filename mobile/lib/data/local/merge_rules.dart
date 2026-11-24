import '../../domain/entities/item.dart';

bool shouldApplyRemote({required Item? local, required Item remote}) {
  if (local == null) return true;
  if (!local.isPending) return true;
  return remote.updatedAt.isAfter(local.updatedAt);
}
