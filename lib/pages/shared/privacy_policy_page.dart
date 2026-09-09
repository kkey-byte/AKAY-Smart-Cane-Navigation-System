import 'package:flutter/material.dart';

import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GabayDetailPageScaffold(
      title: 'Privacy Policy',
      subtitle: 'How GABAY protects your personal information.',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [
          GabayContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GabayLegalSection(
                  title: 'Information We Collect',
                  body:
                      'GABAY may collect account details (name, email, phone), navigator health information you choose to share, live location data, device battery status, route history, and emergency contact information.',
                ),
                GabayLegalSection(
                  title: 'How We Use Your Data',
                  body:
                      'Your data is used to provide navigation assistance, caregiver monitoring, health status display, notifications, and safety alerts. We do not sell your personal information to third parties.',
                ),
                GabayLegalSection(
                  title: 'Location Sharing',
                  body:
                      'Navigator location is shared only with linked caregiver accounts you approve. You may revoke sharing permissions at any time through app settings or by contacting support.',
                ),
                GabayLegalSection(
                  title: 'Data Storage & Security',
                  body:
                      'We implement reasonable technical and organizational measures to protect your data. Information is stored securely and accessed only for authorized app functionality.',
                ),
                GabayLegalSection(
                  title: 'Third-Party Services',
                  body:
                      'GABAY may integrate with mapping services (e.g., Google Maps) and cloud infrastructure providers. These services have their own privacy policies governing data they process.',
                ),
                GabayLegalSection(
                  title: 'Your Rights',
                  body:
                      'You may request access to, correction of, or deletion of your personal data by contacting our support team. You may also withdraw consent for location tracking where applicable.',
                ),
                GabayLegalSection(
                  title: 'Contact Us',
                  body:
                      'For privacy-related inquiries, email us at privacy@gabay.app. We aim to respond within 5 business days.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
