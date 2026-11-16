import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/cane_registration_challenge.dart';
import '../../services/app_session_service.dart';
import '../../services/pairing_service.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_modal_motion.dart';

/// Opens the existing server-authorized registration flow without another page.
Future<bool?> showCaneRegistrationDialog(
  BuildContext context,
  PairingService service,
) async {
  final revision = AppSessionService.instance.identityRevision;
  final controller = TextEditingController();
  final request = service.requestCaneRegistration();
  // Handle immediate failures even before the dialog's first frame subscribes.
  unawaited(request.then<void>((_) {}, onError: (Object _) {}));
  var submitting = false;
  String? error;
  try {
    return await showDialog<bool>(
      animationStyle: gabayModalAnimation(context),
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => FutureBuilder<CaneRegistrationChallenge>(
          future: request,
          builder: (context, snapshot) {
            final challenge = snapshot.data;
            return AlertDialog(
              backgroundColor: context.gabay.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: context.gabay.border.withValues(alpha: .7),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.gabay.accentTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.sensors_rounded,
                      color: context.gabay.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Register a Cane'),
                ],
              ),
              titleTextStyle: TextStyle(
                color: context.gabay.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              contentTextStyle: GabayTheme.bodyMedium(
                context,
              ).copyWith(fontSize: 14, height: 1.5),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.hasError)
                      Text(
                        snapshot.error.toString().contains(
                              'No cane is authorized for your account',
                            )
                            ? 'No cane is authorized for your account. Ask the cane provider to prepare your registration.'
                            : snapshot.error.toString(),
                      )
                    else if (challenge == null)
                      const Text('Requesting registration code…')
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.gabay.accentTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(
                          challenge.code,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.gabay.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expires: ${challenge.expiresAt.toLocal()}',
                        style: GabayTheme.labelSmall(context),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        enabled: !submitting,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Registration code',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (revision !=
                                    AppSessionService
                                        .instance
                                        .identityRevision) {
                                  Navigator.pop(dialogContext, false);
                                  return;
                                }
                                if (controller.text.trim().isEmpty) {
                                  update(
                                    () =>
                                        error = 'Enter the registration code.',
                                  );
                                  return;
                                }
                                update(() {
                                  submitting = true;
                                  error = null;
                                });
                                try {
                                  await service.confirmCaneRegistration(
                                    challenge.id,
                                    controller.text,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext, true);
                                  }
                                } catch (failure) {
                                  if (dialogContext.mounted) {
                                    update(() {
                                      submitting = false;
                                      error = failure.toString();
                                    });
                                  }
                                }
                              },
                        child: const Text('Register'),
                      ),
                      if (error != null) Text(error!),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      ),
    );
  } finally {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 1), controller.dispose),
    );
  }
}
