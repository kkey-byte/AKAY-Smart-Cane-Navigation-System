import 'package:flutter/material.dart';
import '../shared/pairing_management_page.dart';

class ViCaregiversPage extends StatelessWidget {
  const ViCaregiversPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PairingManagementPage(caregiver: false);
}
