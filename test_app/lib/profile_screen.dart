import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // needed for Clipboard (the Copy button)
import 'main.dart'; // colors
import 'shared_widgets.dart'; // AkayHeader and ConnectedBanner

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Temporary message until the real screens for these buttons exist.
  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what - coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkayHeader(),
              const SizedBox(height: 14),
              const ConnectedBanner(),
              const SizedBox(height: 22),

              // ----- Title row: text on the left, button on the right -----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOUSEHOLD SETTINGS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: kGreen,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Profile',
                          style: TextStyle(fontSize: 32, color: kTextDark),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Review the details responders use to find and help your household.',
                          style: TextStyle(fontSize: 13, color: kTextGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _comingSoon(context, 'Edit profile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ----- Main profile card -----
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top part: avatar, name, Verified badge
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC98A5E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'MS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Maria Santos',
                                style: TextStyle(
                                    fontSize: 16, color: kTextDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Household owner - Santos Household',
                                style: TextStyle(
                                    fontSize: 12, color: kTextGrey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: kLightGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 14, color: kGreen),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // The grey "field" boxes
                    const _FieldBox(
                        label: 'Mobile number', value: '+63 912 345 6789'),
                    const _FieldBox(
                        label: 'Home address',
                        value: 'Purok 4, Barangay Lumbo'),
                    const _FieldBox(
                        label: 'Emergency contact',
                        value: 'Juan Santos - +63 998 765 4321'),
                    // The invite code has a Copy button, so it is built here.
                    _CopyFieldBox(
                      label: 'Household invite code',
                      value: 'AKAY-3847',
                      onCopy: () {
                        // Clipboard.setData puts text into the clipboard.
                        Clipboard.setData(
                            const ClipboardData(text: 'AKAY-3847'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ----- Mobility needs card -----
              _Card(
                child: _SectionCard(
                  label: 'MOBILITY NEEDS',
                  title: 'Wheelchair required',
                  body:
                      'This information helps responders prepare the right equipment.',
                  buttonText: 'Update needs',
                  onPressed: () => _comingSoon(context, 'Update needs'),
                ),
              ),
              const SizedBox(height: 12),

              // ----- Preparedness card -----
              _Card(
                child: _SectionCard(
                  label: 'PREPAREDNESS',
                  title: 'Emergency profile ready',
                  body: 'Your household information is complete.',
                  buttonText: 'Review checklist',
                  onPressed: () => _comingSoon(context, 'Checklist'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// A white rounded card. It wraps whatever "child" we give it.
// Writing this once means every card in the app looks the same.
// ---------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------
// A small label on top and a grey rounded box with the value inside.
// ---------------------------------------------------------------
class _FieldBox extends StatelessWidget {
  final String label;
  final String value;
  const _FieldBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: kTextGrey)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kBackground,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: kTextDark)),
          ),
        ],
      ),
    );
  }
}

// Same as _FieldBox, but with a "Copy" button on the right.
class _CopyFieldBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _CopyFieldBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: kTextGrey)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: kBackground,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(value,
                    style:
                        const TextStyle(fontSize: 14, color: kTextDark)),
              ),
              TextButton(
                onPressed: onCopy,
                child: const Text('Copy',
                    style: TextStyle(
                        color: kGreen, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// Label, title, text and a green button. Used twice above
// (Mobility needs and Preparedness) with different words.
// ---------------------------------------------------------------
class _SectionCard extends StatelessWidget {
  final String label;
  final String title;
  final String body;
  final String buttonText;
  final VoidCallback onPressed;

  const _SectionCard({
    required this.label,
    required this.title,
    required this.body,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: kGreen,
          ),
        ),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(fontSize: 16, color: kTextDark)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 12, color: kTextGrey)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              backgroundColor: kLightGreen,
              foregroundColor: kGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(buttonText,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}