import '../../theme/gabay_typography.dart';
import '../../widgets/shared/gabay_page_header.dart';
import '../../widgets/shared/gabay_accent_icon.dart';
import '../../widgets/shared/gabay_page_background.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../widgets/shared/gabay_selection_dialog.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/patient_profile.dart';
import '../../models/profile_address.dart';
import '../../widgets/profile/address_editor_sheet.dart';
import '../../services/philippine_address_service.dart';
import '../../models/user_role.dart';
import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/profile/profile_header_clipper.dart';

/// Progressive profile completion form.
/// Saves Account fields → Users, Health fields → PatientProfiles.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.profileService, this.addressService});

  final ProfileService? profileService;
  final PhilippineAddressService? addressService;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();

  late final ProfileService _profileService;
  final _picker = ImagePicker();

  DateTime? _birthdate;
  String? _gender;
  String? _profilePictureUrl;
  Uint8List? _localPhotoBytes;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  Future<void> _editAddress() async {
    if (!_editing || _saving) return;
    final address = await showModalBottomSheet<ProfileAddress>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.gabay.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => AddressEditorSheet(
        initialAddress: _addressController.text,
        service: widget.addressService,
      ),
    );
    if (address != null && mounted) {
      setState(() => _addressController.text = address.serialize());
    }
  }

  String? _error;
  bool _isCaregiver = false;
  PatientProfile? _loadedPatientProfile;

  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService.instance;
    final session = AppSessionService.instance;
    _isCaregiver = session.role == UserRole.caregiver;
    _emailController.text = session.email ?? '';
    _nameController.text = session.displayName ?? '';
    _phoneController.text = session.phone ?? '';
    _profilePictureUrl = session.profilePicture;
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await _profileService.fetchProfile();
      if (!mounted) return;
      _nameController.text = bundle.name?.trim().isNotEmpty == true
          ? bundle.name!
          : _nameController.text;
      _emailController.text = bundle.email;
      _phoneController.text = bundle.phone ?? '';
      _profilePictureUrl = bundle.profilePicture;
      final p = bundle.patientProfile;
      _loadedPatientProfile = p;
      _isCaregiver = UserRole.fromBackend(bundle.role) == UserRole.caregiver;
      _birthdate = p.birthdate;
      _gender = _normalizeChoice(p.gender, _genders);
      _ageController.text =
          p.age?.toString() ??
          (_birthdate != null ? _ageFromBirthdate(_birthdate!).toString() : '');
      _addressController.text = p.address ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String? _normalizeChoice(String? value, List<String> options) {
    if (value == null || value.trim().isEmpty) return null;
    for (final o in options) {
      if (o.toLowerCase() == value.trim().toLowerCase()) return o;
    }
    return value;
  }

  int _ageFromBirthdate(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age -= 1;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select birthdate',
      cancelText: 'Cancel',
      confirmText: 'Save date',
      builder: (context, child) {
        final theme = Theme.of(context);
        final g = context.gabay;
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: g.accent),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: g.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: ProfileHeaderMetrics.navyBlue,
              headerForegroundColor: Colors.white,
              headerHelpStyle: const TextStyle(
                fontSize: GabayTypography.body,
                fontWeight: GabayTypography.medium,
              ),
              headerHeadlineStyle: const TextStyle(
                fontSize: GabayTypography.hero,
                fontWeight: GabayTypography.medium,
              ),
              weekdayStyle: _ProfileTypography.field(
                context,
              ).copyWith(fontWeight: GabayTypography.regular),
              dayStyle: _ProfileTypography.field(context),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return g.textSecondary;
                }
                if (states.contains(WidgetState.selected)) return Colors.white;
                return g.textPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? g.accent
                    : Colors.transparent,
              ),
              todayBorder: BorderSide(color: g.accent),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: g.heading,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: g.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _birthdate = picked;
      _ageController.text = _ageFromBirthdate(picked).toString();
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const GabayAccentIcon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const GabayAccentIcon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    if (!mounted) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _localPhotoBytes = bytes);
  }

  Future<void> _save() async {
    if (_saving || _loading || !_editing) return;
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      _snack('Please select a gender.');
      return;
    }
    if (_birthdate == null) {
      _snack('Please select your birthdate.');
      return;
    }

    setState(() => _saving = true);
    try {
      final age =
          int.tryParse(_ageController.text.trim()) ??
          _ageFromBirthdate(_birthdate!);

      // Store picture in Users.profile_picture as a data URL (reliable, no Storage).
      var pictureUrl = _profilePictureUrl;
      if (_localPhotoBytes != null) {
        pictureUrl = _profileService.encodeProfilePictureDataUrl(
          _localPhotoBytes!,
        );
      }

      await _profileService.saveProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        profilePicture: pictureUrl,
        patient: PatientProfile(
          age: age,
          gender: _gender,
          birthdate: _birthdate,
          medicalConditions: _loadedPatientProfile?.medicalConditions,
          allergies: _loadedPatientProfile?.allergies,
          bloodType: _loadedPatientProfile?.bloodType,
          emergencyContact: _loadedPatientProfile?.emergencyContact,
          address: _addressController.text.trim(),
        ),
      );

      if (!mounted) return;
      _snack('Profile updated successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatBirthdate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final session = AppSessionService.instance;

    return Scaffold(
      backgroundColor: g.scaffoldBackground,

      body: GabayPageBackground(
        child: GabayScrollingPage(
          header: GabayPageHeader(
            title: _editing ? 'Edit Profile' : 'Profile',
            showBack: false,
            leading: _editing
                ? null
                : IconButton(
                    icon: const GabayAccentIcon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
            actions: [
              if (!_editing)
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: _saving || _loading
                      ? null
                      : () => setState(() => _editing = true),
                  icon: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: g.accent,
                          ),
                        )
                      : const GabayAccentIcon(Icons.edit_outlined),
                ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: AbsorbPointer(
                        absorbing: !_editing || _saving,
                        child: ExcludeFocus(
                          excluding: !_editing || _saving,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height:
                                    (_editing ? 152.0 : 218.0) +
                                    (MediaQuery.textScalerOf(
                                                      context,
                                                    ).scale(14) /
                                                    14 -
                                                1)
                                            .clamp(0, 3) *
                                        90,
                                child: Stack(
                                  children: [
                                    ClipPath(
                                      clipper: const ProfileHeaderClipper(
                                        notchRadius: 48,
                                        sideDrop: 16,
                                      ),
                                      child: Container(
                                        height: 76,
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 0,
                                      right: 0,
                                      child: Column(
                                        children: [
                                          _AvatarPicker(
                                            localBytes: _localPhotoBytes,
                                            networkUrl: _profilePictureUrl,
                                            onTap: _pickPhoto,
                                            editable: _editing,
                                          ),
                                          const SizedBox(height: 10),
                                          if (!_editing) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                  ),
                                              child: Text(
                                                _nameController.text,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: g.textPrimary,
                                                  fontSize:
                                                      GabayTypography.cardTitle,
                                                  fontWeight:
                                                      GabayTypography.regular,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                  ),
                                              child: Text(
                                                _emailController.text,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: g.textSecondary,
                                                  fontSize: GabayTypography
                                                      .supporting,
                                                  fontWeight:
                                                      GabayTypography.regular,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                          Text(
                                            _isCaregiver
                                                ? 'Caregiver'
                                                : session.role?.label ??
                                                      'Navigator',
                                            style: TextStyle(
                                              color: g.accent,
                                              fontSize: GabayTypography.body,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (session.needsProfileCompletion)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: _IncompleteBanner(color: g),
                                ),
                              if (_error != null) ...[
                                Text(
                                  'Could not refresh from server. You can still edit and save.\n$_error',
                                  style: TextStyle(
                                    color: g.danger,
                                    fontSize: GabayTypography.body,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _SectionCard(
                                title: 'Account Information',
                                subtitle: 'Saved to your AKAY user account',
                                children: [
                                  _LabeledField(
                                    label: 'Full name',
                                    child: TextFormField(
                                      controller: _nameController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Name is required'
                                          : null,
                                      decoration: _inputDecoration(context)
                                          .copyWith(
                                            hintText: 'Enter your full name',
                                          ),
                                    ),
                                  ),
                                  _LabeledField(
                                    label: 'Email address',
                                    child: TextFormField(
                                      controller: _emailController,
                                      readOnly: true,
                                      decoration: _inputDecoration(context)
                                          .copyWith(
                                            hintText: 'Your email address',
                                          ),
                                    ),
                                  ),
                                  _LabeledField(
                                    label: 'Phone number',
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) =>
                                          (v == null || v.trim().length < 7)
                                          ? 'Enter a valid phone number'
                                          : null,
                                      decoration: _inputDecoration(context)
                                          .copyWith(
                                            hintText: 'Enter your phone number',
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              _SectionCard(
                                title: 'Personal & Health Details',
                                subtitle: 'Saved to your patient profile',
                                children: [
                                  _LabeledField(
                                    label: 'Date of birth',
                                    child: Semantics(
                                      button: true,
                                      child: InkWell(
                                        onTap: _pickBirthdate,
                                        borderRadius: BorderRadius.circular(
                                          GabayMetrics.controlRadius,
                                        ),
                                        child: InputDecorator(
                                          decoration: _inputDecoration(context)
                                              .copyWith(
                                                prefixIcon: null,
                                                suffixIcon: Icon(
                                                  Icons.edit_calendar_outlined,
                                                  color: g.accent,
                                                  size: 20,
                                                ),
                                              ),
                                          child: Text(
                                            _birthdate == null
                                                ? 'DD / MM / YYYY'
                                                : _formatBirthdate(_birthdate!),
                                            style: _ProfileTypography.field(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _LabeledField(
                                    label: 'Gender',
                                    child: GabayDropdownFormField<String>(
                                      dialogTitle: 'Gender',
                                      key: ValueKey(
                                        'gender_${_gender ?? 'none'}',
                                      ),
                                      initialValue: _gender,
                                      isExpanded: true,
                                      hint: const Text('Select gender'),
                                      items: _genders
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _gender = v),
                                      decoration: _inputDecoration(context),
                                    ),
                                  ),
                                  _LabeledField(
                                    label: 'Address',
                                    child: Semantics(
                                      button: _editing,
                                      label: 'Address details',
                                      child: InkWell(
                                        onTap: _editing ? _editAddress : null,
                                        borderRadius: BorderRadius.circular(
                                          GabayMetrics.controlRadius,
                                        ),
                                        child: InputDecorator(
                                          decoration: _inputDecoration(context),
                                          child: _AddressSummary(
                                            value: _addressController.text,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_editing) ...[
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _saving ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: g.accent,
                                        disabledBackgroundColor: g.accent
                                            .withValues(alpha: 0.5),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _saving ? 'Saving…' : 'Save Changes',
                                        style: const TextStyle(
                                          fontSize: GabayTypography.cardTitle,
                                          fontWeight: GabayTypography.regular,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final g = context.gabay;
    return InputDecoration(
      isDense: true,
      hintStyle: _ProfileTypography.field(context),
      labelStyle: _ProfileTypography.field(context),
      helperStyle: _ProfileTypography.field(context),
      errorStyle: _ProfileTypography.field(context).copyWith(color: g.danger),
      errorMaxLines: 3,
      fillColor: Theme.of(context).brightness == Brightness.light
          ? g.chipBackground
          : g.surfaceElevated,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
        borderSide: BorderSide(color: g.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
        borderSide: BorderSide(color: g.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
        borderSide: BorderSide(color: g.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );
  }
}

class _IncompleteBanner extends StatelessWidget {
  const _IncompleteBanner({required this.color});

  final GabayThemeExtension color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          GabayAccentIcon(Icons.info_outline_rounded, color: color.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete your profile to help caregivers support you better during navigation.',
              style: TextStyle(
                color: color.textPrimary,
                fontWeight: GabayTypography.regular,
                fontSize: GabayTypography.body,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.onTap,
    this.localBytes,
    this.networkUrl,
    this.editable = true,
  });

  final VoidCallback onTap;
  final Uint8List? localBytes;
  final String? networkUrl;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    ImageProvider? image;
    if (localBytes != null) {
      image = MemoryImage(localBytes!);
    } else if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      image = NetworkImage(networkUrl!);
    }

    return Center(
      child: Stack(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: g.surface, width: 4),
              color: g.accentTint,
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? GabayAccentIcon(
                    Icons.person_rounded,
                    size: 48,
                    color: g.accent,
                  )
                : null,
          ),
          if (editable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: ProfileHeaderMetrics.navyBlue,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Semantics(
                    button: true,
                    label: 'Change profile photo',
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: g.surface, width: 2),
                      ),
                      child: const GabayAccentIcon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddressSummary extends StatelessWidget {
  const _AddressSummary({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final address = ProfileAddress.tryParse(value);
    final g = context.gabay;
    Widget part(String label, String text) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: g.textSecondary,
            fontSize: GabayTypography.caption,
            fontWeight: GabayTypography.regular,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text.isEmpty ? 'Tap to add' : text,
          style: _ProfileTypography.field(context),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        part('Region, Province, City, Barangay', address?.area ?? value),
        const SizedBox(height: 12),
        Divider(color: g.border, height: 1),
        const SizedBox(height: 12),
        part('Postal Code', address?.postalCode ?? ''),
        const SizedBox(height: 12),
        Divider(color: g.border, height: 1),
        const SizedBox(height: 12),
        part('Street Name, Building, House No.', address?.street ?? ''),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...children],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(label, style: _ProfileTypography.field(context)),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: label,
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.copyWith(
                  bodyLarge: _ProfileTypography.field(context),
                  bodyMedium: _ProfileTypography.field(context),
                  titleMedium: _ProfileTypography.field(context),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class _ProfileTypography {
  static TextStyle field(BuildContext context) => TextStyle(
    fontSize: GabayTypography.body,
    fontWeight: GabayTypography.regular,
    color: context.gabay.textPrimary,
    height: 1.4,
  );
}
