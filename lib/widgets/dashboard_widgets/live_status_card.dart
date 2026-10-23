import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import '../shared/authorized_users_card.dart';
import '../../pages/shared/pairing_management_page.dart';

class LiveStatusCard extends StatelessWidget {
  const LiveStatusCard({super.key, this.onViewProfile});
  final VoidCallback? onViewProfile;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: GabayTheme.cardDecoration(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthorizedUsersCard(caregiver: true),
        SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PairingManagementPage(caregiver: true),
            ),
          ),
          child: const Text('Monitor navigators and canes'),
        ),
      ],
    ),
  );
}
