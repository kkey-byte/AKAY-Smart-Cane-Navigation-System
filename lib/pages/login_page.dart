import '../theme/gabay_typography.dart';
import '../widgets/shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';

import '../navigation/role_router.dart';
import '../services/app_session_service.dart';
import '../services/auth_service.dart';
import '../theme/gabay_theme.dart';
import '../widgets/auth/gabay_auth_scaffold.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
  bool isLoading = false;
  String? errorMessage;

  Future<void> _login() async {
    setState(() => errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // 1) Firebase Auth verifies email/password → firebase_uid
      // 2) Backend: SELECT role FROM Users WHERE firebase_uid = $1
      final result = await AuthService.instance.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Role comes only from PostgreSQL — never from the login UI.
      final roleFromDb = result.user.role.backendValue;

      await AppSessionService.instance.loginSession(
        userEmail: result.user.email,
        userRole: result.user.role,
        id: result.user.userId,
        token: result.user.firebaseUid ?? result.token,
      );
      await AppSessionService.instance.updateProfileCache(
        name: result.user.name,
        phone: result.user.phone,
        profilePicture: result.user.profilePicture,
        profileComplete:
            (result.user.name?.trim().isNotEmpty == true) &&
            (result.user.phone?.trim().isNotEmpty == true),
      );

      if (!mounted) return;

      // caregiver → CaregiverDashboard
      // visually_impaired → VisuallyImpairedDashboard
      final routed = RoleRouter.routeBasedOnRole(roleFromDb, context);
      if (!routed) {
        await AuthService.instance.signOut();
        await AppSessionService.instance.logout();
        if (!mounted) return;
        setState(() {
          errorMessage =
              'Your account role could not be verified. Please contact support.';
        });
      }
    } on AuthException catch (e) {
      await AuthService.instance.signOut();
      await AppSessionService.instance.logout();
      if (!mounted) return;
      setState(() {
        errorMessage = e.message;
      });
    } catch (_) {
      await AuthService.instance.signOut();
      await AppSessionService.instance.logout();
      if (!mounted) return;
      setState(() {
        errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return GabayAuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue your journey with AKAY.',
      onBack: isLoading ? null : () => Navigator.pop(context),
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
                onPressed: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
                icon: GabayAccentIcon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => rememberMe = value ?? false),
                ),
                const Expanded(child: Text('Remember me')),
              ],
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: g.danger,
                      fontSize: GabayTypography.body,
                    ),
                  ),
                ),
              ),
            GabayAuthPrimaryButton(
              onPressed: isLoading ? null : _login,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        semanticsLabel: 'Signing in',
                      ),
                    )
                  : const Text('Login'),
            ),
            const SizedBox(height: 20),
            Text(
              "Don't have an account?",
              textAlign: TextAlign.center,
              style: GabayTheme.bodyMedium(context),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
