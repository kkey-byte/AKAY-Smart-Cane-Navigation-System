import '../../theme/gabay_typography.dart';
import '../../widgets/shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';
import '../../widgets/shared/gabay_selection_dialog.dart';
import '../../models/patient_profile.dart';
import '../../models/patient_health_status.dart';
import '../../services/health_status_service.dart';
import '../../models/user_role.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_card.dart';
import 'dart:convert';
import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

/// Only the signed-in user's supported profile fields are fetched.
class InformationHealthStatusPage extends StatefulWidget {
  const InformationHealthStatusPage({super.key});
  @override
  State<InformationHealthStatusPage> createState() =>
      _InformationHealthStatusPageState();
}

class _InformationHealthStatusPageState
    extends State<InformationHealthStatusPage> {
  late Future<ProfileBundle> _profile;
  late int _revision;
  @override
  void initState() {
    super.initState();
    _revision = AppSessionService.instance.identityRevision;
    _profile = ProfileService.instance.fetchProfile();
    AppSessionService.instance.addListener(_onSession);
  }

  void _onSession() {
    final revision = AppSessionService.instance.identityRevision;
    if (_revision == revision) return;
    _revision = revision;
    if (mounted) {
      setState(() {
        _profile = ProfileService.instance.fetchProfile();
      });
    }
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_onSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GabayDetailPageScaffold(
    title: 'Health Details',

    body: FutureBuilder<ProfileBundle>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading profile'),
          );
        }
        if (snapshot.hasError || !AppSessionService.instance.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to load profile. Check your connection and sign-in.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _profile = ProfileService.instance.fetchProfile();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return InformationHealthContent(profile: snapshot.data!);
      },
    ),
  );
}

/// Information and Health Status backed by patientmedication.
class InformationHealthContent extends StatefulWidget {
  const InformationHealthContent({
    super.key,
    required this.profile,
    this.healthService,
    this.profileService,
  });
  final ProfileBundle profile;
  final HealthStatusService? healthService;
  final ProfileService? profileService;
  @override
  State<InformationHealthContent> createState() =>
      _InformationHealthContentState();
}

class _InformationHealthContentState extends State<InformationHealthContent> {
  Future<void>? _refreshing;
  Future<void> _refresh() {
    if (_refreshing != null) return _refreshing!;
    if (_loadingHealth) return Future.value();
    return _refreshing = _reload().whenComplete(() => _refreshing = null);
  }

  Future<void> _reload() async {
    final revision = AppSessionService.instance.identityRevision;
    await Future.wait([
      _loadHealth(),
      () async {
        try {
          final updated =
              await (widget.profileService ?? ProfileService.instance)
                  .fetchProfile();
          if (mounted &&
              revision == AppSessionService.instance.identityRevision) {
            setState(() => _updatedProfile = updated);
          }
        } catch (_) {
          if (mounted &&
              revision == AppSessionService.instance.identityRevision) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to refresh profile. Current details are retained.',
                ),
              ),
            );
          }
        }
      }(),
    ]);
  }

  ProfileBundle? _updatedProfile;
  ProfileBundle get profile => _updatedProfile ?? widget.profile;
  String? _height, _weight, _conditions, _allergies, _phone;
  bool _loadingHealth = true;
  String? _healthError;
  int _loadRevision = 0;
  late int _identityRevision;
  HealthStatusService get _service =>
      widget.healthService ?? HealthStatusService.instance;

  @override
  void initState() {
    super.initState();
    _identityRevision = AppSessionService.instance.identityRevision;
    _loadHealth();
  }

  void _apply(PatientHealthStatus? record) {
    _height = record?.height?.toString();
    _weight = record?.weight?.toString();
    _conditions = record == null ? null : record.medicalConditions ?? '';
    _allergies = record == null ? null : record.allergies ?? '';
    _phone = record?.emergencyContactPhone;
  }

  Future<void> _loadHealth() async {
    final generation = ++_loadRevision;
    setState(() {
      _loadingHealth = true;
      _healthError = null;
    });
    try {
      final record = await _service.fetch();
      if (!mounted || generation != _loadRevision) return;
      setState(() => _apply(record));
    } catch (_) {
      if (mounted && generation == _loadRevision) {
        setState(() => _healthError = 'Unable to load health information.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _loadRevision) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to load health information.'),
              duration: const Duration(seconds: 4),
              persist: false,
              action: SnackBarAction(label: 'Retry', onPressed: _loadHealth),
            ),
          );
        });
      }
    } finally {
      if (mounted && generation == _loadRevision) {
        setState(() => _loadingHealth = false);
      }
    }
  }

  Future<void> _persist(Map<String, String> values) async {
    if (!mounted ||
        _identityRevision != AppSessionService.instance.identityRevision) {
      throw StateError('Account changed. Reopen health information.');
    }
    final patient = profile.patientProfile;
    if (patient.profileId == null ||
        patient.profileId!.trim().isEmpty ||
        values['blood_type'] != (patient.bloodType ?? '') ||
        values['contact_name'] != (patient.emergencyContact ?? '')) {
      final updated = await (widget.profileService ?? ProfileService.instance)
          .saveProfile(
            name: profile.name ?? '',
            phone: profile.phone ?? '',
            profilePicture: profile.profilePicture,
            patient: PatientProfile(
              profileId: patient.profileId,
              userId: patient.userId,
              age: patient.age,
              gender: patient.gender,
              birthdate: patient.birthdate,
              medicalConditions: patient.medicalConditions,
              allergies: patient.allergies,
              bloodType: values['blood_type'],
              emergencyContact: values['contact_name'],
              address: patient.address,
            ),
          );
      if (!mounted ||
          _identityRevision != AppSessionService.instance.identityRevision) {
        throw StateError('Account changed. Reopen health information.');
      }
      setState(() => _updatedProfile = updated);
    }
    final result = await _service.save(
      PatientHealthStatus(
        height: double.tryParse(values['height'] ?? ''),
        weight: double.tryParse(values['weight'] ?? ''),
        medicalConditions: values['medical_conditions'],
        allergies: values['allergies'],
        emergencyContactPhone: values['phone_number'],
      ),
    );
    if (mounted) setState(() => _apply(result));
  }

  @override
  void didUpdateWidget(covariant InformationHealthContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.profile, widget.profile)) {
      _updatedProfile = null;
      _identityRevision = AppSessionService.instance.identityRevision;
      _height = _weight = _conditions = _allergies = _phone = null;
      _loadHealth();
    }
  }

  String _value(String? value) =>
      value == null || value.trim().isEmpty ? 'Not provided' : value;

  Future<void> _edit([String section = 'basic']) async {
    final editRevision = _identityRevision;
    final editUserId = profile.userId;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _HealthEditor(
        section: section,
        onSave: (values) async {
          if (!mounted ||
              editRevision != AppSessionService.instance.identityRevision ||
              profile.userId != editUserId) {
            throw StateError('Account changed. Reopen health information.');
          }
          if (_healthError != null) {
            final recovered = await _service.fetch();
            if (!mounted ||
                editRevision != AppSessionService.instance.identityRevision ||
                profile.userId != editUserId) {
              throw StateError('Account changed. Reopen health information.');
            }
            final existing = <String, String>{
              'height': recovered?.height?.toString() ?? '',
              'weight': recovered?.weight?.toString() ?? '',
              'medical_conditions': recovered?.medicalConditions ?? '',
              'allergies': recovered?.allergies ?? '',
              'phone_number': recovered?.emergencyContactPhone ?? '',
            };
            for (final entry in existing.entries) {
              final baseline = switch (entry.key) {
                'height' => _height ?? '',
                'weight' => _weight ?? '',
                'medical_conditions' =>
                  _conditions ?? profile.patientProfile.medicalConditions ?? '',
                'allergies' =>
                  _allergies ?? profile.patientProfile.allergies ?? '',
                _ => _phone ?? '',
              };
              if (values[entry.key] == baseline.trim()) {
                values[entry.key] = entry.value;
              }
            }
          }
          await _persist(values);
          if (mounted) setState(() => _healthError = null);
        },
        values: {
          'blood_type': profile.patientProfile.bloodType ?? '',
          'contact_name': profile.patientProfile.emergencyContact ?? '',
          'height': _height ?? '',
          'weight': _weight ?? '',
          'medical_conditions':
              _conditions ?? profile.patientProfile.medicalConditions ?? '',
          'allergies': _allergies ?? profile.patientProfile.allergies ?? '',
          'phone_number': _phone ?? '',
        },
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health status saved.')));
    }
  }

  ImageProvider? _photo() {
    final value = profile.profilePicture;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('data:')) {
      try {
        return MemoryImage(
          base64Decode(value.substring(value.indexOf(',') + 1)),
        );
      } on FormatException {
        return null;
      }
    }
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? NetworkImage(value)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final patient = profile.patientProfile;
    final photo = _photo();
    final role =
        UserRole.fromBackend(profile.role)?.label ?? 'Role not provided';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          GabayCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: g.accentTint,
                  foregroundImage: photo,
                  onForegroundImageError: photo == null ? null : (_, _) {},
                  child: GabayAccentIcon(
                    Icons.person_outline,
                    color: g.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _value(profile.name),
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: GabayTypography.cardTitle,
                          fontWeight: GabayTypography.regular,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: TextStyle(
                          color: g.accent,
                          fontSize: GabayTypography.supporting,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${patient.age == null ? 'Age not provided' : '${patient.age} years old'} • ${_value(patient.gender)}',
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: GabayTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: GabaySectionLabel(label: 'Health Overview'),
              ),
              IconButton(
                tooltip: 'Edit health details',
                onPressed: _loadingHealth ? null : () => _edit(),
                icon: GabayAccentIcon(
                  Icons.edit_outlined,
                  color: g.accent,
                  size: 20,
                ),
              ),
            ],
          ),
          Text(
            'Manage your health information.',
            style: TextStyle(
              color: g.textSecondary,
              fontSize: GabayTypography.caption,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingHealth)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading health status',
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(13) > 20
                  ? 1
                  : 3;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              final cards = <Widget>[
                SizedBox(
                  width: width,
                  child: _OverviewCard(
                    label: 'Blood Type',
                    value: _value(patient.bloodType),
                    icon: Icons.water_drop_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _OverviewCard(
                    label: 'Height',
                    value: _value(_height),
                    unit: _height?.isNotEmpty == true ? 'cm' : '',
                    icon: Icons.straighten,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _OverviewCard(
                    label: 'Weight',
                    value: _value(_weight),
                    unit: _weight?.isNotEmpty == true ? 'kg' : '',
                    icon: Icons.monitor_weight_outlined,
                  ),
                ),
              ];
              if (columns == 1) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _HealthSection(
            title: 'Medical Conditions',
            icon: Icons.warning_amber_rounded,
            child: Builder(
              builder: (context) {
                final text = _conditions ?? patient.medicalConditions;
                final entries = (text ?? '')
                    .split(RegExp(r'[,;\n]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (entries.isEmpty) {
                  return Text(
                    'Not provided',
                    style: TextStyle(color: g.textSecondary),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final condition in entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: g.accentTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          condition,
                          style: TextStyle(
                            color: g.accent,
                            fontSize: GabayTypography.caption,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _HealthSection(
            title: 'Allergies',
            icon: Icons.block_outlined,
            child: Text(
              _value(_allergies ?? patient.allergies),
              style: TextStyle(
                color: g.textSecondary,
                fontSize: GabayTypography.supporting,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: GabaySectionLabel(label: 'Emergency Contact'),
              ),
            ],
          ),
          GabayCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const _HealthIcon(icon: Icons.person_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _value(patient.emergencyContact),
                            style: TextStyle(
                              color: g.textPrimary,
                              fontWeight: GabayTypography.regular,
                              fontSize: GabayTypography.body,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Emergency contact',
                            style: TextStyle(
                              color: g.textSecondary,
                              fontSize: GabayTypography.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(color: g.border.withValues(alpha: 0.5)),
                _HealthDetail(label: 'Phone Number', value: _value(_phone)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthIcon extends StatelessWidget {
  const _HealthIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.gabay.accentTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: GabayAccentIcon(icon, color: context.gabay.accent, size: 24),
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    this.unit = '',
  });
  final String label, value, unit;
  final IconData icon;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    child: Column(
      children: [
        _HealthIcon(icon: icon),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.gabay.textSecondary,
            fontSize: GabayTypography.caption,
          ),
        ),
        const SizedBox(height: 5),
        Text.rich(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          TextSpan(
            text: value,
            children: [
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: GabayTypography.chartLabel),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.gabay.accent,
            fontSize: value == 'Not provided' ? 13 : 17,
            fontWeight: GabayTypography.regular,
          ),
        ),
      ],
    ),
  );
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HealthIcon(icon: icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.gabay.textPrimary,
                  fontWeight: GabayTypography.regular,
                  fontSize: GabayTypography.body,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _HealthDetail extends StatelessWidget {
  const _HealthDetail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final caption = Text(
        label,
        style: TextStyle(
          color: context.gabay.textSecondary,
          fontSize: GabayTypography.supporting,
        ),
      );
      final content = Text(
        value,
        style: TextStyle(
          color: context.gabay.accent,
          fontSize: GabayTypography.supporting,
        ),
      );
      if (MediaQuery.textScalerOf(context).scale(13) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [caption, const SizedBox(height: 6), content],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: caption),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: content),
          ),
        ],
      );
    },
  );
}

class _HealthEditor extends StatefulWidget {
  const _HealthEditor({
    required this.values,
    required this.onSave,
    required this.section,
  });
  final String section;
  final Map<String, String> values;
  final Future<void> Function(Map<String, String>) onSave;
  @override
  State<_HealthEditor> createState() => _HealthEditorState();
}

class _HealthEditorState extends State<_HealthEditor> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  late final Map<String, TextEditingController> _controllers;
  @override
  void initState() {
    super.initState();
    _controllers = widget.values.map(
      (key, value) => MapEntry(key, TextEditingController(text: value)),
    );
  }

  Map<String, String> get _fields {
    final groups = <String, Map<String, String>>{
      'basic': {
        'blood_type': 'Blood Type',
        'height': 'Height (cm)',
        'weight': 'Weight (kg)',
      },
      'medical_conditions': {'medical_conditions': 'Medical Conditions'},
      'allergies': {'allergies': 'Allergies'},
      'contact': {
        'contact_name': 'Emergency Contact Name',
        'phone_number': 'Emergency Contact Phone Number',
      },
    };
    return {
      ...groups[widget.section]!,
      for (final group in groups.entries)
        if (group.key != widget.section) ...group.value,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      20,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HealthIcon(icon: Icons.health_and_safety_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit health details',
                        style: TextStyle(
                          color: context.gabay.textPrimary,
                          fontSize: GabayTypography.pageTitle,
                          fontWeight: GabayTypography.semibold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Keep your health and contact details up to date.',
                        style: TextStyle(
                          color: context.gabay.textSecondary,
                          fontSize: GabayTypography.supporting,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close health editor',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (final field in _fields.entries) ...[
              if (const [
                'blood_type',
                'medical_conditions',
                'allergies',
                'contact_name',
              ].contains(field.key))
                _editorSection(context, field.key),
              if (field.key == 'blood_type')
                GabayDropdownFormField<String>(
                  key: const ValueKey('blood_type'),
                  initialValue: _controllers['blood_type']!.text,
                  isExpanded: true,
                  decoration: _editorDecoration(context, 'Blood Type'),
                  style: TextStyle(
                    color: context.gabay.textPrimary,
                    fontSize: GabayTypography.body,
                  ),
                  items:
                      {
                            '',
                            'A+',
                            'A-',
                            'B+',
                            'B-',
                            'AB+',
                            'AB-',
                            'O+',
                            'O-',
                            _controllers['blood_type']!.text,
                          }
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value.isEmpty ? 'Not provided' : value,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) =>
                            _controllers['blood_type']!.text = value ?? '',
                )
              else
                TextFormField(
                  enabled: !_saving,
                  key: ValueKey(field.key),
                  controller: _controllers[field.key],
                  maxLines:
                      field.key == 'medical_conditions' ||
                          field.key == 'allergies'
                      ? 3
                      : 1,
                  keyboardType: field.key == 'height' || field.key == 'weight'
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : field.key == 'phone_number'
                      ? TextInputType.phone
                      : TextInputType.multiline,
                  style: TextStyle(
                    color: context.gabay.textPrimary,
                    fontSize: GabayTypography.body,
                    height: 1.4,
                  ),
                  decoration: _editorDecoration(context, field.value).copyWith(
                    suffixText: field.key == 'height'
                        ? 'cm'
                        : field.key == 'weight'
                        ? 'kg'
                        : null,
                    alignLabelWithHint:
                        field.key == 'medical_conditions' ||
                        field.key == 'allergies',
                  ),
                  validator: (value) {
                    if ((field.key == 'height' || field.key == 'weight') &&
                        value != null &&
                        value.trim().isNotEmpty) {
                      final number = double.tryParse(value.trim());
                      if (number == null || !number.isFinite || number <= 0) {
                        return 'Enter a positive number';
                      }
                      if (number >= 1000 ||
                          (number * 100 - (number * 100).round()).abs() >
                              0.000001) {
                        return 'Use a value below 1000 with up to two decimals';
                      }
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  context.gabay.accent.withValues(alpha: .10),
                  context.gabay.surface,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.gabay.accent.withValues(alpha: .16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: context.gabay.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'One emergency contact per account.',
                      style: TextStyle(
                        color: context.gabay.textSecondary,
                        fontSize: GabayTypography.caption,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: context.gabay.danger),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      setState(() {
                        _saving = true;
                        _error = null;
                      });
                      try {
                        await widget.onSave(
                          _controllers.map(
                            (key, value) => MapEntry(key, value.text.trim()),
                          ),
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (error) {
                        if (mounted) {
                          setState(() => _error = _saveErrorMessage(error));
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(_saving ? 'Saving…' : 'Save Changes'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: GabayTheme.secondaryButtonStyle(context).copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
              ),
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  InputDecoration _editorDecoration(BuildContext context, String label) {
    final g = context.gabay;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      floatingLabelStyle: TextStyle(
        color: g.textSecondary,
        fontSize: GabayTypography.cardTitle,
        fontWeight: GabayTypography.medium,
      ),
      labelStyle: TextStyle(
        color: g.textSecondary,
        fontSize: GabayTypography.supporting,
        fontWeight: GabayTypography.medium,
      ),
      filled: true,
      fillColor: dark ? g.surfaceElevated : g.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: g.border.withValues(alpha: .8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: g.accent, width: 1.5),
      ),
    );
  }

  String _saveErrorMessage(Object error) {
    if (error is ProfileException) {
      switch (error.statusCode) {
        case 401:
          return 'Please sign in again before saving. Your entries are retained.';
        case 403:
          return 'This account cannot save these details. Your entries are retained.';
        case 409:
          return 'Save your Profile first, then retry Health Details. Your entries are retained.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'The health service is unavailable. Your entries are retained. Please retry later.';
      }
    }
    return 'Unable to save health status. Your entries are retained.';
  }

  Widget _editorSection(BuildContext context, String field) {
    final (title, icon) = switch (field) {
      'blood_type' => (
        'Basic Health Information',
        Icons.monitor_heart_outlined,
      ),
      'medical_conditions' => (
        'Medical Conditions',
        Icons.medical_information_outlined,
      ),
      'allergies' => ('Allergies', Icons.shield_outlined),
      _ => ('Emergency Contact', Icons.person_outline_rounded),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: context.gabay.accentTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: GabayAccentIcon(icon, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.gabay.textPrimary,
                fontSize: GabayTypography.cardBody,
                fontWeight: GabayTypography.semibold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
