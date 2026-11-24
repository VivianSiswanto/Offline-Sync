enum SyncPhase { idle, syncing, offline, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncPhase phase;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncState copywith({SyncPhase? phase, int? pendingCount}) => SyncState(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    lastSyncedAt: lastSyncedAt,
    message: message,
  );
}
