import '../../widgets/shared/gabay_page_header.dart';
import '../../widgets/shared/gabay_page_background.dart';
import 'package:flutter/material.dart';
import '../../services/pairing_service.dart';
import '../../widgets/shared/dashboard_pairing_card.dart';
import '../../widgets/profile/navigator_smart_cane_section.dart';
import '../../models/pairing.dart';
import '../../services/app_session_service.dart';
import '../../theme/gabay_theme.dart';
import '../shared/pairing_management_page.dart';
import 'dart:async';

class ViCaregiversPage extends StatefulWidget {
  const ViCaregiversPage({super.key, this.service});
  final PairingService? service;
  @override
  State<ViCaregiversPage> createState() => _ViCaregiversPageState();
}

class _ViCaregiversPageState extends State<ViCaregiversPage> {
  final _pairingKey = GlobalKey<DashboardPairingCardState>();
  late final PairingService _service =
      widget.service ?? PairingService.instance;
  late final int _revision = AppSessionService.instance.identityRevision;
  List<RegisteredCane>? _devices;
  String? _deviceError;
  bool? _loadingDevices = true;
  int _deviceRequest = 0;
  bool get _valid => _revision == AppSessionService.instance.identityRevision;

  @override
  void initState() {
    super.initState();
    AppSessionService.instance.addListener(_sessionChanged);
    unawaited(_loadDevices());
  }

  void _sessionChanged() {
    if (!_valid && mounted) {
      _deviceRequest++;
      setState(() {
        _devices = null;
        _loadingDevices = false;
        _deviceError = 'Account changed. Reopen this page.';
      });
    }
  }

  Future<void> _loadDevices() async {
    if (!_valid || !mounted) return;
    final request = ++_deviceRequest;
    setState(() {
      _loadingDevices = true;
      _deviceError = null;
    });
    try {
      final devices = await _service.devices();
      if (mounted && _valid && request == _deviceRequest) {
        setState(() {
          _devices = devices;
          _loadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted && _valid && request == _deviceRequest) {
        setState(() {
          _devices = null;
          _loadingDevices = false;
          _deviceError = 'Unable to load registered canes.';
        });
      }
    }
  }

  Future<void> _openDevices({bool register = false}) async {
    if (!_valid) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PairingManagementPage(
          caregiver: false,
          service: _service,
          devicesOnly: true,
          registerOnOpen: register,
        ),
      ),
    );
    if (mounted && _valid) await _loadDevices();
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_sessionChanged);
    _deviceRequest++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,

    body: GabayPageBackground(
      child: GabayScrollingPage(
        header: const GabayPageHeader(title: 'Connections & Devices'),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _pairingKey.currentState?.refresh() ?? Future<void>.value(),
                _loadDevices(),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Manage your caregiver connections and smart cane.',
                  style: GabayTheme.bodyMedium(context).copyWith(
                    fontSize: 13,
                    color: context.gabay.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                DashboardPairingCard(
                  key: _pairingKey,
                  caregiver: false,
                  profilePresentation: true,
                  service: widget.service,
                  showManageConnections: false,
                  allowDisconnect: true,
                  companionAction: SmartCaneActionCard(
                    compact: true,
                    onRegister: _valid
                        ? () => _openDevices(register: true)
                        : null,
                  ),
                ),
                NavigatorSmartCaneSection(
                  devices: _devices,
                  loading: _loadingDevices,
                  error: _deviceError,
                  onManage: _valid ? () => _openDevices() : null,
                  onRetry: _valid ? _loadDevices : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
