// admin tab for various back-end functions
// accessible only to one admin account (admin, 00000000)
// for verification, one-time pin generation, and logging exception errors
// view all user acounts and roles
// on new account creation, backend should generate a one-time pin and send it to the admin for verification
// the admin can 'accept' 911 calls (for demonstration)
// special one-time pin for demonstration purposes
// this screen is not intended for production use, but for demonstration and testing purposes only
//
// ------------------------------------------------------------
// How it works (Firebase Spark plan: no Cloud Functions)
//   * The admin account is created by hand in the Firebase console (see README / setup notes).
//     Its users/<uid> document has mobile == AkayBackend.adminMobile ('00000000').
//   * The check below is only cosmetic. The real protection is firestore.rules (isAdmin()).
//   * Pins are documents in verificationCodes/<6-digit pin>. They are one-time (used flips to true),
//     tied to a role, optionally tied to one account (forUid) and expire (30 min, demo pins 24 h).
//   * "On new account creation": there is no server to react to a sign-up, so this screen
//     watches the users collection and creates the pin itself while it is open
//     (switch on the Pins tab). If the screen was closed, use "Generate pin" on the account.
//   * 911 calls are the pending documents in `requests`. Accepting one reuses
//     AkayBackend.acceptRequest, with the admin acting as the responder.
//   * Exception errors are written to errorLogs by AkayBackend.logError and listed on the Error log tab.
// ------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../akay_backend.dart';
import '../main.dart'; // colors and text styles
import 'screen_widgets.dart'; // StatusBanner, confirmDialog, requestTypeLabel, requestTypeIcon

// ============================================================
// Small helpers
// ============================================================

DateTime? _dateOf(dynamic ts) => ts is Timestamp ? ts.toDate() : null;

String _ago(DateTime? d) {
  if (d == null) return 'just now';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

String _left(DateTime? d) {
  if (d == null) return '';
  final remaining = d.difference(DateTime.now());
  if (remaining.isNegative) return 'expired';
  if (remaining.inMinutes < 1) return 'less than 1 min left';
  if (remaining.inMinutes < 60) return '${remaining.inMinutes} min left';
  return '${remaining.inHours} h left';
}

String _roleLabel(Map<String, dynamic> user) {
  if (user['mobile'] == AkayBackend.adminMobile) return 'Admin';
  final role = user['role'];
  if (role == 'respondent') return 'Responder';
  if (role == 'resident') return 'Resident';
  return (role ?? 'Unknown').toString();
}

enum _PinState { active, used, expired }

_PinState _stateOf(Map<String, dynamic> pin) {
  if (pin['used'] == true) return _PinState.used;
  final expires = _dateOf(pin['expiresAt']);
  if (expires != null && expires.isBefore(DateTime.now())) {
    return _PinState.expired;
  }
  return _PinState.active;
}

bool _isAdminUser(Map<String, dynamic> user) =>
    user['mobile'] == AkayBackend.adminMobile;

/// An account that still needs a verification pin.
bool _isWaiting(Map<String, dynamic> user) =>
    !_isAdminUser(user) &&
    (user['role'] == 'resident' || user['role'] == 'respondent') &&
    user['verified'] != true;

Widget _loadError(Object e) {
  final denied = e is FirebaseException && e.code == 'permission-denied';
  return StatusBanner(
    tone: BannerTone.danger,
    icon: Icons.error_outline,
    title: 'Could not load',
    message: denied
        ? 'Not allowed. Deploy the latest firestore.rules '
              '(firebase deploy --only firestore:rules) and sign in as the admin account.'
        : AkayBackend.friendlyError(e),
  );
}

const _tabPadding = EdgeInsets.fromLTRB(20, 16, 20, 28);

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, {this.bg = kLightGreen, this.fg = kGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Widget child;
  const _AdminCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(text, style: kSmallLabel),
    );
  }
}

// ============================================================
// Gate: only the admin account sees the console
// ============================================================

class AdminOnlyScreen extends StatelessWidget {
  const AdminOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: StreamBuilder(
          stream: AkayBackend.myProfile(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Denied(
                message: AkayBackend.friendlyError(snapshot.error!),
              );
            }
            final p = snapshot.data?.data();
            if (p == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kGreen),
                );
              }
              return const _Denied();
            }
            if (!AkayBackend.isAdminProfile(p)) return const _Denied();
            return const _AdminConsole();
          },
        ),
      ),
    );
  }
}

class _Denied extends StatelessWidget {
  final String message;
  const _Denied({this.message = 'Access denied. Admin only.'});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: kTextDark),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(child: Center(child: Text(message))),
      ],
    );
  }
}

// ============================================================
// Console: Pins | Accounts | 911 calls | evacuation status | assignments | flood alert | Error log
// ============================================================

class _PinOptions {
  final String role;
  final String? custom;
  const _PinOptions(this.role, this.custom);
}

class _AdminConsole extends StatefulWidget {
  const _AdminConsole();

  @override
  State<_AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<_AdminConsole> {
  StreamSubscription<List<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<List<Map<String, dynamic>>>? _pinsSub;
  Timer? _tick;

  List<Map<String, dynamic>>? _users;
  List<Map<String, dynamic>>? _pins;
  Object? _usersError;
  Object? _pinsError;

  bool _autoPins = true;
  final Set<String> _issuing =
      {}; // accounts a pin is being created for right now
  final Set<String> _attempted =
      {}; // accounts the auto mode already tried this session

  // Auto mode only handles accounts created in the last hour, so old test accounts
  // do not all get pins the moment this screen opens.
  static const Duration _autoWindow = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _usersSub = AkayBackend.adminUsers().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _users = list;
          _usersError = null;
        });
        _maybeAutoIssue();
      },
      onError: (Object e) {
        if (mounted) setState(() => _usersError = e);
      },
    );
    _pinsSub = AkayBackend.adminPins().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _pins = list;
          _pinsError = null;
        });
        _maybeAutoIssue();
      },
      onError: (Object e) {
        if (mounted) setState(() => _pinsError = e);
      },
    );
    // Refresh "12 min left" / "expired" labels.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _pinsSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Copied');
  }

  List<Map<String, dynamic>> _pinsFor(String userId) =>
      (_pins ?? const <Map<String, dynamic>>[])
          .where((p) => p['forUid'] == userId)
          .toList();

  // ---------- pins ----------

  /// New account -> pin, with no tap needed (while this screen is open).
  void _maybeAutoIssue() {
    if (!_autoPins) return;
    final users = _users;
    final pins = _pins;
    if (users == null || pins == null) return;
    final cutoff = DateTime.now().subtract(_autoWindow);
    for (final u in users) {
      if (!_isWaiting(u)) continue;
      final id = u['id'] as String;
      if (_attempted.contains(id) || _issuing.contains(id)) continue;
      final created = _dateOf(u['createdAt']);
      if (created == null || created.isBefore(cutoff)) continue;
      if (_pinsFor(id).isNotEmpty) continue; // already has (or had) a pin
      _attempted.add(id);
      _issue(u, auto: true);
    }
  }

  Future<void> _issue(Map<String, dynamic> user, {bool auto = false}) async {
    final id = user['id'] as String;
    if (!_issuing.add(id)) return;
    if (mounted) setState(() {});
    try {
      // A new pin replaces any older pin of this account that nobody used.
      final old = _pinsFor(id)
          .where((p) => p['used'] != true)
          .map((p) => p['id'] as String)
          .toList();
      final pin = await AkayBackend.adminIssuePinForUser(
        user,
        replacePins: old,
      );
      _toast(
        auto
            ? 'New account ${user['mobile']}: pin $pin'
            : 'Pin $pin created for ${user['mobile']}',
      );
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    } finally {
      _issuing.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _generatePin({required bool demo}) async {
    final options = await showDialog<_PinOptions>(
      context: context,
      builder: (_) => _PinOptionsDialog(demo: demo),
    );
    if (options == null || !mounted) return;
    try {
      final pin = await AkayBackend.adminCreatePin(
        role: options.role,
        demo: demo,
        customPin: options.custom,
      );
      if (!mounted) return;
      final who = options.role == 'respondent' ? 'responder' : 'resident';
      final life = demo
          ? '${AkayBackend.demoPinLifetime.inHours} hours'
          : '${AkayBackend.pinLifetime.inMinutes} minutes';
      await _showPin(
        pin,
        '${demo ? 'Demo pin' : 'Pin'} for a $who. Works once and expires in $life.',
      );
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    }
  }

  Future<void> _showPin(String pin, String note) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('One-Time Pin Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              pin,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: kGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(note, style: kGreyText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: pin)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(String pin) async {
    final ok = await confirmDialog(
      context,
      title: 'Revoke pin $pin?',
      message: 'Nobody will be able to use it any more.',
      confirmLabel: 'Revoke',
      cancelLabel: 'Cancel',
    );
    if (!ok) return;
    try {
      await AkayBackend.adminRevokePin(pin);
      _toast('Pin revoked');
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    }
  }

  // ---------- layout ----------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: kTextDark),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6),
                      Text('ADMIN FUNCTIONS', style: kSmallLabel),
                      SizedBox(height: 2),
                      Text(
                        'Admin Only',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'For admin account only. Demonstration and testing.',
                        style: kGreyText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const TabBar(
            isScrollable: true,
            labelColor: kGreen,
            unselectedLabelColor: kTextGrey,
            indicatorColor: kGreen,
            tabs: [
              Tab(text: 'Pins'),
              Tab(text: 'Accounts'),
              Tab(text: '911 calls'),
              Tab(text: 'Evacuation'),
              Tab(text: 'Assignments'),
              Tab(text: 'Flood alert'),
              Tab(text: 'Error log'),
            ],
          ),
          const Divider(height: 1, color: kBorder),
          Expanded(
            child: TabBarView(
              children: [
                _pinsTab(),
                _accountsTab(),
                const _CallsTab(),
                _EvacuationStatusTab(users: _users),
                _ResponderAssignmentsTab(users: _users),
                const _FloodEmergencyTab(),
                const _LogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Pins tab ----------

  Widget _pinsTab() {
    final err = _usersError ?? _pinsError;
    if (err != null) {
      return ListView(padding: _tabPadding, children: [_loadError(err)]);
    }
    final users = _users;
    final pins = _pins;
    if (users == null || pins == null) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    final waiting = users.where(_isWaiting).toList();

    return ListView(
      padding: _tabPadding,
      children: [
        StatusBanner(
          tone: BannerTone.success,
          icon: Icons.vpn_key_outlined,
          title: 'One-time pins',
          message:
              'Give the pin to the person. It works once, only for the role it was made for, '
              'and expires in ${AkayBackend.pinLifetime.inMinutes} minutes.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-generate a pin for each new account'),
          subtitle: const Text(
            'Works while this screen is open.',
            style: kGreyText,
          ),
          value: _autoPins,
          onChanged: (v) {
            setState(() => _autoPins = v);
            if (v) _maybeAutoIssue();
          },
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _generatePin(demo: false),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Generate pin'),
                style: FilledButton.styleFrom(
                  backgroundColor: kGreen,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _generatePin(demo: true),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Demo pin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
        const _SectionLabel('WAITING FOR VERIFICATION'),
        if (waiting.isEmpty)
          const Text('No accounts are waiting.', style: kGreyText)
        else
          for (final u in waiting) _waitingRow(u),
        const _SectionLabel('ALL PINS'),
        if (pins.isEmpty)
          const Text('No pins yet.', style: kGreyText)
        else
          for (final p in pins) _pinCard(p, users),
      ],
    );
  }

  Widget _waitingRow(Map<String, dynamic> user) {
    final id = user['id'] as String;
    final mine = _pinsFor(id);
    final active = mine.where((p) => _stateOf(p) == _PinState.active).toList();
    final busy = _issuing.contains(id);

    Widget trailing;
    if (busy) {
      trailing = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: kGreen),
      );
    } else if (active.isNotEmpty) {
      final pin = active.first['id'].toString();
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pin,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: kGreen,
                ),
              ),
              Text(_left(_dateOf(active.first['expiresAt'])), style: kGreyText),
            ],
          ),
          IconButton(
            tooltip: 'Copy pin',
            icon: const Icon(Icons.content_copy, size: 18),
            onPressed: () => _copy(pin),
          ),
        ],
      );
    } else {
      trailing = OutlinedButton(
        onPressed: () => _issue(user),
        child: Text(mine.isEmpty ? 'Generate pin' : 'New pin'),
      );
    }

    return _AdminCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['mobile'] ?? '-').toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(_roleLabel(user)),
                    Text(
                      'Joined ${_ago(_dateOf(user['createdAt']))}',
                      style: kGreyText,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _pinCard(Map<String, dynamic> pin, List<Map<String, dynamic>> users) {
    final code = pin['id'].toString();
    final state = _stateOf(pin);
    final forMobile = pin['forMobile']?.toString();
    final usedBy = pin['usedBy']?.toString();
    String? usedByMobile;
    if (usedBy != null) {
      for (final u in users) {
        if (u['id'] == usedBy) usedByMobile = u['mobile']?.toString();
      }
    }

    late final String stateText;
    late final Color stateBg;
    late final Color stateFg;
    switch (state) {
      case _PinState.active:
        stateText = 'Active';
        stateBg = kLightGreen;
        stateFg = kGreen;
        break;
      case _PinState.used:
        stateText = 'Used';
        stateBg = const Color(0xFFE8EDEA);
        stateFg = kTextGrey;
        break;
      case _PinState.expired:
        stateText = 'Expired';
        stateBg = const Color(0xFFFDF1EE);
        stateFg = kRed;
        break;
    }

    final detail = state == _PinState.used
        ? (usedByMobile != null ? 'Used by $usedByMobile' : 'Used')
        : state == _PinState.active
        ? _left(_dateOf(pin['expiresAt']))
        : '';

    return _AdminCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  code,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: state == _PinState.active ? kGreen : kTextGrey,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(
                      pin['role'] == 'respondent' ? 'Responder' : 'Resident',
                    ),
                    if (pin['demo'] == true)
                      const _Tag(
                        'DEMO',
                        bg: Color(0xFFFDF3DC),
                        fg: Color(0xFF7A5A12),
                      ),
                    _Tag(stateText, bg: stateBg, fg: stateFg),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (forMobile != null)
                      'For $forMobile'
                    else
                      'Not tied to an account',
                    if (detail.isNotEmpty) detail,
                  ].join(' · '),
                  style: kGreyText,
                ),
              ],
            ),
          ),
          if (state == _PinState.active) ...[
            IconButton(
              tooltip: 'Copy pin',
              icon: const Icon(Icons.content_copy, size: 18),
              onPressed: () => _copy(code),
            ),
            IconButton(
              tooltip: 'Revoke pin',
              icon: const Icon(Icons.delete_outline, size: 20, color: kRed),
              onPressed: () => _revoke(code),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Accounts tab ----------

  Widget _accountsTab() {
    final err = _usersError;
    if (err != null) {
      return ListView(padding: _tabPadding, children: [_loadError(err)]);
    }
    final users = _users;
    if (users == null) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    final residents = users.where((u) => u['role'] == 'resident').length;
    final responders = users.where((u) => u['role'] == 'respondent').length;
    final verified = users
        .where((u) => !_isAdminUser(u) && u['verified'] == true)
        .length;
    final waiting = users.where(_isWaiting).length;

    return ListView(
      padding: _tabPadding,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag('${users.length} accounts'),
            _Tag('$residents residents'),
            _Tag('$responders responders'),
            _Tag('$verified verified'),
            _Tag(
              '$waiting waiting',
              bg: const Color(0xFFFDF3DC),
              fg: const Color(0xFF7A5A12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (users.isEmpty)
          const Text('No accounts yet.', style: kGreyText)
        else
          for (final u in users) _accountRow(u),
      ],
    );
  }

  Widget _accountRow(Map<String, dynamic> user) {
    final isAdmin = _isAdminUser(user);
    final isResponder = user['role'] == 'respondent';
    final verified = user['verified'] == true;
    return _AdminCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_outlined
                  : isResponder
                  ? Icons.shield_outlined
                  : Icons.person_outline,
              color: kGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['mobile'] ?? '-').toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Joined ${_ago(_dateOf(user['createdAt']))}',
                  style: kGreyText,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Tag(_roleLabel(user)),
              const SizedBox(height: 6),
              if (verified || isAdmin)
                const _Tag('Verified')
              else
                const _Tag(
                  'Not verified',
                  bg: Color(0xFFFDF3DC),
                  fg: Color(0xFF7A5A12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dialog: choose the role (and, for a demo pin, the digits)
// ============================================================

class _PinOptionsDialog extends StatefulWidget {
  final bool demo;
  const _PinOptionsDialog({required this.demo});

  @override
  State<_PinOptionsDialog> createState() => _PinOptionsDialogState();
}

class _PinOptionsDialogState extends State<_PinOptionsDialog> {
  String _role = 'respondent';
  final _custom = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _custom.text.trim();
    if (text.isNotEmpty && text.length != 6) {
      setState(() => _error = 'Use exactly 6 digits');
      return;
    }
    Navigator.of(context).pop(_PinOptions(_role, text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.demo ? 'Demo pin' : 'Generate pin'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.demo
                ? 'A special one-time pin for a demonstration. It stays valid for '
                      '${AkayBackend.demoPinLifetime.inHours} hours.'
                : 'A one-time pin that is not tied to a specific account.',
            style: kGreyText,
          ),
          const SizedBox(height: 14),
          const Text('Who is it for?'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'resident', label: Text('Resident')),
              ButtonSegment<String>(
                value: 'respondent',
                label: Text('Responder'),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          if (widget.demo) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Pin (optional)',
                helperText: 'Leave blank for a random pin',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

// ============================================================
// 911 calls tab: the admin can accept pending requests (demo)
// ============================================================

class _CallsTab extends StatefulWidget {
  const _CallsTab();

  @override
  State<_CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<_CallsTab> {
  late final Stream<List<Map<String, dynamic>>> _pending;
  late final Stream<List<Map<String, dynamic>>> _mine;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _pending = AkayBackend.pendingRequests();
    _mine = AkayBackend.myAcceptedRequests();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(
    String id,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busyId = id);
    try {
      await action();
      _toast(done);
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _accept(Map<String, dynamic> r) async {
    final id = r['id'] as String;
    final ok = await confirmDialog(
      context,
      title: 'Accept this 911 call?',
      message: 'For demonstration. The resident will see that a responder is on the way.',
      confirmLabel: 'Accept',
      cancelLabel: 'Cancel',
    );
    if (!ok || !mounted) return;
    await _run(id, () => AkayBackend.acceptRequest(id), 'Call accepted');
  }

  Future<void> _resolve(Map<String, dynamic> r) async {
    final id = r['id'] as String;
    await _run(id, () => AkayBackend.resolveRequest(id), 'Marked as resolved');
  }

  Future<void> _release(Map<String, dynamic> r) async {
    final id = r['id'] as String;
    await _run(id, () => AkayBackend.releaseRequest(id), 'Call released');
  }

  Widget _requestCard(Map<String, dynamic> r, {required bool accepted}) {
    final id = r['id'] as String;
    final type = (r['type'] ?? 'other').toString();
    final barangay = (r['barangay'] ?? 'Unknown barangay').toString();
    final when = accepted
        ? 'Accepted ${_ago(_dateOf(r['matchedAt']))}'
        : 'Sent ${_ago(_dateOf(r['createdAt']))}';
    final busy = _busyId == id;

    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF1EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(requestTypeIcon(type), color: kRed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestTypeLabel(type),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$barangay · $when', style: kGreyText),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (accepted)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _release(r),
                    child: const Text('Release'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _resolve(r),
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    child: const Text('Mark resolved'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : () => _accept(r),
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Accept call'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _tabPadding,
      children: [
        const StatusBanner(
          tone: BannerTone.warning,
          icon: Icons.science_outlined,
          title: 'Demonstration only',
          message:
              'Accepting a call matches it with the admin account, so the resident '
              'sees that a responder is on the way. The admin can hold one call at a time.',
        ),
        const _SectionLabel('WAITING FOR A RESPONDER'),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _pending,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _loadError(snapshot.error!);
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: kGreen)),
              );
            }
            final list = snapshot.data!;
            if (list.isEmpty) {
              return const Text('No pending 911 calls.', style: kGreyText);
            }
            return Column(
              children: [
                for (final r in list) _requestCard(r, accepted: false),
              ],
            );
          },
        ),
        const _SectionLabel('ACCEPTED BY ADMIN'),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _mine,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _loadError(snapshot.error!);
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: kGreen)),
              );
            }
            final list = snapshot.data!
                .where((r) => r['status'] == 'matched')
                .toList();
            if (list.isEmpty) {
              return const Text(
                'Nothing accepted right now.',
                style: kGreyText,
              );
            }
            return Column(
              children: [for (final r in list) _requestCard(r, accepted: true)],
            );
          },
        ),
      ],
    );
  }
}

// ============================================================
// Admin evacuation status, responder assignments, and flood advisory
// ============================================================

class _EvacuationStatusTab extends StatelessWidget {
  final List<Map<String, dynamic>>? users;

  const _EvacuationStatusTab({required this.users});

  String _statusLabel(Map<String, dynamic>? status) {
    switch (status?['status']) {
      case 'home':
        return 'Still at home';
      case 'transit':
        return 'In transit';
      case 'evacuated':
        return 'Evacuated';
      case 'unreported':
      default:
        return 'Needs status update';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = users;
    if (accounts == null) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    final residents = accounts
        .where(
          (user) =>
              (user['role'] == 'resident' || user['role'] == 'respondent') &&
              user['accountStatus'] != 'deleted' &&
              !_isAdminUser(user),
        )
        .toList();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AkayBackend.adminEvacuationStatuses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: _tabPadding,
            children: [_loadError(snapshot.error!)],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreen));
        }

        final statusByUid = {
          for (final status in snapshot.data!) status['id'].toString(): status,
        };
        return ListView(
          padding: _tabPadding,
          children: [
            const StatusBanner(
              tone: BannerTone.warning,
              icon: Icons.shield_outlined,
              title: 'User evacuation status',
              message: 'A status reset by a new flood alert appears as “Needs status update” until the user reports again.',
            ),
            _SectionLabel('${residents.length} user accounts'),
            if (residents.isEmpty)
              const Text(
                'No resident or responder accounts found.',
                style: kGreyText,
              )
            else
              for (final resident in residents)
                _AdminCard(
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: kGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (resident['mobile'] ?? 'Resident').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              statusByUid[resident['id']] == null
                                  ? 'No status reported'
                                  : statusByUid[resident['id']]!['status'] ==
                                        'unreported'
                                  ? 'Reset ${_ago(_dateOf(statusByUid[resident['id']]!['updatedAt']))}'
                                  : 'Updated ${_ago(_dateOf(statusByUid[resident['id']]!['updatedAt']))}',
                              style: kGreyText,
                            ),
                          ],
                        ),
                      ),
                      _Tag(
                        _statusLabel(statusByUid[resident['id']]),
                        bg:
                            statusByUid[resident['id']]?['status'] ==
                                'evacuated'
                            ? kLightGreen
                            : const Color(0xFFFFF6E0),
                        fg:
                            statusByUid[resident['id']]?['status'] ==
                                'evacuated'
                            ? kGreen
                            : const Color(0xFF8A6500),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _ResponderAssignmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>>? users;

  const _ResponderAssignmentsTab({required this.users});

  @override
  Widget build(BuildContext context) {
    final accounts = users;
    if (accounts == null) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    final mobileByUid = {
      for (final user in accounts) user['id'].toString(): user['mobile'],
    };

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AkayBackend.adminRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: _tabPadding,
            children: [_loadError(snapshot.error!)],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreen));
        }

        final assignments = snapshot.data!
            .where(
              (request) =>
                  request['responderId'] is String &&
                  (request['responderId'] as String).isNotEmpty,
            )
            .toList();
        return ListView(
          padding: _tabPadding,
          children: [
            const StatusBanner(
              tone: BannerTone.success,
              icon: Icons.assignment_ind_outlined,
              title: 'Accepted requests',
              message: 'Shows active and completed requests that still have an assigned responder.',
            ),
            _SectionLabel('${assignments.length} accepted assignments'),
            if (assignments.isEmpty)
              const Text(
                'No requests have been accepted yet.',
                style: kGreyText,
              )
            else
              for (final request in assignments)
                _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            requestTypeIcon(
                              (request['type'] ?? 'other').toString(),
                            ),
                            color: kGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              requestTypeLabel(
                                (request['type'] ?? 'other').toString(),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                              ),
                            ),
                          ),
                          _Tag((request['status'] ?? 'unknown').toString()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Resident: ${mobileByUid[request['userId']] ?? request['userId'] ?? 'Unknown'}',
                        style: kGreyText,
                      ),
                      Text(
                        'Responder: ${request['responderMobile'] ?? mobileByUid[request['responderId']] ?? request['responderId']}',
                        style: kGreyText,
                      ),
                      Text(
                        '${request['barangay'] ?? 'Location unavailable'} · Accepted ${_ago(_dateOf(request['matchedAt']))}',
                        style: kGreyText,
                      ),
                      Text('Request ID: ${request['id']}', style: kGreyText),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _FloodEmergencyTab extends StatefulWidget {
  const _FloodEmergencyTab();

  @override
  State<_FloodEmergencyTab> createState() => _FloodEmergencyTabState();
}

class _FloodEmergencyTabState extends State<_FloodEmergencyTab> {
  final _titleController = TextEditingController(text: 'Flood emergency');
  final _messageController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _start() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _toast('Enter the flood advisory for residents.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Start flood emergency?',
      message: 'This publishes the advisory in the app and resets existing evacuation statuses to “Needs status update.”',
      confirmLabel: 'Start emergency',
      cancelLabel: 'Cancel',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await AkayBackend.adminStartFloodEmergency(
        title: _titleController.text,
        message: message,
      );
      _toast('Flood advisory active. $count evacuation statuses reset.');
    } catch (e) {
      _toast(
        'The advisory was not activated. Some statuses may have reset; check the Evacuation tab before retrying. ${AkayBackend.friendlyError(e)}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    final ok = await confirmDialog(
      context,
      title: 'End flood emergency?',
      message: 'The in-app flood advisory will stop appearing.',
      confirmLabel: 'End emergency',
      cancelLabel: 'Keep active',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AkayBackend.adminEndFloodEmergency();
      _toast('Flood advisory ended.');
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: AkayBackend.floodEmergency(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: _tabPadding,
            children: [_loadError(snapshot.error!)],
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreen));
        }

        final emergency = snapshot.data ?? const <String, dynamic>{};
        final active = emergency['active'] == true;
        final resetCount = emergency['resetCount'] is int
            ? emergency['resetCount'] as int
            : 0;
        final resetComplete = emergency['resetComplete'] == true;

        return ListView(
          padding: _tabPadding,
          children: [
            if (active) ...[
              StatusBanner(
                tone: BannerTone.warning,
                icon: Icons.water_drop,
                title: emergency['title']?.toString() ?? 'Flood emergency',
                message: emergency['message']?.toString() ?? '',
              ),
              const SizedBox(height: 10),
              StatusBanner(
                tone: resetComplete ? BannerTone.success : BannerTone.danger,
                icon: resetComplete
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                title: resetComplete
                    ? 'Status reset complete'
                    : 'Status reset incomplete',
                message:
                    '$resetCount existing evacuation status records reset to “Needs status update”.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _end,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End flood emergency'),
                style: FilledButton.styleFrom(backgroundColor: kRed),
              ),
            ] else ...[
              if (emergency.isNotEmpty && !resetComplete)
                StatusBanner(
                  tone: _busy ? BannerTone.warning : BannerTone.danger,
                  icon: _busy ? Icons.hourglass_top : Icons.error_outline,
                  title: _busy
                      ? 'Flood emergency setup in progress'
                      : 'Previous status reset did not finish',
                  message: _busy
                      ? 'Keep this screen open until the reset and advisory finish.'
                      : 'Some accounts may already show “Needs status update”. Check the Evacuation tab before starting again.',
                ),
              const StatusBanner(
                tone: BannerTone.warning,
                icon: Icons.info_outline,
                title: 'In-app advisory only',
                message: 'Signed-in users see this alert while the app is open or the next time they connect. This does not send a push notification when the app is closed.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Advisory title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Flood advisory message',
                  hintText: 'Enter the instructions residents should follow.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.water_drop),
                label: Text(
                  _busy ? 'Starting emergency…' : 'Start flood emergency',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kRed,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================
// Error log tab: exceptions written by AkayBackend.logError
// ============================================================

class _LogTab extends StatefulWidget {
  const _LogTab();

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  late final Stream<List<Map<String, dynamic>>> _logs;
  List<String> _ids = const [];
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _logs = AkayBackend.adminErrorLogs();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logTest() async {
    setState(() => _testing = true);
    try {
      await AkayBackend.adminLogTestException();
      _toast('Test exception logged. It appears in the list below.');
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clearAll() async {
    final ok = await confirmDialog(
      context,
      title: 'Clear the error log?',
      message: 'This deletes every entry shown below.',
      confirmLabel: 'Clear all',
      cancelLabel: 'Cancel',
    );
    if (!ok) return;
    try {
      await AkayBackend.adminClearErrorLogs(_ids);
      _toast('Error log cleared');
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await AkayBackend.adminDeleteErrorLog(id);
    } catch (e) {
      _toast(AkayBackend.friendlyError(e));
    }
  }

  Widget _logCard(Map<String, dynamic> log) {
    final id = log['id'] as String;
    final message = (log['message'] ?? '').toString();
    final source = log['source']?.toString();
    final stack = log['stack']?.toString();
    final uid = (log['uid'] ?? '').toString();
    final shortUid = uid.length > 6 ? uid.substring(0, 6) : uid;

    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (source != null)
                      _Tag(source, bg: const Color(0xFFFDF1EE), fg: kRed),
                    Text(
                      '${_ago(_dateOf(log['createdAt']))} · user $shortUid',
                      style: kGreyText,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _delete(id),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 20, color: kTextGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4, color: kTextDark),
          ),
          if (stack != null && stack.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Stack trace', style: kGreyText),
                children: [
                  SelectableText(
                    stack,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: kTextGrey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _tabPadding,
      children: [
        const StatusBanner(
          tone: BannerTone.success,
          icon: Icons.bug_report_outlined,
          title: 'Exception log',
          message:
              'Errors that the app shows to users, and uncaught errors, are saved here '
              'with the time and the user. Repeats within a minute are saved once.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _testing ? null : _logTest,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Log Test Exception'),
                style: FilledButton.styleFrom(
                  backgroundColor: kGreen,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _ids.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kRed,
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ),
        const _SectionLabel('LATEST ERRORS'),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _logs,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _loadError(snapshot.error!);
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: kGreen)),
              );
            }
            final list = snapshot.data!;
            _ids = list.map((l) => l['id'] as String).toList();
            if (list.isEmpty) {
              return const Text('No errors logged.', style: kGreyText);
            }
            return Column(children: [for (final l in list) _logCard(l)]);
          },
        ),
      ],
    );
  }
}
