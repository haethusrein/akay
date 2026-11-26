import 'package:flutter/material.dart';
import 'main.dart'; // colors

// The top bar from the wireframe: back arrow, "AKAY" in the middle,
// and three dots on the right.
class AkayBackHeader extends StatelessWidget {
  const AkayBackHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // InkWell makes the arrow tappable.
        InkWell(
          // Navigator.maybePop = "go back to the previous screen".
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: kTextDark),
          ),
        ),
        // Expanded + Center keeps the title in the middle of the bar.
        const Expanded(
          child: Center(
            child: Text(
              'AKAY',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                color: kTextDark,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.more_horiz, color: kTextDark),
        ),
      ],
    );
  }
}

// A colored strip with an icon and a line of text.
// Used for "FLOOD ALERT", "OFFLINE COPY", "CRITICAL - FLOOD" and
// the offline warning. Only the colors and words change.
class AlertBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg; // background color
  final Color border; // outline color
  final Color fg; // text and icon color
  final bool caps; // true = small bold letters (a "label" look)

  const AlertBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.bg,
    required this.border,
    required this.fg,
    this.caps = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: caps ? 12 : 13,
                fontWeight: caps ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: caps ? 1 : 0,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The big green button (the one main action on a screen).
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// The white button with a dark outline (the secondary action).
class OutlineActionButton extends StatelessWidget {
  final String text;
  final IconData? icon; // optional icon before the text
  final VoidCallback onPressed;

  const OutlineActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kTextDark,
          side: const BorderSide(color: kTextDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}