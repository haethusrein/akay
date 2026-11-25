import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../akay_backend.dart';
import '../main.dart'; // colors: kGreen, kRed, kBorder, ...

// ============================================================
// AKAY - Shared building blocks for the new screens
// (Sign in, Confirm request, Sync status, Track response, ...)
//
// Everything here is UI only. No backend calls.
// ============================================================

// While the backend is empty, show the Figma sample data so you can see the layout.
// Set to false before the final demo to show only real data.
const bool kShowSampleData = true;

/// Live in-app advisory shared by resident and responder screens.
class FloodAdvisoryBanner extends StatelessWidget {
  const FloodAdvisoryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AkayBackend.isSignedIn) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: AkayBackend.floodEmergency(),
      builder: (context, snapshot) {
        final advisory = snapshot.data;
        if (snapshot.hasError || advisory?['active'] != true) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7A16C)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF9A3F17)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (advisory?['title'] ?? 'Flood emergency').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF702D13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (advisory?['message'] ?? '').toString(),
                      style: const TextStyle(color: Color(0xFF702D13)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please check and update your evacuation status.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF702D13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Hotline ----------
const kHotlineNumber = '911';

/// Opens the phone's dialer with the hotline number filled in.
/// (The person still has to press the green call button.)
Future<void> callHotline(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(Uri(scheme: 'tel', path: kHotlineNumber));
    if (!ok) throw 'no dialer';
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open the dialer. Please call $kHotlineNumber.',
        ),
      ),
    );
  }
}

// ---------- Request types (same values AkayBackend.sendRequest expects) ----------
const kRequestTypes = ['flood', 'medical', 'fire', 'other'];

String requestTypeLabel(String type) {
  switch (type) {
    case 'flood':
      return 'Flood';
    case 'medical':
      return 'Medical emergency';
    case 'fire':
      return 'Fire';
    default:
      return 'Other emergency';
  }
}

IconData requestTypeIcon(String type) {
  switch (type) {
    case 'flood':
      return Icons.water_drop;
    case 'medical':
      return Icons.medical_services;
    case 'fire':
      return Icons.local_fire_department;
    default:
      return Icons.help_outline;
  }
}

// ---------- Page frame: back arrow + "AKAY" title, scrolling body ----------
class AkayScreen extends StatelessWidget {
  final Widget child;
  final bool showBack;
  final Widget? trailing;

  const AkayScreen({
    super.key,
    required this.child,
    this.showBack = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back, color: kTextDark),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'AKAY',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: trailing == null
                        ? null
                        : Center(child: trailing),
                  ), // balances the back button to keep the title centered
                ],
              ),
            ),
            const Divider(height: 1, color: kBorder),
            if (AkayBackend.isSignedIn) const FloodAdvisoryBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Big title block: small label + large title (+ optional subtitle) ----------
class ScreenTitle extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? trailing;
  const ScreenTitle({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack || trailing != null) ...[
          Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(Icons.arrow_back, color: kTextDark),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(label, style: kSmallLabel),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w500,
            color: kTextDark,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              color: kTextGrey,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------- Colored message box ----------
enum BannerTone { warning, success, danger }

class StatusBanner extends StatelessWidget {
  final BannerTone tone;
  final IconData icon;
  final String? title;
  final String message;

  const StatusBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg, border, fg;
    switch (tone) {
      case BannerTone.warning:
        bg = const Color(0xFFFDF3DC);
        border = const Color(0xFFF1DDA6);
        fg = const Color(0xFF7A5A12);
        break;
      case BannerTone.success:
        bg = kLightGreen;
        border = const Color(0xFFCFE5DA);
        fg = kGreen;
        break;
      case BannerTone.danger:
        bg = const Color(0xFFFDF1EE);
        border = const Color(0xFFF6DDD8);
        fg = kRed;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(fontSize: 13, height: 1.4, color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- One step in a progress list (Saved / Waiting / Confirmed ...) ----------
enum StepStatus { done, current, waiting }

class StepRow extends StatelessWidget {
  final int number;
  final String title;
  final String? caption;
  final StepStatus state;
  final bool isLast;

  const StepRow({
    super.key,
    required this.number,
    required this.title,
    required this.state,
    this.caption,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    // The status is shown with an icon AND text, never color alone.
    final Widget dot;
    switch (state) {
      case StepStatus.done:
        dot = const CircleAvatar(
          radius: 14,
          backgroundColor: kGreen,
          child: Icon(Icons.check, size: 16, color: Colors.white),
        );
        break;
      case StepStatus.current:
        dot = const CircleAvatar(
          radius: 14,
          backgroundColor: kAmberDot,
          child: Icon(Icons.circle, size: 10, color: Colors.white),
        );
        break;
      case StepStatus.waiting:
        dot = CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kTextGrey, width: 1.5),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTextGrey,
              ),
            ),
          ),
        );
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              dot,
              if (!isLast) Expanded(child: Container(width: 2, color: kBorder)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: state == StepStatus.waiting
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: state == StepStatus.waiting
                          ? kTextGrey
                          : kTextDark,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(caption!, style: kGreyText),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const kAmberDot = Color(0xFFE0A030);

// ---------- Buttons ----------

/// Solid colored button (use color: kRed for the dangerous main action).
class SolidAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const SolidAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = kGreen,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// White button with a border: the safe "secondary path".
class OutlineAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const OutlineAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kTextDark,
          backgroundColor: Colors.white,
          side: const BorderSide(color: kTextDark, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Plain underlined text link under the buttons.
class TextLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: kTextDark,
          minimumSize: const Size(48, 48),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// ---------- Label / value row with an optional action (Change, Edit) ----------
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String? actionText;
  final VoidCallback? onAction;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 124, child: Text(label, style: kGreyText)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                if (actionText != null)
                  InkWell(
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        actionText!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kGreen,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- "What's happening?" bottom sheet. Returns 'flood' | 'medical' | ... ----------
Future<String?> pickEmergencyType(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "What's happening?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          for (final t in kRequestTypes)
            ListTile(
              leading: Icon(requestTypeIcon(t)),
              title: Text(requestTypeLabel(t)),
              onTap: () => Navigator.pop(ctx, t),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ---------- Ask "are you sure?" before an important action ----------
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Keep it',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: kRed),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ---------- Small drawn map: "You" in the middle, optional red "!" pin ----------
class MiniMap extends StatelessWidget {
  final bool showPin;
  const MiniMap({super.key, this.showPin = true});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 170,
        width: double.infinity,
        color: const Color(0xFFE9EFEB),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 40,
              child: ColoredBox(color: Color(0xFFC6DBE3)),
            ),
            Align(
              alignment: const Alignment(-0.35, 0.45),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: kTextDark),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (showPin)
              const Align(
                alignment: Alignment(0.45, -0.35),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: kRed,
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
