import '../../widgets/shared/gabay_page_header.dart';
import '../../widgets/shared/gabay_page_background.dart';
import 'package:flutter/material.dart';
import '../../services/pairing_service.dart';
import '../../widgets/shared/dashboard_pairing_card.dart';

class ViCaregiversPage extends StatefulWidget {
  const ViCaregiversPage({super.key, this.service});
  final PairingService? service;
  @override
  State<ViCaregiversPage> createState() => _ViCaregiversPageState();
}

class _ViCaregiversPageState extends State<ViCaregiversPage> {
  final _pairingKey = GlobalKey<DashboardPairingCardState>();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,

    body: GabayPageBackground(
      child: GabayScrollingPage(
        header: const GabayPageHeader(title: 'Caregivers'),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () =>
                _pairingKey.currentState?.refresh() ?? Future.value(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                DashboardPairingCard(
                  key: _pairingKey,
                  caregiver: false,
                  profilePresentation: true,
                  service: widget.service,
                  showManageConnections: false,
                  allowDisconnect: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
