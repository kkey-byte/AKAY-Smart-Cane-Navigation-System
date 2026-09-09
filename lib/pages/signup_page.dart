import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../navigation/role_router.dart';
import '../services/app_session_service.dart';
import '../services/auth_service.dart';
import '../theme/gabay_theme.dart';
import '../widgets/signup_wave_clipper.dart';
import 'login_page.dart';

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
      final roleString =
          result.user.role.backendValue.isNotEmpty
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
                colors: [Color(0xFF15408E), Color(0xFF082A67)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: isLoading ? null : () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: SignupWaveClipper(),
              child: Container(
                height: size.height * .86,
                decoration: BoxDecoration(
                  color: g.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(70),
                    topRight: Radius.circular(70),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(28, 48, 28, 30 + bottomInset),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 35),
                        Text(
                          "Create Your Account",
                          style: TextStyle(
                            fontSize: 33,
                            fontWeight: FontWeight.w800,
                            color: g.heading,
                          ),
                        ),
                        Text(
                          "Create an account to unlock safer and more connected mobility.",
                          style: TextStyle(
                            color: g.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            "Email",
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
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
                              hintText: "@gmail.com",
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
                            "Password",
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
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
                              hintText: "Enter your password",
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
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: g.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            "Confirm Password",
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          decoration: BoxDecoration(
                            color: g.chipBackground,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: g.border),
                          ),
                          child: TextFormField(
                            controller: confirmPasswordController,
                            enabled: !isLoading,
                            obscureText: obscureConfirmPassword,
                            validator: _validateConfirmPassword,
                            style: TextStyle(color: g.textPrimary),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              hintText: "Enter again to confirm password",
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
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: g.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscureConfirmPassword =
                                        !obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            "Role",
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: g.chipBackground,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: g.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserRole>(
                              value: selectedRole,
                              isExpanded: true,
                              dropdownColor: g.surface,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: g.textPrimary,
                              ),
                              style: TextStyle(
                                color: g.textPrimary,
                                fontSize: 15,
                              ),
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() => selectedRole = value);
                                    },
                              items: const [
                                DropdownMenuItem(
                                  value: UserRole.caregiver,
                                  child: Text("Caregiver"),
                                ),
                                DropdownMenuItem(
                                  value: UserRole.navigator,
                                  child: Text("Navigator (Visually Impaired)"),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Transform.scale(
                              scale: .9,
                              child: Checkbox(
                                value: agree,
                                activeColor: g.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: isLoading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          agree = value ?? false;
                                        });
                                      },
                              ),
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: g.textSecondary,
                                    fontSize: 12,
                                  ),
                                  children: [
                                    const TextSpan(text: "Agree with "),
                                    TextSpan(
                                      text: "Terms & Conditions",
                                      style: TextStyle(
                                        color: g.accent,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: agree
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF1EA4FF),
                                        Color(0xFF0057B8),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [g.border, g.textSecondary],
                                    ),
                              boxShadow: agree
                                  ? [
                                      BoxShadow(
                                        color: g.accent.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ElevatedButton(
                              onPressed: agree && !isLoading
                                  ? _handleSignUp
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
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
                                      "Create Account",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Already have an account? ",
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
                                              builder: (_) => const LoginPage(),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    "Login",
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
                        const SizedBox(height: 20),
                      ],
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
