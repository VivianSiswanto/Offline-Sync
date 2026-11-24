import '../../domain/entities/item.dart';

abstract class SyncApi {
  Future<PushResult> push(List<Item> changes);
  Future<PullResult> pull(int since);
}

class PushResult {
  const PushResult({required this.accepted});
  final Set<String> accepted;
}

class PullResult {
  const PullResult({required this.changes, required this.cursor});
  final List<Item> changes;
  final int cursor;
}

class SyncException implements Exception {
  SyncException(this.message, {required this.retryable});
  final String message;
  final bool retryable;

  @override
  String toString() => 'SyncException($message, retryable: $retryable)';
}
