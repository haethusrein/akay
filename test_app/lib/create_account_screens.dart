import 'dart:math' show min;
import 'akay_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// main.dart gives us the colors (kGreen, kBackground, ...) and HomeScreen.
import 'main.dart';

// ============================================================
// AKAY - Create account flow (front end only, no backend yet)
//
// Screen order:
//   1. WelcomeScreen          "Create an account" / "I already have an account"
//   2. CreateAccountScreen    pick Resident or Respondent + mobile + password
//   3. HouseholdSetupScreen   (Residents only) household profile, step 2 of 3
//   4. VerifyCodeScreen       6-digit one-time code, then opens HomeScreen
//
// Everything here is fake data for now. Search for "TODO" to find the
// places where the backend (Firebase) will be connected later.
// ============================================================

// ---------- Extra colors used only by these screens ----------
const kAmber = Color(0xFFF4C152);
const kHeaderTop = Color(0xFF2B6150);
const kHeaderBottom = Color(0xFF113B31);
const kFieldFill = Color(0xFFF8FAF9);
const kFieldBorder = Color(0xFFE0E7E4);
const kHintGrey = Color(0xFF9AA7A2);

// The two kinds of accounts.
enum UserRole { resident, respondent }

// Shows a small message at the bottom of the screen. Used for buttons
// whose screens or backend are not built yet.
void showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// ============================================================
// Screen 1: Welcome
// ============================================================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WELCOME TO AKAY', style: kSmallLabel),
          const SizedBox(height: 10),
          const Text(
            'Emergency help starts with a prepared community.',
            style: kAuthTitle,
          ),
          const SizedBox(height: 10),
          const Text(
            'Create your account before an emergency so responders know your location and needs.',
            style: TextStyle(fontSize: 14, color: kTextGrey, height: 1.45),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Create an account',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                // TODO: open the sign in screen (not designed yet)
                showComingSoon(context, 'Sign in screen is coming soon.');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                side: const BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'I already have an account',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                // TODO: open the phone dialer
                showComingSoon(context, 'Calling the hotline comes later.');
              },
              icon: const Icon(Icons.phone_outlined, size: 18),
              label: const Text(
                'Call emergency hotline',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: kRed),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Screen 2: Create account (choose role + mobile + password)
// ============================================================
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.resident;
  bool _hidePassword = true;

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
    if (value.length < 6) return 'Use at least 6 characters';
    return null;
  }

    Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await AkayBackend.signUp(
        mobile: _mobileController.text,
        password: _passwordController.text,
        role: _role,
      );
      if (!mounted) return;
      final Widget next = _role == UserRole.resident
          ? const HouseholdSetupScreen()
          : const VerifyCodeScreen();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
    } catch (e) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackLink(),
            const SizedBox(height: 12),
            const Text('CREATE YOUR ACCOUNT', style: kSmallLabel),
            const SizedBox(height: 10),
            const Text('How will you use AKAY?', style: kAuthTitle),
            const SizedBox(height: 8),
            const Text(
              'Your role determines the information and tools available to you.',
              style: TextStyle(fontSize: 14, color: kTextGrey, height: 1.45),
            ),
            const SizedBox(height: 18),
            RoleOption(
              icon: Icons.home_outlined,
              title: 'Resident',
              subtitle: 'Request help for my household',
              selected: _role == UserRole.resident,
              onTap: () => setState(() => _role = UserRole.resident),
            ),
            const SizedBox(height: 10),
            RoleOption(
              icon: Icons.people_outline,
              title: 'Respondent',
              subtitle: 'Help households in my community',
              selected: _role == UserRole.respondent,
              onTap: () => setState(() => _role = UserRole.respondent),
            ),
            const SizedBox(height: 18),
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
              onFieldSubmitted: (_) => _continue(),
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
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Continue', onPressed: _continue),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Screen 3: Household profile (Residents only, step 2 of 3)
// ============================================================
class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  // TODO: replace this sample list with the real barangays of Valencia City.
  static const _barangays = [
    'Barangay Bagontaas',
    'Barangay Batangan',
    'Barangay Colonia',
    'Barangay Lumbo',
    'Barangay Mailag',
    'Barangay Poblacion',
  ];

  static const _needs = [
    'None',
    'Wheelchair required',
    'Bedridden',
    'Oxygen tank',
    'Needs carrying / stretcher',
    'Infant or young child',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  String? _barangay; // null until the user picks one
  int _members = 1;
  String _need = 'None';
  bool _pinned = false;
  bool _submitted = false; // true after the user taps Save once

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    final formOk = _formKey.currentState!.validate();
    setState(() => _submitted = true);
    if (!formOk || !_pinned || _barangay == null) return;

    // TODO: later, save the household profile to Firebase here.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerifyCodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackLink(),
            const SizedBox(height: 12),
            const Text('RESIDENT SETUP · STEP 2 OF 3', style: kSmallLabel),
            const SizedBox(height: 10),
            const Text('Create your household profile', style: kAuthTitle),
            const SizedBox(height: 8),
            const Text(
              'This information helps responders arrive with the right equipment.',
              style: TextStyle(fontSize: 14, color: kTextGrey, height: 1.45),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Household name'),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a household name'
                  : null,
              decoration: fieldDecoration('e.g. Santos Household'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Barangay'),
            PickerField(
              value: _barangay,
              placeholder: 'Select your barangay',
              hasError: _submitted && _barangay == null,
              onTap: () async {
                final picked = await showOptionSheet(
                  context,
                  title: 'Barangay',
                  options: _barangays,
                  selected: _barangay,
                );
                if (picked != null) setState(() => _barangay = picked);
              },
            ),
            if (_submitted && _barangay == null)
              const FieldError('Select your barangay'),
            const SizedBox(height: 16),
            const FieldLabel('Complete address'),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your address'
                  : null,
              decoration: fieldDecoration(
                'Purok, street, house number, or landmark',
              ),
            ),
            const SizedBox(height: 12),
            PinLocationTile(
              pinned: _pinned,
              // TODO: later, use the phone's GPS or a map to pick the location.
              onTap: () => setState(() => _pinned = !_pinned),
            ),
            if (_submitted && !_pinned)
              const FieldError('Pin your exact home location'),
            const SizedBox(height: 16),
            const FieldLabel('Household members'),
            PickerField(
              value: _members == 1 ? '1 member' : '$_members members',
              placeholder: '',
              onTap: () async {
                final options = List.generate(
                  10,
                  (i) => i == 0 ? '1 member' : '${i + 1} members',
                );
                final picked = await showOptionSheet(
                  context,
                  title: 'Household members',
                  options: options,
                  selected: _members == 1 ? '1 member' : '$_members members',
                );
                if (picked != null) {
                  setState(() => _members = options.indexOf(picked) + 1);
                }
              },
            ),
            const SizedBox(height: 16),
            const FieldLabel('Mobility or equipment needs'),
            PickerField(
              value: _need,
              placeholder: '',
              onTap: () async {
                final picked = await showOptionSheet(
                  context,
                  title: 'Mobility or equipment needs',
                  options: _needs,
                  selected: _need,
                );
                if (picked != null) setState(() => _need = picked);
              },
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Save and verify household', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Screen 4: One-time code (identity verification)
// ============================================================
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const _codeLength = 6;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild the screen whenever the user types or the focus changes.
    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _complete => _controller.text.length == _codeLength;

  void _verify() {
    // TODO: later, check the code with the backend / registry here.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false, // remove all earlier screens so Back won't return here
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    final activeIndex = min(code.length, _codeLength - 1);

    return AuthScaffold(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kLightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_outlined, color: kGreen, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('IDENTITY VERIFICATION', style: kSmallLabel),
          const SizedBox(height: 10),
          const Text(
            'Enter the one-time code',
            textAlign: TextAlign.center,
            style: kAuthTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'We sent a 6-digit code to your registered mobile number.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: kTextGrey, height: 1.45),
          ),
          const SizedBox(height: 22),

          // The six boxes are only for show. One invisible TextField on top
          // receives the typing, and each box displays one of its digits.
          Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_codeLength, (i) {
                  return CodeBox(
                    digit: i < code.length ? code[i] : '',
                    active: _focusNode.hasFocus && i == activeIndex,
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: _codeLength,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (_) {
                      if (_complete) FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Green "Registry match found" box appears once all 6 digits are in.
          if (_complete) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kLightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: kGreen),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registry match found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kGreen,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your account will receive a verified badge.',
                          style: kGreyText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // The button stays grey until the code is complete.
          PrimaryButton(
            label: 'Verify and open home',
            onPressed: _complete ? _verify : null,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Shared building blocks for the create account screens
// ============================================================

const kAuthTitle = TextStyle(
  fontSize: 25,
  height: 1.2,
  fontWeight: FontWeight.w500,
  color: kTextDark,
);

// The page layout every screen shares: green header on top,
// then a white card with the screen's content.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: kBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The dark green banner: logo, tagline and "Sa oras ng sakuna...".
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Add the status bar height so text doesn't sit under the clock.
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        36,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [kHeaderTop, kHeaderBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6B59),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: kAmber,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AKAY',
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Community response',
                    style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),
          const Text(
            'GUIDED HELP WHEN IT MATTERS MOST',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: kAmber,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sa oras ng sakuna, may\naakay sa iyo.',
            style: TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connect vulnerable households with verified community responders during floods and emergencies.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xCCFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

// The big green button. Pass onPressed: null to make it grey (disabled).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x400F5C4D),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFB9CFC8),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// "<- Back" at the top of the card.
class BackLink extends StatelessWidget {
  const BackLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).maybePop(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 14, color: kTextGrey),
              SizedBox(width: 6),
              Text(
                'Back',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small bold label above a text field.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3F4F49),
        ),
      ),
    );
  }
}

// Small red error message under a custom field.
class FieldError extends StatelessWidget {
  final String text;
  const FieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, color: kRed)),
    );
  }
}

// The look of every text box (grey fill, rounded, green when focused).
InputDecoration fieldDecoration(String hint, {Widget? suffix}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kHintGrey, fontSize: 15),
    filled: true,
    fillColor: kFieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    suffixIcon: suffix,
    border: border(kFieldBorder),
    enabledBorder: border(kFieldBorder),
    focusedBorder: border(kGreen, 1.5),
    errorBorder: border(kRed),
    focusedErrorBorder: border(kRed, 1.5),
  );
}

// One of the two "Resident" / "Respondent" cards.
class RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const RoleOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF5EF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kGreen : kBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              IconBox(icon: icon, bg: kLightGreen, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: kGreyText),
                  ],
                ),
              ),
              // The round "radio" mark on the right.
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? kGreen : const Color(0xFFC9D3CF),
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: kGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Looks like a text box, but tapping it opens a list to choose from.
class PickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final bool hasError;
  final VoidCallback onTap;

  const PickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: kFieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasError ? kRed : kFieldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                  color: value == null ? kHintGrey : kTextDark,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: kHintGrey),
          ],
        ),
      ),
    );
  }
}

// Opens a bottom sheet with a list of options and returns the chosen one
// (or null if the user closes it).
Future<String?> showOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        title: Text(option),
                        trailing: option == selected
                            ? const Icon(Icons.check, color: kGreen)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(option),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// The dashed green "Pin exact home location" box.
class PinLocationTile extends StatelessWidget {
  final bool pinned;
  final VoidCallback onTap;

  const PinLocationTile({super.key, required this.pinned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: pinned ? kGreen : const Color(0xFF7DB8A3),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5EF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                pinned ? Icons.check_circle : Icons.location_on_outlined,
                color: kGreen,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pinned ? 'Home location pinned' : 'Pin exact home location',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pinned
                          ? 'Sample location saved (tap to remove)'
                          : 'Use GPS or choose on map',
                      style: kGreyText,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kTextGrey),
            ],
          ),
        ),
      ),
    );
  }
}

// Flutter has no built-in dashed border, so we draw one ourselves.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  const DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(14),
        ),
      );

    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// One box of the 6-digit code.
class CodeBox extends StatelessWidget {
  final String digit;
  final bool active;

  const CodeBox({super.key, required this.digit, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? kGreen
              : (digit.isEmpty ? kFieldBorder : const Color(0xFFB9D5C8)),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: kTextDark,
        ),
      ),
    );
  }
}
