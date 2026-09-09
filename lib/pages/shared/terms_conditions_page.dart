import 'package:flutter/material.dart';

import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GabayDetailPageScaffold(
      title: 'Terms & Conditions',
      subtitle: 'Last updated: July 2026',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [
          GabayContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GabayLegalSection(
                  title: '1. Acceptance of Terms',
                  body:
                      'By accessing and using the GABAY mobile application, you agree to comply with these Terms & Conditions. If you do not agree, please discontinue use of the app.',
                ),
                GabayLegalSection(
                  title: '2. Purpose of the App',
                  body:
                      'GABAY is designed to support caregivers and visually impaired navigators through live tracking, route assistance, health information sharing, and emergency alerts. The app is an assistive tool and does not replace professional medical or emergency services.',
                ),
                GabayLegalSection(
                  title: '3. User Responsibilities',
                  body:
                      'You are responsible for maintaining the confidentiality of your account credentials, ensuring accurate profile information, and using the app in a lawful and respectful manner. Caregivers must obtain consent before monitoring a navigator\'s location.',
                ),
                GabayLegalSection(
                  title: '4. Location & Device Data',
                  body:
                      'GABAY may collect location data, device battery status, and navigation activity to provide tracking and safety features. You agree to enable necessary permissions for the app to function as intended.',
                ),
                GabayLegalSection(
                  title: '5. Emergency Features',
                  body:
                      'SOS and fall-detection alerts are supplementary safety tools. GABAY does not guarantee emergency response times and should not be relied upon as the sole means of requesting help.',
                ),
                GabayLegalSection(
                  title: '6. Limitation of Liability',
                  body:
                      'GABAY and its developers shall not be held liable for delays, inaccuracies in location data, connectivity issues, or outcomes resulting from use or inability to use the application.',
                ),
                GabayLegalSection(
                  title: '7. Changes to Terms',
                  body:
                      'We may update these terms from time to time. Continued use of the app after changes are posted constitutes acceptance of the revised terms.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
