import 'package:flutter/material.dart';

/// Retains the shared entry point while displaying standard bottom snackbars.
void showGabayTopMessage(BuildContext context, SnackBar message) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(message);
}
