import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'rider_documents.dart';

/// Shown once, after a delivery partner's first login: the store needs
/// their date of birth, permanent address, driving licence and Aadhaar
/// card before they take orders.
class RiderDocumentsScreen extends ConsumerStatefulWidget {
  const RiderDocumentsScreen({super.key});

  @override
  ConsumerState<RiderDocumentsScreen> createState() =>
      _RiderDocumentsScreenState();
}

class _RiderDocumentsScreenState extends ConsumerState<RiderDocumentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _licence = TextEditingController();
  final _aadhaar = TextEditingController();
  DateTime? _dob;
  String? _licencePhoto;
  String? _aadhaarPhoto;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _licence.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec',
  ];

  static String formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      // Only adults can be delivery partners.
      lastDate: DateTime(
        now.year - RiderDocuments.minimumAge,
        now.month,
        now.day,
      ),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pick(String name, {required bool camera}) async {
    try {
      final path = await ref
          .read(riderDocumentsRepositoryProvider)
          .pickPhoto(name, camera: camera);
      if (path == null || !mounted) return;
      setState(() {
        if (name == 'licence') {
          _licencePhoto = path;
        } else {
          _aadhaarPhoto = path;
        }
      });
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Could not open the photo. Try again.');
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    final dob = _dob;
    final licence = _licencePhoto;
    final aadhaar = _aadhaarPhoto;
    if (!valid || dob == null || licence == null || aadhaar == null) {
      setState(
        () => _error = dob == null
            ? 'Choose your date of birth.'
            : licence == null || aadhaar == null
                ? 'Add a photo of both documents.'
                : null,
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final phone = await ref.read(riderPhoneProvider.future);
      await ref.read(riderDocumentsRepositoryProvider).submit(
            phone,
            RiderDocuments(
              dateOfBirth: dob,
              address: _address.text.trim(),
              licenceNumber: _licence.text.trim().toUpperCase(),
              aadhaarNumber: _aadhaar.text.replaceAll(RegExp(r'\s'), ''),
            ),
            licencePhotoPath: licence,
            aadhaarPhotoPath: aadhaar,
          );
      ref.invalidate(riderDocumentsProvider);
    } on Exception {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not send your documents. Check the signal and '
              'try again.';
        });
      }
    }
  }

  Widget _photoTile(String name, String title, String? path) {
    final added = path != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: added ? AppColors.successSoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: added ? AppColors.success : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                added ? Icons.check_circle_rounded : Icons.badge_outlined,
                color: added ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  added ? '$title photo added' : 'Photo of $title',
                  key: ValueKey('$name-photo-state'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('$name-camera'),
                  onPressed: _saving ? null : () => _pick(name, camera: true),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('$name-gallery'),
                  onPressed:
                      _saving ? null : () => _pick(name, camera: false),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dob = _dob;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
        actions: [
          TextButton(
            key: const ValueKey('documents-logout'),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            key: const ValueKey('rider-documents-form'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'Before your first order, the store needs these details. '
                'Only the store can see them.',
                style: TextStyle(height: 1.4, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              InkWell(
                key: const ValueKey('dob-field'),
                onTap: _saving ? null : _pickDob,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    dob == null ? 'Tap to choose' : formatDate(dob),
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          dob == null ? AppColors.textMuted : AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('address-field'),
                controller: _address,
                maxLines: 3,
                maxLength: 200,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().length < 10
                    ? 'Enter your full permanent address'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Permanent address',
                  hintText: 'House, street, area, city, pincode',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('licence-field'),
                controller: _licence,
                maxLength: 20,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v ?? '').trim().length < 8
                    ? 'Enter your driving licence number'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Driving licence number',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              _photoTile('licence', 'driving licence', _licencePhoto),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('aadhaar-field'),
                controller: _aadhaar,
                keyboardType: TextInputType.number,
                maxLength: 14,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                ],
                validator: RiderDocuments.aadhaarProblem,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar number',
                  hintText: '12 digits',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              _photoTile('aadhaar', 'Aadhaar card', _aadhaarPhoto),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    key: const ValueKey('documents-error'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('submit-documents-button'),
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Sending…' : 'Submit'),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
