import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // fieldDecoration, FieldLabel, showComingSoon
import '../main.dart'; // colors + HomeScreen
import 'emergency_info_screen.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Sign in (wireframe 01 "Log in")
//
// Backend used: AkayBackend.signIn(mobile:, password:)
// ============================================================
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;
  String? _loginError; // shown under the form when sign in fails

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Accepts 09123456789, +63 912 345 6789, or 9123456789.
  String? _validateMobile(String? value) {
    var digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10 || !digits.startsWith('9')) {
      return 'Enter a valid mobile number, e.g. +63 912 345 6789';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _signIn() async {
    setState(() => _loginError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AkayBackend.signIn(
        mobile: _mobileController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // TODO: if the account is a respondent, open the responder screens instead.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loginError = AkayBackend.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle(
              label: 'RESIDENT OR RESPONDER ACCESS',
              title: 'Log in to AKAY',
              subtitle: 'Use the mobile number linked to your account.',
            ),
            const SizedBox(height: 24),
            const FieldLabel('Mobile number'),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _validateMobile,
              decoration: fieldDecoration('+63 9XX XXX XXXX'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _signIn(),
              decoration: fieldDecoration(
                'Enter your password',
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: kHintGrey,
                  ),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),

            // Error from the backend, with a clear way to recover.
            if (_loginError != null) ...[
              const SizedBox(height: 16),
              StatusBanner(
                tone: BannerTone.danger,
                icon: Icons.error_outline,
                message: _loginError!,
              ),
            ],

            const SizedBox(height: 22),
            SolidAction(
              label: _loginError == null ? 'Log in' : 'Try logging in again',
              loading: _loading,
              onPressed: _signIn,
            ),
            TextLinkButton(
              label: 'Forgot password?',
              // TODO(backend): password reset is not available yet.
              onPressed: () =>
                  showComingSoon(context, 'Password reset is coming soon.'),
            ),

            const SizedBox(height: 8),
            const StatusBanner(
              tone: BannerTone.success,
              icon: Icons.wifi_off,
              message:
                  'No signal? Emergency information saved on this phone stays available.',
            ),
            const SizedBox(height: 12),
            OutlineAction(
              label: 'Open offline information',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmergencyInfoScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
