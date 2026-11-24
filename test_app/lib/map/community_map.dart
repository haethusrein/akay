// ============================================================
// AKAY - The two ways to view the map
//   CommunityMap   the 70% view that sits in the Community tab
//                  (top bar and bottom navigation stay visible)
//   MapFullScreen  the full-screen view (opens when you press the expand button)
// The size of the 70% view is MapConfig.panelHeightFraction.
// ============================================================
import 'package:flutter/material.dart';

import 'akay_map.dart';
import 'map_config.dart';

class CommunityMap extends StatelessWidget {
  const CommunityMap({super.key});

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MapFullScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.of(context).size.height * MapConfig.panelHeightFraction;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: AkayMap(onToggleFullScreen: () => _openFullScreen(context)),
      ),
    );
  }
}

class MapFullScreen extends StatelessWidget {
  const MapFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AkayMap(
        fullScreen: true,
        onToggleFullScreen: () => Navigator.of(context).pop(),
      ),
    );
  }
}
