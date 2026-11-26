import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart' show showComingSoon;
import '../main.dart';
import 'screen_widgets.dart';

/// Private emergency information the signed-in resident can keep with their
/// account. It is not automatically sent to responders with a help request.
class EmergencyInfoScreen extends StatefulWidget {
  const EmergencyInfoScreen({super.key});

  @override
  State<EmergencyInfoScreen> createState() => _EmergencyInfoScreenState();
}

class _EmergencyInfoScreenState extends State<EmergencyInfoScreen> {
  final _conditions = TextEditingController();
  final _medications = TextEditingController();
  final _allergies = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _instructions = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await AkayBackend.myEmergencyProfile().first;
      final data = snapshot.data();
      if (data != null) {
        _conditions.text = (data['conditions'] ?? '').toString();
        _medications.text = (data['medications'] ?? '').toString();
        _allergies.text = (data['allergies'] ?? '').toString();
        _contactName.text = (data['contactName'] ?? '').toString();
        _contactPhone.text = (data['contactPhone'] ?? '').toString();
        _instructions.text = (data['instructions'] ?? '').toString();
      }
      _loaded = true;
    } catch (error) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AkayBackend.saveEmergencyProfile(
        conditions: _conditions.text,
        medications: _medications.text,
        allergies: _allergies.text,
        contactName: _contactName.text,
        contactPhone: _contactPhone.text,
        instructions: _instructions.text,
      );
      if (!mounted) return;
      showComingSoon(context, 'Emergency information saved.');
    } catch (error) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _entry(
    TextEditingController controller,
    String label, {
    int maxLength = 500,
    int minLines = 1,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: controller,
    maxLength: maxLength,
    minLines: minLines,
    maxLines: minLines == 1 ? 1 : 4,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: minLines > 1,
    ),
    validator: (value) => (value?.length ?? 0) > maxLength
        ? 'Use $maxLength characters or fewer.'
        : null,
  );

  @override
  void dispose() {
    _conditions.dispose();
    _medications.dispose();
    _allergies.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AkayScreen(
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }
    if (!_loaded) {
      return const AkayScreen(
        child: StatusBanner(
          tone: BannerTone.danger,
          icon: Icons.error_outline,
          message: 'Emergency information could not be loaded.',
        ),
      );
    }

    return AkayScreen(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FloodAdvisoryBanner(),
            const SizedBox(height: 16),
            const ScreenTitle(
              label: 'YOUR SAFETY DETAILS',
              title: 'Emergency information',
              subtitle: 'Add the health and contact details you may need in an emergency.',
            ),
            const SizedBox(height: 16),
            const StatusBanner(
              tone: BannerTone.warning,
              icon: Icons.lock_outline,
              title: 'Private to your account',
              message:
                  'These details are saved to your account. They are not automatically shared with responders when you send a help request.',
            ),
            const SizedBox(height: 16),
            _entry(_conditions, 'Medical conditions', minLines: 2),
            _entry(_medications, 'Medications', minLines: 2),
            _entry(_allergies, 'Allergies', minLines: 2),
            _entry(_contactName, 'Emergency contact name', maxLength: 80),
            _entry(
              _contactPhone,
              'Emergency contact phone',
              maxLength: 24,
              keyboardType: TextInputType.phone,
            ),
            _entry(
              _instructions,
              'Other emergency details',
              minLines: 3,
            ),
            const SizedBox(height: 10),
            SolidAction(
              label: 'Save emergency information',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 10),
            OutlineAction(
              label: 'Done',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
