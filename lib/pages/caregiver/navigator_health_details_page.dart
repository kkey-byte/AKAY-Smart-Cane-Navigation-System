import '../../widgets/profile/health_display_widgets.dart';
import '../../widgets/shared/gabay_card.dart';
import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../services/app_session_service.dart';
import '../../services/pairing_service.dart';
import '../../services/navigator_health_service.dart';
import '../../models/navigator_health_details.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';
import '../../widgets/shared/gabay_selection_dialog.dart';
import '../../widgets/profile/linked_navigator_photo.dart';

/// Shows only identities returned by the authorized connections service.
class NavigatorHealthDetailsPage extends StatefulWidget {
  const NavigatorHealthDetailsPage({
    super.key,
    this.service,
    this.healthService,
  });
  final PairingService? service;
  final NavigatorHealthService? healthService;
  @override
  State<NavigatorHealthDetailsPage> createState() =>
      _NavigatorHealthDetailsPageState();
}

class _NavigatorHealthDetailsPageState
    extends State<NavigatorHealthDetailsPage> {
  late final Stream<List<PairingConnection>> _connections;
  late final int _revision;
  late final NavigatorHealthService _healthService;
  String? _selectedId;
  @override
  void initState() {
    super.initState();
    _revision = AppSessionService.instance.identityRevision;
    _healthService =
        widget.healthService ??
        NavigatorHealthService(api: widget.service?.api);
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
              _NavigatorHealthInformation(
                key: ValueKey(selected.navigatorUid),
                selected: selected,
                service: _healthService,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavigatorHealthInformation extends StatefulWidget {
  const _NavigatorHealthInformation({
    super.key,
    required this.selected,
    required this.service,
  });
  final PairingConnection selected;
  final NavigatorHealthService service;
  @override
  State<_NavigatorHealthInformation> createState() =>
      _NavigatorHealthInformationState();
}

class _NavigatorHealthInformationState
    extends State<_NavigatorHealthInformation> {
  late final Stream<NavigatorHealthDetails> _details;
  @override
  void initState() {
    super.initState();
    _details = widget.service.watch(widget.selected.navigatorUid);
  }

  String _value(Object? value) =>
      value == null || value.toString().trim().isEmpty
      ? 'Not provided'
      : value.toString().trim();

  Map<String, String> _information(NavigatorHealthDetails details) {
    final profile = details.profile, health = details.health;
    final birthdate = profile.birthdate;
    int? age = profile.age;
    if (birthdate != null) {
      final today = DateTime.now();
      final calculated =
          today.year -
          birthdate.year -
          ((today.month < birthdate.month ||
                  (today.month == birthdate.month && today.day < birthdate.day))
              ? 1
              : 0);
      age = calculated >= 0 ? calculated : null;
    }
    String measurement(double? value, String unit) => details.healthUnavailable
        ? 'Unavailable'
        : value == null
        ? 'Not provided'
        : '${value == value.roundToDouble() ? value.toInt() : value} $unit';
    // An existing health record's explicit clears must not resurrect old data.
    return {
      'Age': _value(age),
      'Gender': _value(profile.gender),
      'Blood Type': _value(profile.bloodType),
      'Height': measurement(health?.height, 'cm'),
      'Weight': measurement(health?.weight, 'kg'),
      'Medical Conditions': _value(
        health != null ? health.medicalConditions : profile.medicalConditions,
      ),
      'Allergies': _value(
        health != null ? health.allergies : profile.allergies,
      ),
      'Emergency Contact': _value(profile.emergencyContact),
      'Emergency Contact Phone': details.healthUnavailable
          ? 'Unavailable'
          : _value(health?.emergencyContactPhone),
      'Phone Number': _value(details.phone),
      'Address': _value(profile.address),
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return StreamBuilder<NavigatorHealthDetails>(
      stream: _details,
      builder: (context, snapshot) {
        final available = !snapshot.hasError && snapshot.hasData;
        if (!available) {
          return GabayContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!snapshot.hasError)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Loading health information',
                  ),
                const SizedBox(height: 12),
                Text(
                  snapshot.hasError
                      ? 'Health information not available'
                      : 'Loading health information',
                  style: GabayTheme.sectionTitle(context),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.hasError
                      ? 'Unable to load this navigator’s information. Check your connection and sharing access.'
                      : 'Loading this navigator’s information…',
                  style: GabayTheme.bodyMedium(context),
                ),
              ],
            ),
          );
        }
        final fields = _information(snapshot.data!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GabaySectionLabel(label: 'Health Overview'),
            const SizedBox(height: 6),
            Text(
              'Shared health information.',
              style: GabayTheme.labelSmall(context),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 280 &&
                        MediaQuery.textScalerOf(context).scale(13) <= 20
                    ? 3
                    : 1;
                final cards = [
                  for (final item in [
                    (label: 'Blood Type', icon: Icons.water_drop_outlined),
                    (label: 'Height', icon: Icons.straighten),
                    (label: 'Weight', icon: Icons.monitor_weight_outlined),
                  ])
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 10) / columns,
                      child: GabayHealthOverviewCard(
                        label: item.label,
                        value: fields[item.label]!,
                        icon: item.icon,
                      ),
                    ),
                ];
                if (columns == 1) {
                  return Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        cards[i],
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            GabayHealthSection(
              title: 'Medical Conditions',
              icon: Icons.warning_amber_rounded,
              child: Text(
                fields['Medical Conditions']!,
                style: GabayTheme.bodyMedium(context),
              ),
            ),
            const SizedBox(height: 14),
            GabayHealthSection(
              title: 'Allergies',
              icon: Icons.block_outlined,
              child: Text(
                fields['Allergies']!,
                style: GabayTheme.bodyMedium(context),
              ),
            ),
            const SizedBox(height: 20),
            const GabaySectionLabel(label: 'Emergency Contact'),
            GabayCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const GabayHealthIcon(icon: Icons.person_outline),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fields['Emergency Contact']!,
                              style: TextStyle(
                                color: g.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Emergency contact',
                              style: GabayTheme.labelSmall(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(color: g.border.withValues(alpha: .5)),
                  GabayHealthDetail(
                    label: 'Phone Number',
                    value: fields['Emergency Contact Phone']!,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              context,
              'Personal Details',
              Icons.person_outline_rounded,
              fields,
              ['Age', 'Gender', 'Phone Number'],
            ),
            const SizedBox(height: 14),
            _section(context, 'Address', Icons.location_on_outlined, fields, [
              'Address',
            ]),
            if (snapshot.data!.healthUnavailable) ...[
              const SizedBox(height: 14),
              Text(
                'Health status is temporarily unavailable.',
                style: GabayTheme.labelSmall(context),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    Map<String, String> fields,
    List<String> keys,
  ) {
    final g = context.gabay;
    return GabayContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: g.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: GabayTheme.sectionTitle(context)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: g.border.withValues(alpha: .6),
                ),
              ),
            if (keys.length > 1) ...[
              Text(
                keys[i] == 'Emergency Contact'
                    ? 'Name'
                    : keys[i] == 'Emergency Contact Phone'
                    ? 'Phone Number'
                    : keys[i],
                style: GabayTheme.labelSmall(context),
              ),
              const SizedBox(height: 4),
            ],
            Semantics(
              label: '${keys[i]}: ${fields[keys[i]]}',
              excludeSemantics: true,
              child: SelectableText(
                fields[keys[i]]!,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
