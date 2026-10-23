import 'package:flutter/material.dart';
import '../../services/app_session_service.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class ViEmergencyContactsPage extends StatelessWidget {
  const ViEmergencyContactsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppSessionService.instance,
    builder: (context, _) {
      final session = AppSessionService.instance;
      final contacts = session.isLoggedIn
          ? session.setupData.emergencyContacts
          : [];
      return GabayDetailPageScaffold(
        title: 'Emergency Contacts',
        subtitle: 'Contacts saved during your account setup.',
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (contacts.isEmpty) const Text('No emergency contacts saved.'),
            for (final contact in contacts)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(contact.name),
                subtitle: Text('${contact.relationship}\n${contact.phone}'),
                isThreeLine: true,
              ),
          ],
        ),
      );
    },
  );
}
