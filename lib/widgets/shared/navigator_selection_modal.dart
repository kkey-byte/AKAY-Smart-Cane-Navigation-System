import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import 'gabay_selection_dialog.dart';

Future<String?> showNavigatorSelectionModal(
  BuildContext context, {
  required List<({String uid, String name})> navigatorOptions,
  required String selectedUid,
}) => showGabaySelectionDialog<String>(
  context,
  title: 'Linked navigators',
  subtitle: 'Choose who to monitor',
  selectedValue: selectedUid,
  options: [
    for (final option in navigatorOptions)
      GabaySelectionOption(
        value: option.uid,
        searchText: option.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option.name),
            if (option.uid == selectedUid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Currently monitoring',
                  style: TextStyle(
                    color: context.gabay.accent,
                    fontSize: GabayTypography.caption,
                  ),
                ),
              ),
          ],
        ),
      ),
  ],
);
