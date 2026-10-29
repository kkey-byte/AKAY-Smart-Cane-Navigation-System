import 'package:flutter/material.dart';
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
    title: 'Information & Health Status',

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
  });
  final ProfileBundle profile;
  final HealthStatusService? healthService;
  @override
  State<InformationHealthContent> createState() =>
      _InformationHealthContentState();
}

class _InformationHealthContentState extends State<InformationHealthContent> {
  ProfileBundle get profile => widget.profile;
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
        setState(() => _healthError = 'Health status could not be loaded.');
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
      _identityRevision = AppSessionService.instance.identityRevision;
      _height = _weight = _conditions = _allergies = _phone = null;
      _loadHealth();
    }
  }

  String _value(String? value) =>
      value == null || value.trim().isEmpty ? 'Not provided' : value;

  Future<void> _edit() async {
    final editRevision = _identityRevision;
    final editUserId = profile.userId;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _HealthEditor(
        onSave: (values) {
          if (!mounted ||
              editRevision != AppSessionService.instance.identityRevision ||
              profile.userId != editUserId) {
            throw StateError('Account changed. Reopen health information.');
          }
          return _persist(values);
        },
        values: {
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
    return ListView(
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
                child: Icon(Icons.person_outline, color: g.accent, size: 32),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(role, style: TextStyle(color: g.accent, fontSize: 13)),
                    const SizedBox(height: 10),
                    Text(
                      '${patient.age == null ? 'Age not provided' : '${patient.age} years old'} • ${_value(patient.gender)}',
                      style: TextStyle(color: g.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: GabaySectionLabel(label: 'Health Overview')),
            IconButton(
              tooltip: 'Edit health details',
              onPressed: _loadingHealth || _healthError != null ? null : _edit,
              icon: Icon(Icons.edit_outlined, color: g.accent, size: 20),
            ),
          ],
        ),
        if (_loadingHealth)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading health status',
          ),
        if (_healthError != null) ...[
          Text(_healthError!, style: TextStyle(color: g.danger)),
          TextButton(
            onPressed: _loadHealth,
            child: const Text('Retry health status'),
          ),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = MediaQuery.textScalerOf(context).scale(13) > 20
                ? 1
                : 3;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
              ],
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
                        style: TextStyle(color: g.accent, fontSize: 12),
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
          child: _HealthDetail(
            label: 'Allergies',
            value: _value(_allergies ?? patient.allergies),
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
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Registered Caregiver',
                          style: TextStyle(
                            color: g.textSecondary,
                            fontSize: 12,
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
        const SizedBox(height: 20),
        const GabaySectionLabel(label: 'Address'),
        const SizedBox(height: 10),
        GabayCard(
          child: Text(
            _value(patient.address),
            style: TextStyle(color: g.textPrimary),
          ),
        ),
      ],
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
    child: Icon(icon, color: context.gabay.accent, size: 24),
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
          style: TextStyle(color: context.gabay.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: const TextStyle(fontSize: 10)),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.gabay.accent,
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        Divider(color: context.gabay.border.withValues(alpha: 0.5)),
        const SizedBox(height: 4),
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
        style: TextStyle(color: context.gabay.textSecondary, fontSize: 13),
      );
      final content = Text(
        value,
        style: TextStyle(color: context.gabay.accent, fontSize: 13),
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
  const _HealthEditor({required this.values, required this.onSave});
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
            Text(
              'Edit health details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Height is measured in cm and weight in kg.'),
            const SizedBox(height: 20),
            for (final field in const {
              'height': 'Height (cm)',
              'weight': 'Weight (kg)',
              'medical_conditions': 'Medical Conditions',
              'allergies': 'Allergies',
              'phone_number': 'Emergency Contact Phone Number',
            }.entries) ...[
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
                decoration: InputDecoration(
                  labelText: field.value,
                  filled: true,
                  fillColor: context.gabay.chipBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: context.gabay.danger),
                ),
              ),
            FilledButton(
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
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _error =
                                'Unable to save health status. Your entries are retained.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(_saving ? 'Saving…' : 'Save health status'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
