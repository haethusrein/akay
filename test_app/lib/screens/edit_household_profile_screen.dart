import 'package:flutter/material.dart';
// Import your AkayBackend / Firestore helper here
// import '../services/akay_backend.dart';

class EditHouseholdProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const EditHouseholdProfileScreen({
    super.key,
    required this.currentData,
  });

  @override
  State<EditHouseholdProfileScreen> createState() =>
      _EditHouseholdProfileScreenState();
}

class _EditHouseholdProfileScreenState
    extends State<EditHouseholdProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _membersController;
  late String _mobilityNeed;
  bool _saving = false;

  static const _mobilityOptions = [
    'None',
    'Wheelchair',
    'Crutches / Walker',
    'Bedridden',
    'Medical Equipment (Oxygen, etc.)',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentData['householdName']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.currentData['phone']?.toString() ?? '',
    );
    _addressController = TextEditingController(
      text: widget.currentData['address']?.toString() ?? '',
    );
    _membersController = TextEditingController(
      text: widget.currentData['memberCount']?.toString() ?? '1',
    );
    final savedNeed = widget.currentData['mobilityNeed']?.toString();
    _mobilityNeed = _mobilityOptions.contains(savedNeed)
        ? savedNeed!
        : _mobilityOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final updated = {
        'householdName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'memberCount': int.tryParse(_membersController.text.trim()) ?? 1,
        'mobilityNeed': _mobilityNeed,
      };

      // TODO: Wire this to your existing Firestore/AkayBackend update method:
      // await AkayBackend.updateHouseholdProfile(updated);

      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Household Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Household Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address / Barangay'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _membersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Household Members'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mobilityNeed,
              decoration: const InputDecoration(
                labelText: 'Mobility or Equipment Needs',
              ),
              items: _mobilityOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _mobilityNeed = v);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _saveChanges,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}