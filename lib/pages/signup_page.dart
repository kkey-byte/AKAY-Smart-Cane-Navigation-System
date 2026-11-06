import '../theme/gabay_typography.dart';
import '../widgets/shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';
import '../widgets/shared/gabay_selection_dialog.dart';

import '../models/user_role.dart';
import '../navigation/role_router.dart';
import '../services/app_session_service.dart';
import '../services/auth_service.dart';
import '../theme/gabay_theme.dart';
import '../widgets/auth/gabay_auth_scaffold.dart';
import '../widgets/auth/password_strength_indicator.dart';
import 'login_page.dart';
import 'shared/terms_conditions_page.dart';
import '../widgets/shared/gabay_page_header.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  bool agree = false;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  /// Maps to PostgreSQL `Users.role` via [UserRole.backendValue].
  UserRole selectedRole = UserRole.caregiver;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _termsOpening = false;

  Future<void> _reviewTerms() async {
    if (isLoading || _termsOpening) return;
    FocusScope.of(context).unfocus();
    _termsOpening = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .32),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GabayPageHeader(
                title: 'Terms & Conditions',
                showBack: false,
                actions: [
                  IconButton(
                    tooltip: 'Close terms',
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Flexible(child: TermsConditionsContent()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Confirm'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _termsOpening = false;
    if (!mounted) return;
    if (confirmed == true) setState(() => agree = true);
  }

  // Optional profile fields are intentionally omitted from the UI for
  // low-friction onboarding. They can be collected later and sent as:
  // name / phone / profilePicture → nullable Postgres columns.

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Please confirm your password';
    if (confirm != passwordController.text) return 'Passwords do not match';
    return null;
  }

  /// Sign Up button workflow:
  /// 1) Validate form  2) Loading  3) Firebase Auth
  /// 4) Sync profile to Postgres (`firebase_uid`)  5) Role-based navigation
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Conditions')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Step A+B: Firebase createUser → Postgres Users sync
      final result = await AuthService.instance.register(
        email: emailController.text.trim(),
        password: passwordController.text,
        role: selectedRole,
      );

      // Prefer the role returned from Postgres; fall back to the form selection.
      final roleString = result.user.role.backendValue.isNotEmpty
          ? result.user.role.backendValue
          : selectedRole.backendValue;

      await AppSessionService.instance.registerSession(
        userEmail: result.user.email,
        userRole: result.user.role,
        id: result.user.userId,
        token: result.user.firebaseUid ?? result.token,
      );

      if (!mounted) return;

      // Step C: clear auth stack → CaregiverDashboard / VisuallyImpairedDashboard
      final routed = RoleRouter.routeBasedOnRole(roleString, context);
      if (!routed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unrecognized account role.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return GabayAuthScaffold(
      title: 'Create Your Account',
      subtitle: 'Join AKAY and stay connected.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GabayAuthField(
              label: 'Email',
              icon: Icons.person_outline_rounded,
              controller: emailController,
              validator: _validateEmail,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),
            GabayAuthField(
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              controller: passwordController,
              validator: _validatePassword,
              enabled: !isLoading,
              obscureText: obscurePassword,
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
                icon: GabayAccentIcon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            PasswordStrengthIndicator(controller: passwordController),
            const SizedBox(height: 18),
            GabayAuthField(
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              controller: confirmPasswordController,
              validator: _validateConfirmPassword,
              enabled: !isLoading,
              obscureText: obscureConfirmPassword,
              suffixIcon: IconButton(
                tooltip: obscureConfirmPassword
                    ? 'Show confirm password'
                    : 'Hide confirm password',
                onPressed: () => setState(
                  () => obscureConfirmPassword = !obscureConfirmPassword,
                ),
                icon: GabayAccentIcon(
                  obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 18),
            GabayAuthSurface(
              child: GabayDropdownFormField<UserRole>(
                initialValue: selectedRole,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Role',
                  fillColor: Colors.transparent,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: g.surface.withValues(alpha: .8),
                    ),
                  ),
                  prefixIcon: Icon(Icons.badge_outlined, color: g.accent),
                ),
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value != null) setState(() => selectedRole = value);
                      },
                items: const [
                  DropdownMenuItem(
                    value: UserRole.caregiver,
                    child: Text('Caregiver'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.navigator,
                    child: Text('Navigator (Visually Impaired)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: agree,
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value == true) {
                            _reviewTerms();
                          } else {
                            setState(() => agree = false);
                          }
                        },
                ),
                Expanded(
                  child: InkWell(
                    onTap: isLoading ? null : _reviewTerms,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: GabayTypography.supporting,
                        ),
                        children: [
                          const TextSpan(text: 'Agree with '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: g.accent,
                              decoration: TextDecoration.underline,
                              fontWeight: GabayTypography.medium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GabayAuthPrimaryButton(
              onPressed: agree && !isLoading ? _handleSignUp : null,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        semanticsLabel: 'Creating account',
                      ),
                    )
                  : const Text('Create Account'),
            ),
            const SizedBox(height: 20),
            Text(
              'Already have an account?',
              textAlign: TextAlign.center,
              style: GabayTheme.bodyMedium(context),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
