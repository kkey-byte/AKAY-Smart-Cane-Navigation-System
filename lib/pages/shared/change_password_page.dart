import '../../theme/gabay_typography.dart';
import '../../widgets/shared/gabay_page_header.dart';
import '../../widgets/shared/gabay_page_background.dart';
import '../../widgets/shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../../services/auth_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _visible = [false, false, false];
  bool _saving = false;

  bool get _longEnough => _password.text.runes.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _hasSpecial => RegExp(r'[^a-zA-Z0-9\s]').hasMatch(_password.text);

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await (widget.authService ?? AuthService.instance).changePassword(
        currentPassword: _current.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      _current.clear();
      _password.clear();
      _confirm.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password update could not be confirmed. Please sign in again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final background = g.scaffoldBackground;
    final score = [
      _longEnough,
      _hasUppercase,
      _hasSpecial,
    ].where((met) => met).length;
    final strength = score == 3
        ? 'Strong password'
        : score == 2
        ? 'Fair password'
        : 'Weak password';
    return Scaffold(
      backgroundColor: background,

      body: GabayPageBackground(
        child: GabayScrollingPage(
          header: const GabayPageHeader(
            title: 'Change Password',
            showBack: false,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 40).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _field(
                                'Current Password',
                                'Enter your current password',
                                _current,
                                0,
                              ),
                              const SizedBox(height: 20),
                              _field(
                                'New Password',
                                'Enter your new password',
                                _password,
                                1,
                              ),
                              const SizedBox(height: 20),
                              _field(
                                'Confirm Password',
                                'Type password again to confirm',
                                _confirm,
                                2,
                              ),
                              const SizedBox(height: 14),
                              Semantics(
                                label:
                                    '$strength. $score of 3 requirements met',
                                child: Row(
                                  children: List.generate(
                                    3,
                                    (index) => Expanded(
                                      child: Container(
                                        height: 5,
                                        margin: EdgeInsets.only(
                                          right: index == 2 ? 0 : 8,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: index < score
                                              ? (score == 3
                                                    ? g.success
                                                    : score == 2
                                                    ? g.warning
                                                    : g.danger)
                                              : g.border,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$strength. Must contain:',
                                style: TextStyle(color: g.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              _requirement(
                                'At least 8 characters',
                                _longEnough,
                              ),
                              _requirement(
                                'One uppercase letter',
                                _hasUppercase,
                              ),
                              _requirement(
                                'One special character',
                                _hasSpecial,
                              ),
                              const SizedBox(height: 24),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final buttons = [
                                    OutlinedButton(
                                      onPressed: _saving
                                          ? null
                                          : () => Navigator.maybePop(context),
                                      style:
                                          OutlinedButton.styleFrom(
                                            backgroundColor: g.chipBackground,
                                            foregroundColor: g.textPrimary,
                                            side: BorderSide(color: g.border),
                                            minimumSize: const Size.fromHeight(
                                              52,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ).copyWith(
                                            backgroundBuilder:
                                                (context, states, child) =>
                                                    child ??
                                                    const SizedBox.shrink(),
                                          ),
                                      child: const Text('Discard'),
                                    ),
                                    ElevatedButton(
                                      onPressed: _saving ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        minimumSize: const Size.fromHeight(52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            GabayMetrics.controlRadius,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Apply Changes'),
                                    ),
                                  ];
                                  if (constraints.maxWidth < 300 ||
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(16) >
                                          24) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        buttons[0],
                                        const SizedBox(height: 12),
                                        buttons[1],
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: buttons[0]),
                                      const SizedBox(width: 16),
                                      Expanded(child: buttons[1]),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _requirement(String text, bool met) {
    final g = context.gabay;
    return Semantics(
      label: '$text, ${met ? "met" : "not met"}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            GabayAccentIcon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: met ? g.success : g.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: GabayTypography.caption,
                  color: g.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String hint,
    TextEditingController controller,
    int index,
  ) {
    final g = context.gabay;
    final dark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: GabayTypography.cardBody,
                    fontWeight: GabayTypography.medium,
                  ),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: g.accent),
                    ),
                  ],
                ),
              ),
            ),
            if (index == 2)
              TextButton(
                onPressed: () => _confirm.clear(),
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            enabled: !_saving,
            controller: controller,
            obscureText: !_visible[index],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: index == 2
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: [
              index == 0 ? AutofillHints.password : AutofillHints.newPassword,
            ],
            style: TextStyle(
              color: g.textPrimary,
              fontSize: GabayTypography.body,
            ),
            onChanged: index == 1 ? (_) => setState(() {}) : null,
            onFieldSubmitted: index == 2 ? (_) => _submit() : null,
            validator: (value) {
              if (value == null || value.isEmpty) return '$label is required';
              if (index == 1 &&
                  !(_longEnough && _hasUppercase && _hasSpecial)) {
                return 'Meet all password requirements below';
              }
              if (index == 2 && value != _password.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            decoration: InputDecoration(
              // Labels are displayed above the input to match the card layout.
              hintText: hint,
              hintStyle: TextStyle(
                color: g.textSecondary,
                fontSize: GabayTypography.body,
              ),
              labelStyle: TextStyle(color: g.textSecondary),
              filled: true,
              fillColor: g.surface,
              border: border(g.border),
              enabledBorder: border(dark ? g.border : const Color(0xFFD8D8D8)),
              focusedBorder: border(g.accent),
              errorBorder: border(g.danger),
              focusedErrorBorder: border(g.danger),
              errorMaxLines: 3,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              suffixIcon: IconButton(
                tooltip:
                    '${_visible[index] ? "Hide" : "Show"} ${label.toLowerCase()}',
                onPressed: () =>
                    setState(() => _visible[index] = !_visible[index]),
                icon: GabayAccentIcon(
                  _visible[index]
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: g.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
