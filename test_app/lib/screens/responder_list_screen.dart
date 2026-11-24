import 'profile_screen.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'checkin_screen.dart';
import 'respond_ping_screen.dart';
import 'screen_widgets.dart';
import 'track_response_screen.dart';

typedef RequestMap = Map<String, dynamic>;

// ============================================================
// AKAY - Responder: "Households needing help" (wireframe 10)
//
// Backend used:
//   AkayBackend.setOnline(bool)          online switch (needs GPS)
//   AkayBackend.pendingRequests()        live list of households waiting
//   AkayBackend.watchRequestDetails(id)  exact address & household needs
//   AkayBackend.myAcceptedRequests()     requests this responder accepted
//   AkayBackend.currentPosition()        responder GPS for Map tab
// ============================================================
class ResponderListScreen extends StatefulWidget {
  const ResponderListScreen({super.key});

  @override
  State<ResponderListScreen> createState() => _ResponderListScreenState();
}

enum _PriorityFilter { all, critical, high }

enum _NeedsFilter { all, anyMobility, wheelchair, bedridden, oxygen, seniors }

enum _StatusFilter { all, stillHere, inTransit, localUpdate }

class _ResponderListScreenState extends State<ResponderListScreen> {
  bool _online = false;
  bool _showMap = false;

  _PriorityFilter _selectedPriority = _PriorityFilter.all;
  _NeedsFilter _selectedNeeds = _NeedsFilter.all;
  _StatusFilter _selectedStatus = _StatusFilter.all;

  DateTime _lastUpdated = DateTime.now();

  // Figma-style sample households, shown only while kShowSampleData is true
  // and no real requests exist. They have no 'id', so nothing is sent.
  static final List<RequestMap> _sample = [
    {
      'type': 'medical',
      'status': 'pending',
      'evacStatus': 'Still here',
      'address': 'Purok 2',
      'minutes': 12,
      'lat': 7.9045,
      'lng': 125.0928,
      'household': {
        'name': 'Reyes Household',
        'members': 3,
        'mobilityNeed': 'Bedridden',
        'notes': ['Oxygen tank'],
      },
    },
    {
      'type': 'flood',
      'status': 'pending',
      'evacStatus': 'Request waiting',
      'address': 'Purok 4',
      'minutes': 8,
      'lat': 7.9018,
      'lng': 125.0952,
      'household': {
        'name': 'Santos Household',
        'members': 4,
        'mobilityNeed': 'Wheelchair',
        'notes': ['2 seniors'],
      },
    },
    {
      'type': 'other',
      'status': 'local',
      'evacStatus': 'In transit',
      'address': 'Purok 1',
      'minutes': 4,
      'lat': 7.9061,
      'lng': 125.0904,
      'household': {
        'name': 'Cruz Household',
        'members': 5,
        'mobilityNeed': 'None',
        'notes': ['Status waiting to sync'],
      },
    },
  ];

  Future<void> _toggleOnline(bool value) async {
    try {
      await AkayBackend.setOnline(value);
      if (mounted) setState(() => _online = value);
    } catch (e) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

  bool _isLocalUpdate(RequestMap r) =>
      (r['status'] ?? '').toString() == 'local';

  bool _isCritical(RequestMap r) =>
      r['type'] == 'medical' || r['type'] == 'fire';

  int _minutes(RequestMap r) {
    if (r['minutes'] is int) return r['minutes'] as int;
    try {
      return DateTime.now().difference(r['createdAt'].toDate()).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  String _evacLabel(RequestMap r) {
    final explicit = (r['evacStatus'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;
    final status = (r['status'] ?? 'pending').toString();
    switch (status) {
      case 'matched':
        return 'In transit';
      case 'resolved':
        return 'Evacuated / Safe';
      case 'local':
        return 'Local update';
      default:
        return 'Still here';
    }
  }

  String _locationLine(RequestMap r) {
    final place = (r['address'] ?? r['barangay'] ?? '').toString().trim();
    final status = _evacLabel(r);
    if (place.isEmpty) return status;
    return '$place · $status';
  }

  String _needsLine(RequestMap r) {
    final h = (r['household'] is Map) ? r['household'] as Map : const {};
    final parts = <String>[];
    final mobility = (h['mobilityNeed'] ?? '').toString().trim();
    if (mobility.isNotEmpty && mobility.toLowerCase() != 'none') {
      parts.add(mobility);
    }
    final notes = h['notes'];
    if (notes is List && notes.isNotEmpty) {
      parts.add(notes.map((e) => e.toString()).join(' · '));
    }
    if (h['members'] != null) {
      parts.add('${h['members']} people');
    }
    return parts.isEmpty ? 'No special mobility notes' : parts.join(' · ');
  }

  bool _matchesFilters(RequestMap r) {
    if (_selectedPriority == _PriorityFilter.critical && !_isCritical(r)) {
      return false;
    }
    if (_selectedPriority == _PriorityFilter.high &&
        (_isCritical(r) || _isLocalUpdate(r))) {
      return false;
    }

    final h = (r['household'] is Map) ? r['household'] as Map : const {};
    final mobility = (h['mobilityNeed'] ?? '').toString().toLowerCase();
    final notesText = (h['notes'] is List)
        ? (h['notes'] as List).join(' ').toLowerCase()
        : '';
    final combinedNeeds = '$mobility $notesText';

    switch (_selectedNeeds) {
      case _NeedsFilter.all:
        break;
      case _NeedsFilter.anyMobility:
        if (mobility.isEmpty || mobility == 'none') return false;
        break;
      case _NeedsFilter.wheelchair:
        if (!combinedNeeds.contains('wheelchair')) return false;
        break;
      case _NeedsFilter.bedridden:
        if (!combinedNeeds.contains('bedridden')) return false;
        break;
      case _NeedsFilter.oxygen:
        if (!combinedNeeds.contains('oxygen')) return false;
        break;
      case _NeedsFilter.seniors:
        if (!combinedNeeds.contains('senior')) return false;
        break;
    }

    final status = (r['status'] ?? 'pending').toString();
    final evacLower = _evacLabel(r).toLowerCase();
    switch (_selectedStatus) {
      case _StatusFilter.all:
        break;
      case _StatusFilter.stillHere:
        if (status != 'pending') return false;
        break;
      case _StatusFilter.inTransit:
        if (status != 'matched' && !evacLower.contains('transit')) return false;
        break;
      case _StatusFilter.localUpdate:
        if (!_isLocalUpdate(r)) return false;
        break;
    }

    return true;
  }

  String _priorityFilterLabel(_PriorityFilter f) {
    switch (f) {
      case _PriorityFilter.all:
        return 'Priority';
      case _PriorityFilter.critical:
        return 'Critical';
      case _PriorityFilter.high:
        return 'High';
    }
  }

  String _needsFilterLabel(_NeedsFilter f) {
    switch (f) {
      case _NeedsFilter.all:
        return 'Needs';
      case _NeedsFilter.anyMobility:
        return 'Mobility';
      case _NeedsFilter.wheelchair:
        return 'Wheelchair';
      case _NeedsFilter.bedridden:
        return 'Bedridden';
      case _NeedsFilter.oxygen:
        return 'Oxygen';
      case _NeedsFilter.seniors:
        return 'Seniors';
    }
  }

  String _statusFilterLabel(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.all:
        return 'Status';
      case _StatusFilter.stillHere:
        return 'Still here';
      case _StatusFilter.inTransit:
        return 'In transit';
      case _StatusFilter.localUpdate:
        return 'Local sync';
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatedStr = TimeOfDay.fromDateTime(_lastUpdated).format(context);

    return AkayScreen(
      showBack: Navigator.of(context).canPop(),
      trailing: IconButton(
        tooltip: 'Account & sign out',
        icon: const Icon(Icons.account_circle_outlined, color: kTextDark),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
      child: StreamBuilder<List<RequestMap>>(
        stream: AkayBackend.pendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _lastUpdated = DateTime.now();
          }

          final rawItems = snapshot.data ?? const <RequestMap>[];
          final usingSample =
              snapshot.hasData && rawItems.isEmpty && kShowSampleData;
          final sourceItems = usingSample ? _sample : rawItems;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Freshness bar (Wireframe 10)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: kLightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCFE5DA)),
                ),
                child: Row(
                  children: [
                    Icon(
                      snapshot.hasError ? Icons.wifi_off : Icons.wifi,
                      size: 16,
                      color: kGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        snapshot.hasError
                            ? 'OFFLINE COPY · UPDATED $updatedStr'
                            : usingSample
                            ? 'SAMPLE PREVIEW · UPDATED $updatedStr'
                            : 'LIVE LIST · UPDATED $updatedStr',
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: kGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Households needing help',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 12),

              // Online / offline availability switch
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _online
                            ? 'You are online to responders'
                            : 'You are offline',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                    ),
                    Switch(
                      value: _online,
                      activeTrackColor: kGreen,
                      onChanged: _toggleOnline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StatusBanner(
                    tone: BannerTone.danger,
                    icon: Icons.error_outline,
                    message: AkayBackend.friendlyError(snapshot.error!),
                  ),
                ),

              if (!snapshot.hasData && !snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: kGreen),
                  ),
                )
              else
                _HydratedRequestsBody(
                  rawItems: sourceItems,
                  usingSample: usingSample,
                  showMap: _showMap,
                  onToggleMap: (mapMode) => setState(() => _showMap = mapMode),
                  priorityLabel: _priorityFilterLabel(_selectedPriority),
                  priorityActive: _selectedPriority != _PriorityFilter.all,
                  onPickPriority: _pickPriority,
                  needsLabel: _needsFilterLabel(_selectedNeeds),
                  needsActive: _selectedNeeds != _NeedsFilter.all,
                  onPickNeeds: _pickNeeds,
                  statusLabel: _statusFilterLabel(_selectedStatus),
                  statusActive: _selectedStatus != _StatusFilter.all,
                  onPickStatus: _pickStatus,
                  hasActiveFilters:
                      _selectedPriority != _PriorityFilter.all ||
                      _selectedNeeds != _NeedsFilter.all ||
                      _selectedStatus != _StatusFilter.all,
                  onClearFilters: () => setState(() {
                    _selectedPriority = _PriorityFilter.all;
                    _selectedNeeds = _NeedsFilter.all;
                    _selectedStatus = _StatusFilter.all;
                  }),
                  matchesFilters: _matchesFilters,
                  cardBuilder: (r) => _card(context, r),
                ),

              // Requests this responder already accepted
              StreamBuilder<List<RequestMap>>(
                stream: AkayBackend.myAcceptedRequests(),
                builder: (context, acceptedSnap) {
                  final mine = acceptedSnap.data ?? const <RequestMap>[];
                  if (mine.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ACCEPTED BY YOU', style: kSmallLabel),
                        const SizedBox(height: 8),
                        for (final r in mine) _acceptedTile(context, r),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              OutlineAction(
                label: 'Evacuation-center check-in',
                icon: Icons.fact_check_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickPriority() async {
    final picked = await showModalBottomSheet<_PriorityFilter>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by priority',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final f in _PriorityFilter.values)
              ListTile(
                title: Text(
                  f == _PriorityFilter.all
                      ? 'All priorities'
                      : _priorityFilterLabel(f),
                ),
                trailing: f == _selectedPriority
                    ? const Icon(Icons.check, color: kGreen)
                    : null,
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedPriority = picked);
  }

  Future<void> _pickNeeds() async {
    final picked = await showModalBottomSheet<_NeedsFilter>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by household needs',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final f in _NeedsFilter.values)
              ListTile(
                title: Text(
                  f == _NeedsFilter.all ? 'All needs' : _needsFilterLabel(f),
                ),
                trailing: f == _selectedNeeds
                    ? const Icon(Icons.check, color: kGreen)
                    : null,
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedNeeds = picked);
  }

  Future<void> _pickStatus() async {
    final picked = await showModalBottomSheet<_StatusFilter>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by evacuation status',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final f in _StatusFilter.values)
              ListTile(
                title: Text(
                  f == _StatusFilter.all
                      ? 'All statuses'
                      : _statusFilterLabel(f),
                ),
                trailing: f == _selectedStatus
                    ? const Icon(Icons.check, color: kGreen)
                    : null,
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedStatus = picked);
  }

  Widget _acceptedTile(BuildContext context, RequestMap r) {
    final id = r['id']?.toString();
    if (id == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: AkayBackend.watchRequestDetails(id),
      builder: (context, detailSnap) {
        final detail = detailSnap.data?.data();
        final hh = detail?['household'] ?? r['household'];
        final name = (hh is Map ? hh['name'] : null)?.toString() ?? 'Household';
        final address = (detail?['address'] ?? r['barangay'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kBorder),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
            subtitle: Text(
              '${requestTypeLabel((r['type'] ?? 'other').toString())}'
              '${address.isNotEmpty ? ' · $address' : ''} · ${r['status']}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrackResponseScreen(requestId: id),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, RequestMap r) {
    final local = _isLocalUpdate(r);
    final critical = _isCritical(r);
    final color = local ? kTextGrey : (critical ? kRed : kAmberDot);
    final name =
        (r['household'] is Map ? r['household']['name'] : null)?.toString() ??
        'Household';
    final badgeText = local
        ? 'LOCAL UPDATE'
        : '${critical ? 'CRITICAL' : 'HIGH'} · ${_minutes(r)} MIN';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _locationLine(r),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_needsLine(r), style: kGreyText),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RespondPingScreen(request: r),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                backgroundColor: kLightGreen,
                side: const BorderSide(color: Color(0xFFCFE5DA)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                local ? 'Open household' : 'Open request',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Hydrates real Firestore requests with their matching
// `requestDetails/{id}` docs so household name, address,
// mobility needs, and notes are available to filters, cards,
// the map view, and RespondPingScreen.
// ============================================================
class _HydratedRequestsBody extends StatelessWidget {
  final List<RequestMap> rawItems;
  final bool usingSample;
  final bool showMap;
  final ValueChanged<bool> onToggleMap;

  final String priorityLabel;
  final bool priorityActive;
  final VoidCallback onPickPriority;

  final String needsLabel;
  final bool needsActive;
  final VoidCallback onPickNeeds;

  final String statusLabel;
  final bool statusActive;
  final VoidCallback onPickStatus;

  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  final bool Function(RequestMap) matchesFilters;
  final Widget Function(RequestMap) cardBuilder;

  const _HydratedRequestsBody({
    required this.rawItems,
    required this.usingSample,
    required this.showMap,
    required this.onToggleMap,
    required this.priorityLabel,
    required this.priorityActive,
    required this.onPickPriority,
    required this.needsLabel,
    required this.needsActive,
    required this.onPickNeeds,
    required this.statusLabel,
    required this.statusActive,
    required this.onPickStatus,
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.matchesFilters,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return _RecursiveDetailJoiner(
      items: rawItems,
      index: 0,
      accumulated: const [],
      builder: (hydratedItems) {
        final filtered = hydratedItems.where(matchesFilters).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // List / Map segmented toggle (Wireframe 10)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Expanded(
                    child: _Seg(
                      label: 'List · ${filtered.length}',
                      selected: !showMap,
                      onTap: () => onToggleMap(false),
                    ),
                  ),
                  Expanded(
                    child: _Seg(
                      label: 'Map',
                      selected: showMap,
                      onTap: () => onToggleMap(true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3-column filter row: Priority | Needs | Status
            Row(
              children: [
                Expanded(
                  child: _FilterDropdownButton(
                    label: priorityLabel,
                    active: priorityActive,
                    onTap: onPickPriority,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterDropdownButton(
                    label: needsLabel,
                    active: needsActive,
                    onTap: onPickNeeds,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterDropdownButton(
                    label: statusLabel,
                    active: statusActive,
                    onTap: onPickStatus,
                  ),
                ),
              ],
            ),
            if (hasActiveFilters)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClearFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Clear filters',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),

            if (showMap)
              _ResponderMapView(requests: filtered)
            else if (filtered.isEmpty)
              const AppCard(
                child: Text(
                  'No households match the current filters.',
                  style: kGreyText,
                ),
              )
            else
              for (final r in filtered) cardBuilder(r),

            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Data may be outdated. Confirm by radio when possible.',
                textAlign: TextAlign.center,
                style: kGreyText,
              ),
            ),
            if (usingSample)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Center(
                  child: Text(
                    'Showing sample households while live queue is empty.',
                    textAlign: TextAlign.center,
                    style: kGreyText,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecursiveDetailJoiner extends StatelessWidget {
  final List<RequestMap> items;
  final int index;
  final List<RequestMap> accumulated;
  final Widget Function(List<RequestMap> hydrated) builder;

  const _RecursiveDetailJoiner({
    required this.items,
    required this.index,
    required this.accumulated,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (index >= items.length) {
      return builder(accumulated);
    }

    final current = items[index];
    final id = current['id']?.toString();
    if (id == null || id.isEmpty) {
      return _RecursiveDetailJoiner(
        items: items,
        index: index + 1,
        accumulated: [...accumulated, current],
        builder: builder,
      );
    }

    return StreamBuilder(
      stream: AkayBackend.watchRequestDetails(id),
      builder: (context, snapshot) {
        final detail = snapshot.data?.data();
        final merged = RequestMap.from({
          ...current,
          if (detail != null) ...{
            'address': detail['address'] ?? current['address'],
            'description': detail['description'] ?? current['description'],
            'household': detail['household'] ?? current['household'],
            if (detail['location'] != null) 'location': detail['location'],
          },
        });
        return _RecursiveDetailJoiner(
          items: items,
          index: index + 1,
          accumulated: [...accumulated, merged],
          builder: builder,
        );
      },
    );
  }
}

// ============================================================
// Interactive Map View for Responder Household List
// ============================================================
class _ResponderMapView extends StatefulWidget {
  final List<RequestMap> requests;
  const _ResponderMapView({required this.requests});

  @override
  State<_ResponderMapView> createState() => _ResponderMapViewState();
}

class _ResponderMapViewState extends State<_ResponderMapView> {
  int _selectedIndex = 0;
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    try {
      final pos = await AkayBackend.currentPosition();
      if (!mounted) return;
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
      });
    } catch (_) {
      // GPS unavailable or denied; map still renders relative pins cleanly.
    }
  }

  (double, double)? _coordsFor(RequestMap r) {
    final loc = r['location'];
    if (loc != null) {
      try {
        final dynamic d = loc;
        final lat = (d.latitude as num).toDouble();
        final lng = (d.longitude as num).toDouble();
        return (lat, lng);
      } catch (_) {}
    }
    if (r['lat'] is num && r['lng'] is num) {
      return ((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requests.isEmpty) {
      return const AppCard(
        child: Text('No households to display on the map.', style: kGreyText),
      );
    }

    final safeIndex = _selectedIndex
        .clamp(0, widget.requests.length - 1)
        .toInt();
    final selected = widget.requests[safeIndex];
    final selectedName =
        (selected['household'] is Map ? selected['household']['name'] : null)
            ?.toString() ??
        'Household';
    final selectedAddress =
        (selected['address'] ?? selected['barangay'] ?? 'Location shared')
            .toString();

    double? refLat = _myLat;
    double? refLng = _myLng;
    if (refLat == null || refLng == null) {
      for (final r in widget.requests) {
        final c = _coordsFor(r);
        if (c != null) {
          refLat = c.$1;
          refLng = c.$2;
          break;
        }
      }
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EFEB),
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: kTextDark, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 6),
                      ],
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                for (int i = 0; i < widget.requests.length; i++)
                  _buildPin(i, widget.requests[i], refLat, refLng, safeIndex),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(selectedAddress, style: kGreyText),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RespondPingScreen(request: selected),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  backgroundColor: kLightGreen,
                  side: const BorderSide(color: Color(0xFFCFE5DA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Open request',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPin(
    int index,
    RequestMap r,
    double? refLat,
    double? refLng,
    int safeIndex,
  ) {
    final coords = _coordsFor(r);
    double alignX;
    double alignY;

    if (coords != null && refLat != null && refLng != null) {
      final dx = (coords.$2 - refLng) * 140;
      final dy = -(coords.$1 - refLat) * 140;
      if (dx.abs() < 0.05 && dy.abs() < 0.05) {
        final angle = (index * 1.4) + 0.6;
        alignX = math.cos(angle) * 0.45;
        alignY = math.sin(angle) * 0.45;
      } else {
        alignX = dx.clamp(-0.78, 0.78);
        alignY = dy.clamp(-0.75, 0.75);
      }
    } else {
      final angle = (index * 1.4) + 0.6;
      alignX = math.cos(angle) * 0.48;
      alignY = math.sin(angle) * 0.48;
    }

    final isCritical = r['type'] == 'medical' || r['type'] == 'fire';
    final isSelected = index == safeIndex;

    return Align(
      alignment: Alignment(alignX, alignY),
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCritical ? kRed : kAmberDot,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? kTextDark : Colors.white,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 6),
            ],
          ),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final riverPaint = Paint()..color = const Color(0xFFC6DBE3);
    canvas.drawRect(Rect.fromLTWH(0, 0, 36, size.height), riverPaint);

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 6;
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.35),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.55, 0),
      Offset(size.width * 0.42, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterDropdownButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterDropdownButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kLightGreen : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? kGreen : kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? kGreen : kTextDark,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: active ? kGreen : kTextGrey,
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kGreen : Colors.white,
          border: Border.all(color: kGreen),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : kGreen,
          ),
        ),
      ),
    );
  }
}
