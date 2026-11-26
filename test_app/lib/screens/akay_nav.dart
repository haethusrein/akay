import 'package:flutter/material.dart';
import 'dart:async';
import '../internet_probe.dart';
import '../akay_backend.dart';
import '../create_account_screens.dart'; // kAmber, showComingSoon
import '../main.dart'; // colors, HomeScreen
import 'community_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Navigation pieces shared by Home, Community, Requests, Profile
//   AkayTopBar        logo + bell (Notifications panel) + menu (Menu panel)
//   AkayBottomNav     Home / Community / Requests / Profile
//   TabScaffold       the page frame the tab screens use
//   ConnectedBanner   green "Connected" strip
// ============================================================

/// Switch tab. 0 = Home, 1 = Community, 2 = Requests, 3 = Profile.
void goToTab(BuildContext context, int index) {
  final pages = <Widget>[
    const HomeScreen(),
    const CommunityScreen(),
    const RequestsScreen(),
    const ProfileScreen(),
  ];
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, a, b) => pages[index],
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
    (route) => false,
  );
}

// ---------- Bottom navigation ----------
class AkayBottomNav extends StatelessWidget {
  final int selectedIndex;
  const AkayBottomNav({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      backgroundColor: Colors.white,
      indicatorColor: kLightGreen,
      onDestinationSelected: (i) {
        if (i != selectedIndex) goToTab(context, i);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: kGreen),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: kGreen),
          label: 'Community',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history, color: kGreen),
          label: 'Requests',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: kGreen),
          label: 'Profile',
        ),
      ],
    );
  }
}

// ---------- Page frame for the tab screens ----------
class TabScaffold extends StatelessWidget {
  final int index;
  final Widget child;
  const TabScaffold({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkayTopBar(),
              const SizedBox(height: 16),
              const FloodAdvisoryBanner(),
              const ConnectedBanner(),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
      bottomNavigationBar: AkayBottomNav(selectedIndex: index),
    );
  }
}

// ---------- Green "Connected" strip ----------
class ConnectedBanner extends StatefulWidget {
  const ConnectedBanner({super.key});

  @override
  State<ConnectedBanner> createState() => _ConnectedBannerState();
}

class _ConnectedBannerState extends State<ConnectedBanner>
    with WidgetsBindingObserver {
  bool? _online;
  bool _checking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_checking) return;
    _checking = true;

    try {
      final result = await hasInternetAccess();
      if (mounted && result != _online) {
        setState(() => _online = result);
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checking = _online == null;
    final connected = _online == true;
    final color = checking ? kTextGrey : (connected ? kGreen : kRed);
    final background = checking
        ? const Color(0xFFF1F3F2)
        : (connected ? kLightGreen : const Color(0xFFFDE9E5));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? const Color(0xFFCFE5DA)
              : color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            checking
                ? 'Checking connection'
                : (connected ? 'Connected' : 'No internet'),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              checking
                  ? 'Checking internet access'
                  : (connected
                      ? 'Emergency network active'
                      : 'Some features may not sync'),
              style: kGreyText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Small pill button (e.g. "New help request", "Find my location") ----------
class PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = kGreen,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ---------- Top bar: logo, name, bell, menu ----------
class AkayTopBar extends StatelessWidget {
  const AkayTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: kAmber, size: 30),
        ),
        const SizedBox(width: 10),
        const Text(
          'AKAY',
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const Spacer(),
        StreamBuilder<int>(
          stream: AkayBackend.isSignedIn
              ? AkayBackend.unreadCount()
              : Stream<int>.value(0),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? (kShowSampleData ? 1 : 0);
            return _SquareButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              showDot: unread > 0,
              onTap: () => showNotificationsPanel(context),
            );
          },
        ),
        const SizedBox(width: 8),
        _SquareButton(
          icon: Icons.menu,
          tooltip: 'Menu',
          onTap: () => showMenuPanel(context),
        ),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Icon(icon, color: kTextDark, size: 22),
            ),
            if (showDot)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Side panels (Figma: Notifications, Menu)
// ============================================================
Future<void> _showSidePanel(
  BuildContext context, {
  required String label,
  required String title,
  required Widget Function(BuildContext panelContext) body,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a, b) {
      final width = MediaQuery.of(ctx).size.width;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: kBackground,
          child: SizedBox(
            width: width < 420 ? width * 0.88 : 372,
            height: double.infinity,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: kSmallLabel),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                style: const TextStyle(fontSize: 26, color: kTextDark),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE8EDEA),
                          ),
                          icon: const Icon(Icons.close, size: 18, color: kTextGrey),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 16),
                    Expanded(child: body(ctx)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}

// One white row with an icon, two lines of text and a chevron.
class _PanelTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool unread;
  final VoidCallback onTap;

  const _PanelTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBg = kLightGreen,
    this.iconColor = kGreen,
    this.unread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                IconBox(icon: icon, bg: iconBg, color: iconColor, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: kGreyText),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: kTextDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Menu panel ----------
Future<void> showMenuPanel(BuildContext context) {
  const items = [
    (Icons.home_outlined, 'Home', 'Open home'),
    (Icons.map_outlined, 'Community', 'Open community'),
    (Icons.history, 'Requests', 'Open requests'),
    (Icons.person_outline, 'Profile', 'Open profile'),
  ];
  return _showSidePanel(
    context,
    label: 'NAVIGATE',
    title: 'Menu',
    body: (panelContext) => ListView(
      children: [
        for (var i = 0; i < items.length; i++)
          _PanelTile(
            icon: items[i].$1,
            title: items[i].$2,
            subtitle: items[i].$3,
            onTap: () {
              Navigator.of(panelContext).pop();
              goToTab(context, i);
            },
          ),
      ],
    ),
  );
}

// ---------- Notifications panel ----------
String _timeAgo(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return 'Updated ${d.inMinutes} minutes ago';
  if (d.inHours < 24) return 'Updated ${d.inHours} hours ago';
  return 'Updated ${d.inDays} days ago';
}

Future<void> showNotificationsPanel(BuildContext context) {
  return _showSidePanel(
    context,
    label: 'RECENT ACTIVITY',
    title: 'Notifications',
    body: (panelContext) => StreamBuilder(
      stream: AkayBackend.notifications(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Figma sample items, so the layout is visible before the backend has data.
          if (kShowSampleData) {
            return ListView(
              children: [
                _PanelTile(
                  icon: Icons.warning_amber_rounded,
                  iconBg: const Color(0xFFFFF3DC),
                  iconColor: const Color(0xFFE0A030),
                  title: 'Flood advisory Level 2',
                  subtitle: 'Updated 8 minutes ago',
                  onTap: () {},
                ),
                _PanelTile(
                  icon: Icons.alt_route,
                  iconBg: const Color(0xFFE8F1FB),
                  iconColor: const Color(0xFF3B82C4),
                  title: 'Evacuation route clear',
                  subtitle: 'Updated 24 minutes ago',
                  onTap: () {},
                ),
                _PanelTile(
                  icon: Icons.shield_outlined,
                  title: 'Profile verified',
                  subtitle: 'Your household is response-ready',
                  onTap: () {},
                ),
              ],
            );
          }
          return const Center(
            child: Text('No notifications yet.', style: kGreyText),
          );
        }

        return ListView(
          children: [
            for (final d in docs)
              Builder(builder: (context) {
                final data = d.data();
                final type = (data['type'] ?? '').toString();
                final isRead = data['isRead'] == true;
                final created = data['createdAt'];
                String subtitle = (data['body'] ?? '').toString();
                if (subtitle.isEmpty && created != null) {
                  try {
                    subtitle = _timeAgo(created.toDate());
                  } catch (_) {}
                }
                final cancelled = type.contains('cancel');
                return _PanelTile(
                  icon: cancelled
                      ? Icons.warning_amber_rounded
                      : Icons.shield_outlined,
                  iconBg: cancelled ? const Color(0xFFFFF3DC) : kLightGreen,
                  iconColor: cancelled ? const Color(0xFFE0A030) : kGreen,
                  title: (data['title'] ?? 'Notification').toString(),
                  subtitle: subtitle,
                  unread: !isRead,
                  onTap: () {
                    if (!isRead) AkayBackend.markRead(d.id);
                  },
                );
              }),
          ],
        );
      },
    ),
  );
}
