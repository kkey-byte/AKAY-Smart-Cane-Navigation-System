import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/patient_profile.dart';
import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../theme/gabay_theme.dart';

/// Progressive profile completion form.
/// Saves Account fields → Users, Health fields → PatientProfiles.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _medicalController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _addressController = TextEditingController();

  final _profileService = ProfileService.instance;
  final _picker = ImagePicker();

  DateTime? _birthdate;
  String? _gender;
  String? _bloodType;
  String? _profilePictureUrl;
  Uint8List? _localPhotoBytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    final session = AppSessionService.instance;
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
      _birthdate = p.birthdate;
      _gender = _normalizeChoice(p.gender, _genders);
      _bloodType = _normalizeChoice(p.bloodType, _bloodTypes);
      _ageController.text = p.age?.toString() ??
          (_birthdate != null ? _ageFromBirthdate(_birthdate!).toString() : '');
      _medicalController.text = p.medicalConditions ?? '';
      _allergiesController.text = p.allergies ?? '';
      _emergencyController.text = p.emergencyContact ?? '';
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
    );
    if (picked == null) return;
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
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _localPhotoBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      _snack('Please select a gender.');
      return;
    }
    if (_bloodType == null) {
      _snack('Please select a blood type.');
      return;
    }
    if (_birthdate == null) {
      _snack('Please select your birthdate.');
      return;
    }

    setState(() => _saving = true);
    try {
      final age = int.tryParse(_ageController.text.trim()) ??
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
          medicalConditions: _medicalController.text.trim(),
          allergies: _allergiesController.text.trim(),
          bloodType: _bloodType,
          emergencyContact: _emergencyController.text.trim(),
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
    _medicalController.dispose();
    _allergiesController.dispose();
    _emergencyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final session = AppSessionService.instance;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving || _loading ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (session.needsProfileCompletion)
                        _IncompleteBanner(color: g),
                      if (_error != null) ...[
                        Text(
                          'Could not refresh from server. You can still edit and save.\n$_error',
                          style: TextStyle(color: g.danger, fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _AvatarPicker(
                        localBytes: _localPhotoBytes,
                        networkUrl: _profilePictureUrl,
                        onTap: _pickPhoto,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the camera to upload a profile photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Account Information',
                        subtitle: 'Saved to your AKAY user account',
                        children: [
                          _LabeledField(
                            label: 'Full name',
                            child: TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Name is required'
                                      : null,
                              decoration: _inputDecoration(context),
                            ),
                          ),
                          _LabeledField(
                            label: 'Email address',
                            child: TextFormField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: _inputDecoration(context).copyWith(
                                helperText: 'Email cannot be changed here',
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
                              decoration: _inputDecoration(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Personal & Health Details',
                        subtitle: 'Saved to your patient profile',
                        children: [
                          _LabeledField(
                            label: 'Birthdate',
                            child: InkWell(
                              onTap: _pickBirthdate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: _inputDecoration(context).copyWith(
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  _birthdate == null
                                      ? 'Select birthdate'
                                      : '${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-${_birthdate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _birthdate == null
                                        ? g.textSecondary
                                        : g.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Age',
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(context).copyWith(
                                helperText: 'Auto-filled from birthdate',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Gender',
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('gender_${_gender ?? 'none'}'),
                              initialValue: _gender,
                              items: _genders
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _gender = v),
                              decoration: _inputDecoration(context),
                            ),
                          ),
                          _LabeledField(
                            label: 'Blood type',
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('blood_${_bloodType ?? 'none'}'),
                              initialValue: _bloodType,
                              items: _bloodTypes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _bloodType = v),
                              decoration: _inputDecoration(context),
                            ),
                          ),
                          _LabeledField(
                            label: 'Medical conditions',
                            child: TextFormField(
                              controller: _medicalController,
                              maxLines: 3,
                              decoration: _inputDecoration(context).copyWith(
                                hintText: 'e.g. Visually impaired, Asthma',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Allergies',
                            child: TextFormField(
                              controller: _allergiesController,
                              maxLines: 3,
                              decoration: _inputDecoration(context).copyWith(
                                hintText: 'e.g. Penicillin, Seafood',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Emergency contact',
                            child: TextFormField(
                              controller: _emergencyController,
                              maxLines: 2,
                              decoration: _inputDecoration(context).copyWith(
                                hintText: 'Name · Relationship · Phone',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Address',
                            child: TextFormField(
                              controller: _addressController,
                              maxLines: 3,
                              decoration: _inputDecoration(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: g.accent,
                            disabledBackgroundColor:
                                g.accent.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Saving…' : 'Save Changes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final g = context.gabay;
    return InputDecoration(
      fillColor: g.chipBackground,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: g.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: g.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: g.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          Icon(Icons.info_outline_rounded, color: color.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete your profile to help caregivers support you better during navigation.',
              style: TextStyle(
                color: color.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
  });

  final VoidCallback onTap;
  final Uint8List? localBytes;
  final String? networkUrl;

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
              border: Border.all(color: g.accent, width: 3),
              color: g.accentTint,
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? Icon(Icons.person_rounded, size: 48, color: g.accent)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: g.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: g.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
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
    final g = context.gabay;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: g.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: g.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: g.heading,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: g.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
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
    final g = context.gabay;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: g.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
