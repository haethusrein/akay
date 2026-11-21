import 'package:flutter/material.dart';

import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Update evacuation status (wireframe 08)
// "Where is your household now?"  Still here / In transit / Evacuated
//
// UI only. TODO(backend): save the chosen status to the household
// (and queue it for sync when offline). There is no backend method yet.
// ============================================================
class EvacuationStatusScreen extends StatefulWidget {
  const EvacuationStatusScreen({super.key});

  @override
  State<EvacuationStatusScreen> createState() => _EvacuationStatusScreenState();
}

// (title, description, icon)
const _options = [
  ('Still here', 'We remain at our registered home', Icons.home_outlined),
  ('In transit', 'We are traveling to safety', Icons.alt_route),
  ('Evacuated', 'We arrived at a safe location', Icons.shield_outlined),
];

class _EvacuationStatusScreenState extends State<EvacuationStatusScreen> {
  int _selected = 0;

  void _confirm() {
    // TODO(backend): save _options[_selected].$1 as the household's status.
    showComingSoon(
      context,
      'Status set to "${_options[_selected].$1}". (Not saved to the server yet.)',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'EVACUATION STATUS',
            title: 'Where is your household now?',
            subtitle: 'Choose carefully. Responders use this status to plan assistance.',
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selected = i),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selected == i ? kLightGreen : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selected == i ? kGreen : kBorder,
                      width: _selected == i ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconBox(
                        icon: _options[i].$3,
                        bg: kLightGreen,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _options[i].$1,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(_options[i].$2, style: kGreyText),
                          ],
                        ),
                      ),
                      Icon(
                        _selected == i
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _selected == i ? kGreen : kHintGrey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          const StatusBanner(
            tone: BannerTone.warning,
            icon: Icons.warning_amber_rounded,
            message:
                "Confirm the whole household's status. A wrong update could cause responders to miss someone.",
          ),
          const SizedBox(height: 20),
          SolidAction(
            label: 'Confirm "${_options[_selected].$1}"',
            onPressed: _confirm,
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Cancel without changing',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Updates are saved offline and synced when possible.',
              style: kGreyText,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

