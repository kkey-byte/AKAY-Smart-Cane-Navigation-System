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
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? g.surface : const Color(0xFFF3F3F3);
    final headingColor = isDark ? g.heading : const Color(0xFF103B7D);
    final mutedColor = isDark ? g.textSecondary : const Color(0xFFA3A3A3);

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
                colors: [Color(0xFF104694), Color(0xFF021D43)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                tooltip: 'Back',
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
              height: size.height * .65,
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 64, 24, 32 + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue your journey with GABAY.',
                        style: TextStyle(color: mutedColor, fontSize: 13),
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        style: TextStyle(color: g.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? g.chipBackground : Colors.white,
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          labelStyle: TextStyle(
                            color: headingColor,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: isDark
                                  ? g.border
                                  : const Color(0xFFDAD7D7),
                            ),
                          ),
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          labelText: 'Email',
                          hintText: '@gmail.com',
                          hintStyle: TextStyle(color: mutedColor),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          errorStyle: TextStyle(color: g.danger, height: 0.8),
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: passwordController,
                        enabled: !isLoading,
                        obscureText: obscurePassword,
                        validator: _validatePassword,
                        style: TextStyle(color: g.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? g.chipBackground : Colors.white,
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          labelStyle: TextStyle(
                            color: headingColor,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: isDark
                                  ? g.border
                                  : const Color(0xFFDAD7D7),
                            ),
                          ),
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(color: mutedColor),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          errorStyle: TextStyle(color: g.danger, height: 0.8),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: mutedColor,
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
                              activeColor: headingColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(1),
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
                            style: TextStyle(color: mutedColor, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
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
                        height: 54,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF008FE5), Color(0xFF004878)],
                            ),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 36),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: TextStyle(
                                  color: mutedColor,
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
                                    color: headingColor,
                                    fontWeight: FontWeight.w700,
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
            top: size.height * .35 - 36,
            left: 0,
            right: 0,
            child: Center(
              child: Hero(
                tag: 'gabay_logo',
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBDE2FA),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: const GabayLogo(size: 60, color: Color(0xFF008DE0)),
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
