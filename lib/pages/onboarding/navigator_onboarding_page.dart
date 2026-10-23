import '../../services/pairing_service.dart';
import '../shared/pairing_management_page.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/onboarding_data.dart';
import '../../services/app_session_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/onboarding/onboarding_widgets.dart';
import '../../widgets/shared/gabay_card.dart';
import 'onboarding_router.dart';

class NavigatorOnboardingPage extends StatefulWidget {
  const NavigatorOnboardingPage({super.key});

  @override
  State<NavigatorOnboardingPage> createState() =>
      _NavigatorOnboardingPageState();
}

class _NavigatorOnboardingPageState extends State<NavigatorOnboardingPage> {
  static const _setupSteps = 6;

  int _step = 0;
  bool _canePaired = false;
  bool _locationGranted = false;
  bool _notificationsGranted = false;

  final _contacts = <EmergencyContact>[];
  AccessibilityPreferences _accessibility = const AccessibilityPreferences();
  final _tutorialController = PageController();
  int _tutorialIndex = 0;

  final _tutorialPages = const [
    (
      Icons.navigation_rounded,
      'Smart Navigation',
      'Navigate safely using real-time voice guidance.',
    ),
    (
      Icons.sos_rounded,
      'Emergency SOS',
      'Quickly notify trusted caregivers during emergencies.',
    ),
    (
      Icons.bluetooth_rounded,
      'Smart Cane',
      'Connect your Smart Cane for obstacle detection and navigation.',
    ),
    (
      Icons.favorite_rounded,
      'Caregiver Monitoring',
      'Allow caregivers to monitor navigation and receive emergency alerts.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final saved = AppSessionService.instance.setupData;
    _canePaired = false; // Legacy setup flags did not verify a device.
    _locationGranted = saved.locationGranted;
    _notificationsGranted = saved.notificationsGranted;
    _contacts.addAll(saved.emergencyContacts);
    _accessibility = saved.accessibility;
  }

  @override
  void dispose() {
    _tutorialController.dispose();
    super.dispose();
  }

  double? get _progress {
    if (_step <= 0 || _step > _setupSteps) return null;
    return _step / _setupSteps;
  }

  String? get _stepLabel {
    if (_step <= 0 || _step > _setupSteps) return null;
    return 'Step $_step of $_setupSteps';
  }

  bool get _canContinue {
    return switch (_step) {
      0 => true,
      1 =>
        true, // Device registration is independent from onboarding completion.
      2 => _contacts.isNotEmpty,
      3 => _locationGranted,
      4 => true,
      5 => _notificationsGranted,
      6 => true,
      7 => true,
      _ => false,
    };
  }

  Future<void> _persistPartial() async {
    await AppSessionService.instance.updateSetupData(
      AppSessionService.instance.setupData.copyWith(
        smartCanePaired: _canePaired,
        emergencyContacts: List.of(_contacts),
        locationGranted: _locationGranted,
        notificationsGranted: _notificationsGranted,
        accessibility: _accessibility,
      ),
    );
  }

  void _nextStep() async {
    if (!_canContinue && _step != 0 && _step != 6) return;

    if (_step == 6) {
      await _persistPartial();
    } else if (_step > 0 && _step < 7) {
      await _persistPartial();
    }

    if (!mounted) return;
    if (_step >= 7) {
      await OnboardingRouter.openDashboard(context);
      return;
    }

    setState(() => _step++);
  }

  void _previousStep() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Future<void> _openCaneManagement() async {
    final revision = AppSessionService.instance.identityRevision;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PairingManagementPage(caregiver: false),
      ),
    );
    try {
      final devices = await PairingService.instance.devices();
      if (!mounted || revision != AppSessionService.instance.identityRevision) {
        return;
      }
      setState(
        () =>
            _canePaired = devices.any((device) => device.assignmentId != null),
      );
      await _persistPartial();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to refresh registered canes. Open device management to retry.',
          ),
        ),
      );
    }
  }

  Future<void> _skipCane() async {
    await AppSessionService.instance.updateSetupData(
      AppSessionService.instance.setupData.copyWith(smartCaneSkipped: true),
    );
    _nextStep();
  }

  Future<void> _requestLocation({required bool always}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services.')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (always && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    final granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    setState(() => _locationGranted = granted);
    if (granted) await _persistPartial();
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    final granted = status.isGranted;
    setState(() => _notificationsGranted = granted);
    if (granted) await _persistPartial();
  }

  Future<void> _addContact() async {
    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (context) => const _AddContactDialog(),
    );
    if (result == null) return;
    setState(() => _contacts.add(result));
    await _persistPartial();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      stepLabel: _stepLabel,
      progress: _progress,
      onBack: _step > 0 && _step < 7 ? _previousStep : null,
      bottomBar: _buildBottomBar(),
      child: KeyedSubtree(key: ValueKey(_step), child: _buildStepContent()),
    );
  }

  Widget _buildBottomBar() {
    if (_step == 7) {
      return OnboardingPrimaryButton(
        label: 'Go to Dashboard',
        onPressed: _nextStep,
      );
    }

    if (_step == 0) {
      return OnboardingPrimaryButton(
        label: 'Get Started',
        onPressed: _nextStep,
      );
    }

    if (_step == 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingPrimaryButton(
            label: _tutorialIndex == _tutorialPages.length - 1
                ? 'Finish Tutorial'
                : 'Continue',
            onPressed: () {
              if (_tutorialIndex < _tutorialPages.length - 1) {
                _tutorialController.nextPage(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
              } else {
                _nextStep();
              }
            },
          ),
          OnboardingTextButton(
            label: 'Skip tutorial',
            onPressed: () async {
              await AppSessionService.instance.updateSetupData(
                AppSessionService.instance.setupData.copyWith(
                  tutorialSkipped: true,
                ),
              );
              _nextStep();
            },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingPrimaryButton(
          label: 'Continue',
          onPressed: _canContinue ? _nextStep : null,
          enabled: _canContinue,
        ),
        if (_step == 1)
          OnboardingTextButton(label: 'Skip for now', onPressed: _skipCane),
      ],
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _welcomeStep(),
      1 => _caneStep(),
      2 => _emergencyStep(),
      3 => _locationStep(),
      4 => _accessibilityStep(),
      5 => _notificationsStep(),
      6 => _tutorialStep(),
      _ => _completeStep(),
    };
  }

  Widget _welcomeStep() {
    final g = context.gabay;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          const OnboardingIllustration(icon: Icons.waving_hand_rounded),
          const SizedBox(height: 28),
          Text(
            'Welcome to GABAY!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: g.heading,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Let's complete a few quick steps to personalize your experience.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5, color: g.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _caneStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          OnboardingIllustration(
            icon: _canePaired
                ? Icons.check_rounded
                : Icons.bluetooth_searching_rounded,
            colors: _canePaired
                ? [context.gabay.success, const Color(0xFF059669)]
                : null,
          ),
          const SizedBox(height: 24),
          Text('Register Smart Canes', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 10),
          const OnboardingInfoCard(
            title: 'Register and assign your canes',
            subtitle:
                'Verify physical custody using each cane’s private claim code, then assign it to your account. Registration does not confirm hardware connectivity.',
            leading: Icon(Icons.info_outline_rounded, color: Color(0xFF0A84FF)),
          ),
          const SizedBox(height: 20),
          if (_canePaired)
            GabayCard(
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.gabay.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registered cane assignment confirmed for your account.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.gabay.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OnboardingPrimaryButton(
            label: 'Register or manage smart canes',
            onPressed: _openCaneManagement,
          ),
        ],
      ),
    );
  }

  Widget _emergencyStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: OnboardingIllustration(icon: Icons.contact_phone_rounded),
          ),
          const SizedBox(height: 24),
          Text('Emergency Contacts', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(
            'Add people who should be notified during SOS alerts.',
            style: TextStyle(color: context.gabay.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          ..._contacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GabayCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: context.gabay.accentTint,
                    child: Icon(
                      Icons.person_rounded,
                      color: context.gabay.accent,
                    ),
                  ),
                  title: Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${contact.phone}${contact.relationship.isNotEmpty ? ' • ${contact.relationship}' : ''}',
                  ),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Contact'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          const OnboardingIllustration(icon: Icons.location_on_rounded),
          const SizedBox(height: 24),
          Text('Location Access', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          const OnboardingInfoCard(
            title: 'Why we need your location',
            subtitle:
                'GABAY uses your location for turn-by-turn navigation, live caregiver sharing, and emergency SOS routing.',
          ),
          const SizedBox(height: 18),
          OnboardingPrimaryButton(
            label: 'While Using App',
            onPressed: () => _requestLocation(always: false),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _requestLocation(always: true),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Always Allow'),
          ),
          if (_locationGranted) ...[
            const SizedBox(height: 16),
            Text(
              'Location access granted',
              style: TextStyle(
                color: context.gabay.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accessibilityStep() {
    final previewScale = _accessibility.textScale;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: OnboardingIllustration(
              icon: Icons.accessibility_new_rounded,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Accessibility Preferences',
            style: GabayTheme.sectionTitle(context),
          ),
          const SizedBox(height: 16),
          GabayCard(
            child: Text(
              'Live preview: Navigation will feel like this.',
              style: TextStyle(
                fontSize: 15 * previewScale,
                fontWeight: FontWeight.w700,
                color: _accessibility.highContrast
                    ? Colors.black
                    : context.gabay.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _prefTile(
            'Text Size',
            Slider(
              value: _accessibility.textScale,
              min: 0.9,
              max: 1.4,
              divisions: 5,
              label: _accessibility.textScale.toStringAsFixed(1),
              onChanged: (v) => setState(
                () => _accessibility = _accessibility.copyWith(textScale: v),
              ),
            ),
          ),
          _prefSwitch('High Contrast', _accessibility.highContrast, (v) {
            setState(
              () => _accessibility = _accessibility.copyWith(highContrast: v),
            );
          }),
          _prefSwitch('Voice Guidance', _accessibility.voiceGuidance, (v) {
            setState(
              () => _accessibility = _accessibility.copyWith(voiceGuidance: v),
            );
          }),
          _prefTile(
            'Speech Speed',
            Slider(
              value: _accessibility.speechSpeed,
              min: 0.7,
              max: 1.3,
              divisions: 6,
              label: _accessibility.speechSpeed.toStringAsFixed(1),
              onChanged: (v) => setState(
                () => _accessibility = _accessibility.copyWith(speechSpeed: v),
              ),
            ),
          ),
          _prefTile(
            'Language',
            DropdownButtonFormField<String>(
              value: _accessibility.language,
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Filipino', child: Text('Filipino')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(
                  () => _accessibility = _accessibility.copyWith(language: v),
                );
              },
            ),
          ),
          _prefSwitch('Haptic Feedback', _accessibility.hapticFeedback, (v) {
            setState(
              () => _accessibility = _accessibility.copyWith(hapticFeedback: v),
            );
          }),
        ],
      ),
    );
  }

  Widget _prefTile(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GabayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _prefSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GabayCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _notificationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          const OnboardingIllustration(
            icon: Icons.notifications_active_rounded,
          ),
          const SizedBox(height: 24),
          Text('Notifications', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          const OnboardingInfoCard(
            title: 'Stay informed',
            subtitle:
                'Notifications are used for SOS alerts, navigation updates, Smart Cane battery alerts, and caregiver messages.',
          ),
          const SizedBox(height: 18),
          OnboardingPrimaryButton(
            label: 'Enable Notifications',
            onPressed: _requestNotifications,
          ),
          if (_notificationsGranted) ...[
            const SizedBox(height: 16),
            Text(
              'Notifications enabled',
              style: TextStyle(
                color: context.gabay.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tutorialStep() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _tutorialController,
            itemCount: _tutorialPages.length,
            onPageChanged: (index) => setState(() => _tutorialIndex = index),
            itemBuilder: (context, index) {
              final page = _tutorialPages[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OnboardingIllustration(icon: page.$1),
                    const SizedBox(height: 28),
                    Text(
                      page.$2,
                      textAlign: TextAlign.center,
                      style: GabayTheme.sectionTitle(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      page.$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: context.gabay.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _tutorialPages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _tutorialIndex == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _tutorialIndex == index
                    ? context.gabay.accent
                    : context.gabay.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _completeStep() {
    final g = context.gabay;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: OnboardingIllustration(
              icon: Icons.check_rounded,
              colors: [g.success, const Color(0xFF059669)],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "You're All Set!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: g.heading,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your account has been successfully configured. Everything is ready for your first journey.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5, color: g.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Emergency Contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          TextField(
            controller: _relationship,
            decoration: const InputDecoration(labelText: 'Relationship'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              EmergencyContact(
                name: _name.text.trim(),
                phone: _phone.text.trim(),
                relationship: _relationship.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
