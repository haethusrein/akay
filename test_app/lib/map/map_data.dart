// ============================================================
// AKAY - Where the map gets its pins from (Firestore).
// Only this file talks to the database for the map.
//   publicMarkers      -> help-request pins (rounded to ~1 km, no names)
//   evacuationCenters  -> green shield pins (you add these in the console)
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'map_config.dart';

/// One pin on the map.
class MapPin {
  final String id;
  final String kind; // 'flood' | 'medical' | 'fire' | 'other' | 'center'
  final String title;
  final LatLng point;

  const MapPin({
    required this.id,
    required this.kind,
    required this.title,
    required this.point,
  });
}

class MapData {
  MapData._();

  static final _db = FirebaseFirestore.instance;

  /// Live help-request pins (expired ones are skipped).
  static Stream<List<MapPin>> requestPins() {
    if (!MapConfig.showRequestPins) return Stream.value(const []);
    return _db.collection('publicMarkers').snapshots().map((snap) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pins = <MapPin>[];
      for (final d in snap.docs) {
        final x = d.data();
        final lat = x['lat'];
        final lng = x['lng'];
        if (lat is! num || lng is! num) continue;
        final exp = x['expiresAt'];
        if (exp is Timestamp && exp.millisecondsSinceEpoch < now) continue;
        final type = (x['type'] ?? 'other').toString();
        pins.add(
          MapPin(
            id: d.id,
            kind: type,
            title: MapConfig.labelForType(type),
            point: LatLng(lat.toDouble(), lng.toDouble()),
          ),
        );
      }
      return pins;
    });
  }

  /// Evacuation centers.
  static Stream<List<MapPin>> evacuationCenters() {
    if (!MapConfig.showEvacuationCenters) return Stream.value(const []);
    return _db.collection('evacuationCenters').snapshots().map((snap) {
      final pins = <MapPin>[];
      for (final d in snap.docs) {
        final x = d.data();
        final loc = x['location'];
        if (loc is! GeoPoint) continue;
        pins.add(
          MapPin(
            id: d.id,
            kind: 'center',
            title: (x['name'] ?? 'Evacuation center').toString(),
            point: LatLng(loc.latitude, loc.longitude),
          ),
        );
      }
      return pins;
    });
  }
}
