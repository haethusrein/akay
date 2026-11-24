// ============================================================
// AKAY - MAP SETTINGS  (change things HERE, not in the other map files)
//
// Every value has a comment saying what it does.
// After you edit one, press "r" in the terminal running `flutter run`
// (hot reload) or just save the file in VS Code.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

class MapConfig {
  MapConfig._();

  // ---------- 1. WHERE the map starts ----------
  /// Middle of Valencia City, Bukidnon (latitude, longitude).
  static const LatLng center = LatLng(7.9064, 125.0942);

  /// How close the map starts. Bigger = closer. 13 shows most of the city.
  static const double startZoom = 13;

  /// Furthest OUT and furthest IN the person can zoom (0 = world, 18 = street).
  static const double minZoom = 12;
  static const double maxZoom = 18;

  /// true  = the map cannot be dragged away from Valencia City.
  /// false = the person can scroll anywhere.
  static const bool limitToCity = true;

  /// The box the map is kept inside when limitToCity is true.
  /// First point = bottom-left corner, second = top-right corner.
  static final LatLngBounds cityBounds = LatLngBounds(
    const LatLng(7.70, 124.90),
    const LatLng(8.12, 125.30),
  );

  // ---------- 2. HOW BIG the map is ----------
  /// Size of the map inside the Community tab, as a part of the screen height.
  /// 0.70 = 70%, so the top bar and the bottom navigation stay visible.
  /// Try 0.5 for a smaller map, 0.8 for a bigger one.
  static const double panelHeightFraction = 0.70;

  // ---------- 3. WHAT is shown (true = on, false = off) ----------
  static const bool showRequestPins = true; //       red/blue/orange help-request pins
  static const bool showEvacuationCenters = true; // green shield pins
  static const bool showMyLocation = true; //        "find me" button + blue dot
  static const bool showZoomButtons = true; //       + and - buttons
  static const bool showFullScreenButton = true; //  expand / close button
  static const bool showLegend = true; //            the small "what do pins mean" box
  static const bool allowRotate = false; //          two-finger twist to rotate

  // ---------- 4. WHICH map pictures (tiles) ----------
  /// OpenStreetMap, free. Other free styles can be pasted here later.
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Must be your app id (it is in android/app/build.gradle.kts as applicationId).
  /// OpenStreetMap asks apps to send this.
  static const String appId = 'com.akay.akay';

  // ---------- 5. PIN colors and names ----------
  static const Color floodColor = Color(0xFF2F80C9);
  static const Color medicalColor = Color(0xFFD9473F);
  static const Color fireColor = Color(0xFFE67E22);
  static const Color otherColor = Color(0xFF6B7A75);
  static const Color centerColor = Color(0xFF0F5C4D);
  static const Color meColor = Color(0xFF1A73E8);

  static Color colorForType(String type) {
    switch (type) {
      case 'flood':
        return floodColor;
      case 'medical':
        return medicalColor;
      case 'fire':
        return fireColor;
      default:
        return otherColor;
    }
  }

  static IconData iconForType(String type) {
    switch (type) {
      case 'flood':
        return Icons.water_drop;
      case 'medical':
        return Icons.medical_services;
      case 'fire':
        return Icons.local_fire_department;
      default:
        return Icons.priority_high;
    }
  }

  static String labelForType(String type) {
    switch (type) {
      case 'flood':
        return 'Flood request';
      case 'medical':
        return 'Medical request';
      case 'fire':
        return 'Fire request';
      default:
        return 'Help request';
    }
  }
}