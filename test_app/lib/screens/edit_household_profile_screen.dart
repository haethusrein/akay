import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart' show showComingSoon;
import '../main.dart';
import 'screen_widgets.dart';

const _barangays = <String>[
  'Barangay Bagontaas',
  'Barangay Batangan',
  'Barangay Colonia',
  'Barangay Lumbo',
  'Barangay Mailag',
  'Barangay Poblacion',
];

const _mobilityNeeds = <String>[
  'None',
  'Wheelchair required',
  'Bedridden',
  'Oxygen tank',
  'Needs carrying / stretcher',
  'Infant or young child',
  'Other',
];

/// Lets the signed-in resident edit the existing household record. The exact
/// saved map location is preserved because this form does not move the pin.
class EditHouseholdProfileScreen extends StatefulWidget {
  const EditHouseholdProfileScreen({super.key});

  @override
  State<EditHouseholdProfileScreen> createState() =>
      _EditHouseholdProfileScreenState();
}

class _EditHouseholdProfileScreenState extends State<EditHouseholdProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _members = TextEditingController();
  final _notes = TextEditingController();
  String? _barangay;
  String? _mobility;
  GeoPoint? _location;
  bool _loading = true;
  bool _saving = false;
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await AkayBackend.myHousehold().first;
      final data = snapshot.data();
      if (data == null) throw 'No household profile was found.';
      final point = data['location'];
      if (point is! GeoPoint) throw 'The household location is missing.';
      _name.text = (data['name'] ?? '').toString();
      _address.text = (data['address'] ?? '').toString();
      _members.text = (data['members'] ?? 1).toString();
      final notes = data['notes'];
      _notes.text = notes is List ? notes.join('\n') : '';
      _barangay = _barangays.contains(data['barangay'])
          ? data['barangay'] as String
          : null;
      _mobility = _mobilityNeeds.contains(data['mobilityNeed'])
          ? data['mobilityNeed'] as String
          : 'None';
      _location = point;
      _didLoad = true;
    } catch (error) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final point = _location;
    if (point == null || _barangay == null || _mobility == null) return;
    setState(() => _saving = true);
    try {
      final notes = _notes.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (notes.length > 20) throw 'Use no more than 20 responder notes.';
      if (notes.any((line) => line.length > 200)) {
        throw 'Each responder note must be 200 characters or fewer.';
      }
      await AkayBackend.saveHousehold(
        name: _name.text.trim(),
        barangay: _barangay!,
        address: _address.text.trim(),
        lat: point.latitude,
        lng: point.longitude,
        members: int.parse(_members.text.trim()),
        mobilityNeed: _mobility!,
        notes: notes,
      );
      if (!mounted) return;
      showComingSoon(context, 'Household profile saved.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _members.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AkayScreen(
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }
    if (!_didLoad) {
      return const AkayScreen(
        child: StatusBanner(
          tone: BannerTone.danger,
          icon: Icons.error_outline,
          message: 'The household profile could not be loaded.',
        ),
      );
    }

    return AkayScreen(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle(
              label: 'HOUSEHOLD SETTINGS',
              title: 'Edit household profile',
              subtitle: 'Keep these details and responder notes up to date.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Household name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a household name.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              value: _barangay,
              decoration: const InputDecoration(labelText: 'Barangay'),
              items: [
                for (final value in _barangays)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) => setState(() => _barangay = value),
              validator: (value) => value == null ? 'Choose your barangay.' : null,
            ),
            TextFormField(
              controller: _address,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Home address'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your address.'
                  : null,
            ),
            TextFormField(
              controller: _members,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Household members'),
              validator: (value) {
                final n = int.tryParse(value ?? '');
                return n == null || n < 1 || n > 50
                    ? 'Enter a number from 1 to 50.'
                    : null;
              },
            ),
            DropdownButtonFormField<String>(
              value: _mobility,
              decoration: const InputDecoration(labelText: 'Mobility or assistance need'),
              items: [
                for (final value in _mobilityNeeds)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) => setState(() => _mobility = value),
            ),
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Additional notes for responders',
                hintText: 'One note per line, such as oxygen tank or needs help using stairs.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            StatusBanner(
              tone: BannerTone.success,
              icon: Icons.location_on_outlined,
              message:
                  'Saved map pin retained (${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}).',
            ),
            const SizedBox(height: 16),
            SolidAction(label: 'Save household profile', loading: _saving, onPressed: _save),
            const SizedBox(height: 10),
            OutlineAction(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
