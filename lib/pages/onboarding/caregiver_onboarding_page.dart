import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/app_session_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/onboarding/onboarding_widgets.dart';
import 'onboarding_router.dart';

class CaregiverOnboardingPage extends StatefulWidget {
  const CaregiverOnboardingPage({super.key});

  @override
  State<CaregiverOnboardingPage> createState() =>
      _CaregiverOnboardingPageState();
}

class _CaregiverOnboardingPageState extends State<CaregiverOnboardingPage> {
  static const _setupSteps = 3;

  int _step = 0;
  bool _notificationsGranted = false;
  bool _locationGranted = false;

  final _tutorialController = PageController();
  int _tutorialIndex = 0;

  final _tutorialPages = const [
    (
      Icons.map_rounded,
      'Live Tracking',
      'Monitor your linked navigator in real time during walks.',
    ),
    (
      Icons.sos_rounded,
      'Emergency Alerts',
      'Receive instant SOS notifications from your loved one.',
    ),
    (
      Icons.analytics_rounded,
      'Route Reports',
      'Review completed journeys, places visited, and activity history.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final saved = AppSessionService.instance.setupData;
    _notificationsGranted = saved.notificationsGranted;
    _locationGranted = saved.locationGranted;
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
      1 => _notificationsGranted,
      2 => true,
      3 => true,
      4 => true,
      _ => false,
    };
  }

  Future<void> _persistPartial() async {
    await AppSessionService.instance.updateSetupData(
      AppSessionService.instance.setupData.copyWith(
        notificationsGranted: _notificationsGranted,
        locationGranted: _locationGranted,
      ),
    );
  }

  void _nextStep() async {
    if (!_canContinue && _step != 0 && _step != 2 && _step != 3) return;

    if (_step > 0 && _step < 4) {
      await _persistPartial();
    }

    if (!mounted) return;
    if (_step >= 4) {
      await OnboardingRouter.openDashboard(context);
      return;
    }

    setState(() => _step++);
  }

  void _previousStep() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    setState(() => _notificationsGranted = status.isGranted);
    if (status.isGranted) await _persistPartial();
  }

  Future<void> _requestLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    setState(() => _locationGranted = granted);
    if (granted) await _persistPartial();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      stepLabel: _stepLabel,
      progress: _progress,
      onBack: _step > 0 && _step < 4 ? _previousStep : null,
      bottomBar: _buildBottomBar(),
      child: KeyedSubtree(key: ValueKey(_step), child: _buildStepContent()),
    );
  }

  Widget _buildBottomBar() {
    if (_step == 4) {
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

    if (_step == 3) {
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
        if (_step == 2)
          OnboardingTextButton(label: 'Skip for now', onPressed: _nextStep),
      ],
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _welcomeStep(),
      1 => _notificationsStep(),
      2 => _locationStep(),
      3 => _tutorialStep(),
      _ => _completeStep(),
    };
  }

  Widget _welcomeStep() {
    final g = context.gabay;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          const OnboardingIllustration(icon: Icons.favorite_rounded),
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
            "Let's set up your caregiver account so you can support your navigator safely.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5, color: g.textSecondary),
          ),
        ],
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
            title: 'Stay connected',
            subtitle:
                'Get alerts for SOS emergencies, navigation updates, and Smart Cane battery warnings.',
          ),
          const SizedBox(height: 18),
          OnboardingPrimaryButton(
            label: 'Enable Notifications',
            onPressed: _requestNotifications,
          ),
          if (_notificationsGranted)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Notifications enabled',
                style: TextStyle(
                  color: context.gabay.success,
                  fontWeight: FontWeight.w700,
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
          const OnboardingIllustration(icon: Icons.share_location_rounded),
          const SizedBox(height: 24),
          Text('Location Access', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          const OnboardingInfoCard(
            title: 'Optional but helpful',
            subtitle:
                'Location helps show nearby navigators on the map and improves emergency response accuracy.',
          ),
          const SizedBox(height: 18),
          OnboardingPrimaryButton(
            label: 'Allow Location',
            onPressed: _requestLocation,
          ),
          if (_locationGranted)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Location access granted',
                style: TextStyle(
                  color: context.gabay.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                    Text(page.$2, style: GabayTheme.sectionTitle(context)),
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
            'Your caregiver account is ready. You can now monitor and support your navigator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5, color: g.textSecondary),
          ),
        ],
      ),
    );
  }
}
