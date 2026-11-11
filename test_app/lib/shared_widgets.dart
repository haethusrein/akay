import 'package:flutter/material.dart';
import 'main.dart'; // for the colors: kGreen, kLightGreen, kBorder ...

// The top bar: logo, "AKAY", bell and menu icons.
// StatelessWidget = a widget that just draws itself and never changes.
class AkayHeader extends StatelessWidget {
  final VoidCallback? onBellTap; // optional: what happens when bell is tapped
  final VoidCallback? onMenuTap; // optional: what happens when menu is tapped

  const AkayHeader({super.key, this.onBellTap, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    // Row = place children side by side, left to right.
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12), // SizedBox = empty space
        const Text(
          'AKAY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: kTextDark,
          ),
        ),
        const Spacer(), // pushes everything after it to the far right
        _HeaderIconButton(icon: Icons.notifications_none, onTap: onBellTap),
        const SizedBox(width: 8),
        _HeaderIconButton(icon: Icons.menu, onTap: onMenuTap),
      ],
    );
  }
}

// A small white rounded square with an icon inside.
// The underscore at the start (_) means "private to this file".
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    // InkWell makes anything tappable and adds the ripple effect.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: kTextDark),
      ),
    );
  }
}

// The green "Connected - Emergency network active" strip.
class ConnectedBanner extends StatelessWidget {
  const ConnectedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // take the full available width
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kLightGreen,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi, size: 16, color: kGreen),
          SizedBox(width: 8),
          Text(
            'Connected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kGreen,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Emergency network active',
            style: TextStyle(fontSize: 12, color: kTextGrey),
          ),
        ],
      ),
    );
  }
}