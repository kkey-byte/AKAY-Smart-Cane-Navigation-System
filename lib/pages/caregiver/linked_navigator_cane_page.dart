import 'package:flutter/material.dart';
import '../shared/pairing_management_page.dart';

class LinkedNavigatorCanePage extends StatelessWidget {
  const LinkedNavigatorCanePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PairingManagementPage(caregiver: true);
}
