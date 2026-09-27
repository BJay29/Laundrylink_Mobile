// ============================= lib/pages/saved_addresses_page.dart =============================
import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  final AddressService _addressService = AddressService();

  List<Address>? _addresses;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await _addressService.getMyAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load your saved addresses.';
      });
    }
  }

  Future<void> _openAddressForm({Address? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressFormSheet(existing: existing, addressService: _addressService),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Address address) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete address'),
        content: Text('Remove "${address.label}" from your saved addresses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _addressService.deleteAddress(address.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: colors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Unable to delete address.'), backgroundColor: colors.error),
      );
    }
  }

  Future<void> _setDefault(Address address) async {
    if (address.isDefault) return;
    try {
      await _addressService.updateAddress(address.id, isDefault: true);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: context.colors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Unable to set default address.'), backgroundColor: context.colors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget body;
    final addresses = _addresses ?? [];

    if (_loading && _addresses == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _addresses == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.primaryLight),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    } else if (addresses.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 48, color: colors.primaryLight),
            const SizedBox(height: 12),
            Text('No saved addresses yet', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              'Add an address to use it for delivery bookings.',
              style: TextStyle(fontSize: 12.5, color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openAddressForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add address'),
              style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: addresses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final address = addresses[index];
            return _AddressCard(
              address: address,
              onEdit: () => _openAddressForm(existing: address),
              onDelete: () => _confirmDelete(address),
              onSetDefault: () => _setDefault(address),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: const Text('Saved addresses', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: body,
      floatingActionButton: addresses.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openAddressForm(),
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault ? colors.borderStrong : colors.border,
          width: 1.2,
        ),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
            child: Icon(
              address.label.toLowerCase() == 'work' ? Icons.work_outline_rounded : Icons.home_outlined,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(address.label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: colors.successBg, borderRadius: BorderRadius.circular(20)),
                        child: Text('Default', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.success)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(address.addressLine, style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4)),
                // NEW: kung galing GPS ang address na ito (may lat/lng),
                // ipinapakita ang maliit na "pin" indicator para malaman
                // ng user na exact-location ang pinagmulan nito.
                if (address.latitude != null && address.longitude != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.my_location_rounded, size: 11, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'From GPS location',
                        style: TextStyle(fontSize: 10.5, color: colors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (!address.isDefault)
                      TextButton(
                        onPressed: onSetDefault,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                        child: Text('Set as default', style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w700)),
                      ),
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                      child: Text('Edit', style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                      child: Text('Delete', style: TextStyle(fontSize: 12, color: colors.error, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({required this.existing, required this.addressService});
  final Address? existing;
  final AddressService addressService;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  late final TextEditingController _labelController;
  late final TextEditingController _addressController;
  bool _isDefault = false;
  bool _saving = false;
  String? _error;

  // NEW (GPS auto-fill feature): coordinates na "nakadikit" sa kasalukuyang
  // laman ng _addressController. Kapag manual na binago ng user ang text
  // matapos mag-GPS, kino-clear namin ito (tingnan sa _addressController
  // listener) para hindi ma-save ang lumang coordinates kasabay ng bagong
  // text na hindi na tugma dito.
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label ?? 'Home');
    _addressController = TextEditingController(text: widget.existing?.addressLine ?? '');
    _isDefault = widget.existing?.isDefault ?? false;
    _latitude = widget.existing?.latitude;
    _longitude = widget.existing?.longitude;

    _addressController.addListener(_onAddressManuallyEdited);
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressManuallyEdited);
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// NEW: kapag ni-type ng user ang sarili niyang address (hindi galing
  /// sa "Use my current location" fill), kino-clear ang naka-store na
  /// lat/lng para hindi maligaw ang naka-save na coordinates sa text na
  /// binago na niya.
  void _onAddressManuallyEdited() {
    if (_fetchingLocation) return; // habang kami mismo ang nagse-set ng text
    if (_latitude != null || _longitude != null) {
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
  }

  /// NEW (GPS auto-fill feature): pinaka-puso ng feature na hiniling mo —
  /// kinukuha ang GPS coordinates ng device, ino-reverse-geocode papunta
  /// sa readable address, tapos awtomatikong pinupuno ang address field.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _fetchingLocation = true;
      _error = null;
    });

    try {
      final resolved = await _locationService.getCurrentLocationWithAddress();
      if (!mounted) return;

      setState(() {
        _addressController.text = resolved.addressLine;
        _latitude = resolved.latitude;
        _longitude = resolved.longitude;
        _fetchingLocation = false;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _fetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: context.colors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _fetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to get your current location. Please try again.'),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.existing != null) {
        await widget.addressService.updateAddress(
          widget.existing!.id,
          label: _labelController.text.trim(),
          addressLine: _addressController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      } else {
        await widget.addressService.createAddress(
          label: _labelController.text.trim(),
          addressLine: _addressController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Unable to save this address. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(
                widget.existing != null ? 'Edit address' : 'Add address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
              const SizedBox(height: 16),

              // NEW (GPS auto-fill feature): "Use my current location"
              // button — pinaka-madaling paraan para awtomatikong mapunan
              // ang address field, bago pa man mag-type ang user.
              InkWell(
                onTap: _fetchingLocation ? null : _useCurrentLocation,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.chipBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_fetchingLocation)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        )
                      else
                        Icon(Icons.my_location_rounded, size: 17, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        _fetchingLocation ? 'Getting your location…' : 'Use my current location',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label (e.g. Home, Work)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Label is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  // NEW: maliit na "GPS-linked" indicator sa loob mismo ng
                  // field, para malinaw sa user kung galing GPS ang laman.
                  suffixIcon: (_latitude != null && _longitude != null)
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.gps_fixed_rounded, size: 18, color: colors.primary),
                        )
                      : null,
                ),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                title: const Text('Set as default address', style: TextStyle(fontSize: 13.5)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(color: colors.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.existing != null ? 'Save changes' : 'Add address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}