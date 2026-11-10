import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

/// Recording and upload states are independent: an offline recording can still
/// be saved locally, and pausing need not wait for cloud acknowledgement.
class BreadcrumbRecordingControls extends StatelessWidget {
  const BreadcrumbRecordingControls({
    super.key,
    required this.requested,
    required this.recording,
    required this.pendingCount,
    required this.syncing,
    required this.hasTrips,
    required this.onStart,
    required this.onPause,
    required this.onSync,
    this.waitingReason,
    this.storageError,
    this.syncError,
    this.busy = false,
    this.compact = false,
  });
  final bool requested, recording, syncing, hasTrips, busy;
  final bool compact;
  final int pendingCount;
  final String? waitingReason, storageError, syncError;
  final VoidCallback onStart, onPause, onSync;

  @override
  Widget build(BuildContext context) {
    final status = storageError != null
        ? 'Device storage needs attention'
        : !requested
        ? 'Recording paused'
        : waitingReason != null || !recording
        ? 'Waiting for an accurate location'
        : 'Recording · No destination needed';
    final upload = storageError != null
        ? 'Uploads wait until device storage recovers.'
        : pendingCount > 0
        ? syncing
              ? 'Uploading saved track updates…'
              : '$pendingCount track update${pendingCount == 1 ? '' : 's'} awaiting upload'
        : hasTrips
        ? 'All recorded updates uploaded'
        : 'Your recorded path will appear below.';
    final action = requested
        ? onPause
        : busy
        ? null
        : onStart;
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track recording',
                  style: TextStyle(
                    color: context.gabay.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    style: TextStyle(
                      color: context.gabay.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (storageError != null) Text(storageError!),
                if (syncError != null)
                  Text(
                    syncError!,
                    style: TextStyle(color: context.gabay.warning),
                  ),
                if (pendingCount > 0)
                  TextButton(
                    onPressed: busy || syncing ? null : onSync,
                    child: Text(syncing ? 'Syncing…' : 'Sync saved tracks'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
              shape: const CircleBorder(),
              minimumSize: const Size(48, 48),
            ),
            tooltip: requested
                ? 'Pause sharing and save track'
                : 'Resume sharing and recording',
            onPressed: action,
            icon: Icon(
              requested ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            iconSize: 28,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            style: TextStyle(
              color: storageError == null
                  ? context.gabay.textPrimary
                  : context.gabay.warning,
            ),
          ),
        ),
        if (requested && waitingReason != null) Text(waitingReason!),
        if (storageError != null) Text(storageError!),
        const SizedBox(height: 12),
        FilledButton.icon(
          // A pending location request must remain cancellable. Resume and
          // duplicate sync actions can wait; Pause changes the request at once.
          onPressed: requested
              ? onPause
              : busy
              ? null
              : onStart,
          icon: Icon(requested ? Icons.stop : Icons.fiber_manual_record),
          label: Text(
            requested
                ? 'Pause sharing and save track'
                : busy
                ? 'Please wait…'
                : 'Resume sharing and recording',
          ),
        ),
        Text(upload),
        if (syncError != null)
          Text(syncError!, style: TextStyle(color: context.gabay.warning)),
        if (pendingCount > 0)
          TextButton(
            onPressed: busy || syncing ? null : onSync,
            child: Text(
              storageError == null
                  ? 'Saved on device · Sync now'
                  : 'Retry saving and syncing',
            ),
          ),
      ],
    );
  }
}
