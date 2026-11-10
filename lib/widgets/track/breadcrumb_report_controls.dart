import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/breadcrumb_service.dart';
import '../shared/gabay_card.dart';
import 'breadcrumb_recording_controls.dart';

/// Recording actions stay on Reports; they do not open another history page.
class BreadcrumbReportControls extends StatelessWidget {
  const BreadcrumbReportControls({super.key});
  @override
  Widget build(BuildContext context) {
    final service = BreadcrumbService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final recorder = service.recorder;
        if (recorder == null || recorder.ownerId == null) {
          return const SizedBox.shrink();
        }
        return GabayCard(
          padding: const EdgeInsets.all(16),
          child: BreadcrumbRecordingControls(
            compact: true,
            requested: service.trackingRequested,
            recording: service.isRecording,
            waitingReason: service.recordingError,
            storageError: recorder.storageError,
            syncError: recorder.syncError,
            pendingCount: recorder.pendingCount,
            syncing: recorder.isSyncing,
            hasTrips: service.trips.isNotEmpty,
            onStart: () => unawaited(_run(context, () => service.start())),
            onPause: () => unawaited(_run(context, service.stop)),
            onSync: () => unawaited(recorder.sync()),
          ),
        );
      },
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recording could not be updated. Check location access and device storage.',
            ),
          ),
        );
      }
    }
  }
}
