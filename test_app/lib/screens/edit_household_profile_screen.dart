import 'package:flutter/material.dart';

import '../akay_backend.dart';

class EditHouseholdProfileScreen extends StatefulWidget {
  /// The caller passes the signed-in user profile. Its mobile number is shown
  /// read-only; account mobile changes are intentionally outside this screen.
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

  static const _mobilityOptions = [
    'None',
    'Wheelchair required',
    'Bedridden',
    'Oxygen tank',
    'Needs carrying / stretcher',
    'Infant or young child',
    'Other',
  ];

  String _mobilityNeed = 'None';
  bool _loading = true;
  bool _saving = false;
  bool _hasHousehold = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController(
      text: (widget.currentData['mobile'] ?? widget.currentData['phone'] ?? '')
          .toString(),
    );
    _addressController = TextEditingController();
    _membersController = TextEditingController(text: '1');
    _loadHousehold();
  }

  Future<void> _loadHousehold() async {
    try {
      final snapshot = await AkayBackend.myHousehold().first;
      final household = snapshot.data();
      if (!mounted) return;

      if (household != null) {
        _nameController.text = (household['name'] ?? '').toString();
        _addressController.text = (household['address'] ?? '').toString();
        _membersController.text = (household['members'] ?? 1).toString();
        final savedNeed = household['mobilityNeed']?.toString();
        _mobilityNeed = _mobilityOptions.contains(savedNeed)
            ? savedNeed!
            : 'None';
        _hasHousehold = true;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AkayBackend.friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a household name.';
    if (text.length > 80) return 'Use 80 characters or fewer.';
    return null;
  }

  String? _validateAddress(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the household address.';
    if (text.length > 200) return 'Use 200 characters or fewer.';
    return null;
  }

  String? _validateMembers(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count < 1 || count > 50) {
      return 'Enter a whole number from 1 to 50.';
    }
    return null;
  }

  Future<void> _saveChanges() async {
    if (_loading || !_hasHousehold || _saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await AkayBackend.updateHouseholdProfile(
        name: _nameController.text,
        address: _addressController.text,
        members: int.parse(_membersController.text.trim()),
        mobilityNeed: _mobilityNeed,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AkayBackend.friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Household Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasHousehold
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No household profile was found. Complete household setup first.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Household name',
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    readOnly: true,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Account mobile number',
                      helperText:
                          'This number is linked to sign-in and cannot be changed here.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Complete household address',
                    ),
                    validator: _validateAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _membersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Household members',
                    ),
                    validator: _validateMembers,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _mobilityNeed,
                    decoration: const InputDecoration(
                      labelText: 'Mobility or equipment needs',
                    ),
                    items: _mobilityOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _mobilityNeed = value);
                      }
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
