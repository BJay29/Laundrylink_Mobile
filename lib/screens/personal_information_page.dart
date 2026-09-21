import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/api_service.dart';
import '../services/customer_service.dart';
import '../theme/app_colors.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key, required this.customer});
  final Customer customer;

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _mobileController;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.customer.fullName);
    _mobileController = TextEditingController(text: widget.customer.mobileNumber);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _fullNameController.text.trim() != widget.customer.fullName ||
      _mobileController.text.trim() != widget.customer.mobileNumber;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updated = await CustomerService().updateProfile(
        fullName: _fullNameController.text.trim() != widget.customer.fullName
            ? _fullNameController.text.trim()
            : null,
        mobileNumber: _mobileController.text.trim() != widget.customer.mobileNumber
            ? _mobileController.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: const Text('Personal information', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Full name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: colors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: colors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: colors.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Full name cannot be empty.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Mobile number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: colors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: colors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: colors.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Mobile number cannot be empty.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.customer.email ?? 'Not set',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Email cannot be changed here. Contact support if you need to update it.',
              style: TextStyle(fontSize: 11.5, color: colors.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}