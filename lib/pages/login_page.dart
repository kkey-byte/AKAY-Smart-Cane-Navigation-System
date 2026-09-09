import 'package:flutter/material.dart';

import '../navigation/role_router.dart';
import '../services/app_session_service.dart';
import '../services/auth_service.dart';
import '../theme/gabay_theme.dart';
import '../widgets/gabay_logo.dart';
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
        profileComplete: (result.user.name?.trim().isNotEmpty == true) &&
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
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF082A67),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF143E87), Color(0xFF082A67)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: size.height * .66,
              decoration: BoxDecoration(
                color: g.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(28, 70, 28, 32 + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: g.heading,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue your journey with GABAY.',
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: g.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: g.chipBackground,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: g.border),
                        ),
                        child: TextFormField(
                          controller: emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          style: TextStyle(color: g.textPrimary),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: '@gmail.com',
                            hintStyle: TextStyle(color: g.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            errorStyle: TextStyle(
                              color: g.danger,
                              height: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: g.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: g.chipBackground,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: g.border),
                        ),
                        child: TextFormField(
                          controller: passwordController,
                          enabled: !isLoading,
                          obscureText: obscurePassword,
                          validator: _validatePassword,
                          style: TextStyle(color: g.textPrimary),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: 'Enter your password',
                            hintStyle: TextStyle(color: g.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            errorStyle: TextStyle(
                              color: g.danger,
                              height: 0.8,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: g.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Transform.scale(
                            scale: 0.9,
                            child: Checkbox(
                              value: rememberMe,
                              activeColor: g.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        rememberMe = value ?? false;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Remember me',
                            style: TextStyle(
                              color: g.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: g.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF1EA4FF), Color(0xFF0057B8)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: g.accent.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: TextStyle(
                                  color: g.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const SignupPage(),
                                          ),
                                        );
                                      },
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    color: g.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * .29,
            left: 0,
            right: 0,
            child: Center(
              child: Hero(
                tag: 'gabay_logo',
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: g.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GabayLogo(size: 50, color: g.accent),
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
