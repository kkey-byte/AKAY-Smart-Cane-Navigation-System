import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../services/app_session_service.dart';
import '../../services/pairing_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';
import '../../widgets/shared/gabay_selection_dialog.dart';
import '../../widgets/profile/linked_navigator_photo.dart';

/// Shows only identities returned by the authorized connections service.
/// The current health endpoint cannot read another account's health record.
class NavigatorHealthDetailsPage extends StatefulWidget {
  const NavigatorHealthDetailsPage({super.key, this.service});
  final PairingService? service;
  @override
  State<NavigatorHealthDetailsPage> createState() =>
      _NavigatorHealthDetailsPageState();
}

class _NavigatorHealthDetailsPageState
    extends State<NavigatorHealthDetailsPage> {
  late final Stream<List<PairingConnection>> _connections;
  late final int _revision;
  String? _selectedId;
  @override
  void initState() {
    super.initState();
    _revision = AppSessionService.instance.identityRevision;
    _connections = (widget.service ?? PairingService.instance)
        .watchConnections();
    AppSessionService.instance.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return GabayDetailPageScaffold(
      title: 'Navigator Health Details',
      body: StreamBuilder<List<PairingConnection>>(
        stream: _connections,
        builder: (context, snapshot) {
          if (_revision != AppSessionService.instance.identityRevision) {
            return const Center(
              child: Text('Account changed. Reopen this page.'),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Linked navigators are unavailable. Please reopen this page to retry.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading linked navigators',
              ),
            );
          }
          final rows = snapshot.data!
              .where((row) => row.status == 'active')
              .toList();
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No connected navigators yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final selected =
              rows.where((row) => row.id == _selectedId).firstOrNull ??
              rows.first;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GabayContentCard(
                child: Row(
                  children: [
                    LinkedNavigatorPhoto(picture: selected.navigatorPicture),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.navigatorName,
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: GabayTypography.cardTitle,
                              fontWeight: GabayTypography.semibold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Navigator · Connected',
                            style: TextStyle(
                              color: g.textSecondary,
                              fontSize: GabayTypography.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Select navigator',
                      icon: Icon(Icons.expand_more_rounded, color: g.accent),
                      onPressed: () async {
                        final id = await showGabaySelectionDialog<String>(
                          context,
                          title: 'Select navigator',
                          selectedValue: selected.id,
                          options: rows
                              .map(
                                (row) => GabaySelectionOption(
                                  value: row.id,
                                  child: Text(row.navigatorName),
                                ),
                              )
                              .toList(),
                        );
                        if (mounted &&
                            _revision ==
                                AppSessionService.instance.identityRevision &&
                            id != null) {
                          setState(() => _selectedId = id);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GabayContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      'User ID: ${selected.navigatorUserId ?? selected.navigatorUid}',
                      style: TextStyle(
                        color: g.textSecondary,
                        fontSize: GabayTypography.caption,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Health information not available',
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: GabayTypography.cardTitle,
                        fontWeight: GabayTypography.semibold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The current service does not share navigator health records with caregivers.',
                      style: TextStyle(
                        color: g.textSecondary,
                        fontSize: GabayTypography.body,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
