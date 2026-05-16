import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncService().statusStream,
      initialData: SyncStatus(), // Default offline/empty
      builder: (context, snapshot) {
        final status = snapshot.data!;

        // Determine Color & Icon
        Color color = Colors.grey;
        IconData icon = Icons.cloud_off;
        String tooltip = 'Offline';

        if (status.isSyncing) {
          color = Colors.blue;
          icon = Icons.sync;
          tooltip = 'Syncing...';
        } else if (status.isOnline) {
          if (status.lastError != null) {
            color = Colors.orange;
            icon = Icons.warning_amber_rounded;
            tooltip = 'Sync Error: ${status.lastError}';
          } else {
            color = Colors.green;
            icon = Icons.cloud_done;
            tooltip = 'Online (Synced)';
          }
        } else {
          // Offline
          color = Colors.red;
          icon = Icons.cloud_off;
          tooltip = 'Offline';
          if (status.lastError != null) {
            tooltip += '\n${status.lastError}';
          }
        }

        return Tooltip(
          message: tooltip,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, color: color, size: 20),
                if (status.pendingOrders > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Pending: ${status.pendingOrders}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
