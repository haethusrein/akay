// ============================================================
// AKAY - The map widget (flutter_map = Flutter's version of Leaflet.js)
//
// It fills whatever space its parent gives it, so the SAME widget is used for
//   * the 70% map in the Community tab   (see community_map.dart)
//   * the full-screen map                 (see community_map.dart)
// All options live in map_config.dart.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart'; // colors
import 'map_config.dart';
import 'map_data.dart';

class AkayMap extends StatefulWidget {
  /// true when shown full screen (changes the button icon and top spacing).
  final bool fullScreen;

  /// Called when the expand / close button is pressed.
  final VoidCallback? onToggleFullScreen;

  const AkayMap({super.key, this.fullScreen = false, this.onToggleFullScreen});

  @override
  State<AkayMap> createState() => _AkayMapState();
}

class _AkayMapState extends State<AkayMap> {
  final _controller = MapController();
  LatLng? _me; // my position once "find me" was pressed
  bool _locating = false;

  // ---------- button actions ----------
  void _zoom(double change) {
    final cam = _controller.camera;
    final z = (cam.zoom + change).clamp(MapConfig.minZoom, MapConfig.maxZoom);
    _controller.move(cam.center, z);
  }

  Future<void> _findMe() async {
    setState(() => _locating = true);
    try {
      final p = await AkayBackend.currentPosition();
      final me = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() => _me = me);
      _controller.move(me, 16);
    } catch (e) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _backToCity() => _controller.move(MapConfig.center, MapConfig.startZoom);

  // ---------- pins ----------
  Marker _pinMarker(MapPin pin) {
    final isCenter = pin.kind == 'center';
    final color =
        isCenter ? MapConfig.centerColor : MapConfig.colorForType(pin.kind);
    final icon = isCenter ? Icons.shield : MapConfig.iconForType(pin.kind);
    return Marker(
      point: pin.point,
      width: 38,
      height: 38,
      child: GestureDetector(
        onTap: () => showComingSoon(context, pin.title),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: isCenter ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isCenter ? BorderRadius.circular(10) : null,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 4),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Marker _meMarker(LatLng p) => Marker(
    point: p,
    width: 26,
    height: 26,
    child: Container(
      decoration: BoxDecoration(
        color: MapConfig.meColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final topPad = widget.fullScreen ? MediaQuery.of(context).padding.top : 0.0;

    return StreamBuilder<List<MapPin>>(
      stream: MapData.requestPins(),
      builder: (context, requests) {
        return StreamBuilder<List<MapPin>>(
          stream: MapData.evacuationCenters(),
          builder: (context, centers) {
            final pins = <MapPin>[
              ...?centers.data, // centers first so request pins sit on top
              ...?requests.data,
            ];

            return Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: MapConfig.center,
                    initialZoom: MapConfig.startZoom,
                    minZoom: MapConfig.minZoom,
                    maxZoom: MapConfig.maxZoom,
                    cameraConstraint: MapConfig.limitToCity
                        ? CameraConstraint.contain(bounds: MapConfig.cityBounds)
                        : const CameraConstraint.unconstrained(),
                    interactionOptions: InteractionOptions(
                      flags: MapConfig.allowRotate
                          ? InteractiveFlag.all
                          : InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapConfig.tileUrl,
                      userAgentPackageName: MapConfig.appId,
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in pins) _pinMarker(p),
                        if (_me != null) _meMarker(_me!),
                      ],
                    ),
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse('https://openstreetmap.org/copyright'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ----- buttons on the right -----
                Positioned(
                  top: topPad + 12,
                  right: 12,
                  child: Column(
                    children: [
                      if (MapConfig.showFullScreenButton &&
                          widget.onToggleFullScreen != null)
                        _MapButton(
                          icon: widget.fullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          tooltip: widget.fullScreen
                              ? 'Exit full screen'
                              : 'Full screen',
                          onTap: widget.onToggleFullScreen!,
                        ),
                      if (MapConfig.showZoomButtons) ...[
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          onTap: () => _zoom(1),
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onTap: () => _zoom(-1),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.location_city,
                        tooltip: 'Back to Valencia City',
                        onTap: _backToCity,
                      ),
                      if (MapConfig.showMyLocation) ...[
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.my_location,
                          tooltip: 'Find my location',
                          loading: _locating,
                          onTap: _findMe,
                        ),
                      ],
                    ],
                  ),
                ),

                // ----- legend (bottom right) -----
                if (MapConfig.showLegend)
                  const Positioned(bottom: 12, right: 12, child: _Legend()),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------- round white button ----------
class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool loading;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
                  )
                : Icon(icon, color: kTextDark, size: 22),
          ),
        ),
      ),
    );
  }
}

// ---------- small "what do the pins mean" box ----------
class _Legend extends StatelessWidget {
  const _Legend();

  Widget _row(Color color, IconData icon, String text, {bool square = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? BorderRadius.circular(4) : null,
            ),
            child: Icon(icon, size: 10, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, color: kTextDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MapConfig.showRequestPins) ...[
            _row(MapConfig.floodColor, Icons.water_drop, 'Flood'),
            _row(MapConfig.medicalColor, Icons.medical_services, 'Medical'),
            _row(MapConfig.fireColor, Icons.local_fire_department, 'Fire'),
          ],
          if (MapConfig.showEvacuationCenters)
            _row(MapConfig.centerColor, Icons.shield, 'Evacuation center',
                square: true),
        ],
      ),
    );
  }
}
