import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../sync/sync_state.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, required this.state});
  final ValueListenable<SyncState> state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: state,
      builder: (context, s, _) {
        final (IconData icon, Color color, String text) = switch (s.phase) {
          SyncPhase.syncing => (Icons.sync, Colors.blue, 'Syncing'),
          SyncPhase.offline => (
            Icons.cloud_off,
            Colors.orange,
            'Offline. ${_changes(s.pendingCount)} waiting to sync',
          ),
          SyncPhase.error => (
            Icons.error_outline,
            Colors.red,
            'Sync error: ${s.message ?? 'unknown'}',
          ),
          SyncPhase.idle when s.pendingCount > 0 => (
            Icons.cloud_upload_outlined,
            Colors.orange,
            '${_changes(s.pendingCount)} waiting to sync',
          ),
          SyncPhase.idle => (
            Icons.cloud_done_outlined,
            Colors.green,
            s.lastSyncedAt == null
                ? 'Not synced yet'
                : "All changes synced at ${_time(s.lastSyncedAt!)}",
          ),
        };

        return Container(
          width: double.infinity,
          color: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: TextStyle(color: color)),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _changes(int n) => n == 1 ? '1 change' : '$n changes';

  static String _time(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }
}
