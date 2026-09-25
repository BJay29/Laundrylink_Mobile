import 'dart:async';
import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/shop.dart';
import '../services/address_service.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';
import 'booking_confirmation_page.dart';
import 'saved_addresses_page.dart';

/// Dedicated booking form page — opened after tapping "Book" on a
/// service in ShopDetailPage. Collects everything CustomerBookingCreate
/// needs (see app/schemas.py) and submits to POST /bookings/customer.
class BookingFormPage extends StatefulWidget {
  const BookingFormPage({super.key, required this.shop, required this.service});

  final Shop shop;
  final ShopServiceItem service;

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final BookingService _bookingService = BookingService();
  final AddressService _addressService = AddressService();

  final _quantityController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();
  final _promoController = TextEditingController();

  String _fulfillmentMode = 'dropoff'; // 'dropoff' | 'delivery'
  DateTime? _pickupDatetime;
  final Set<int> _selectedAddOnIds = {};

  List<Address>? _addresses;
  bool _loadingAddresses = false;
  String? _addressLoadError;
  int? _selectedAddressId;

  String _paymentMethod = 'cash';

  bool _submitting = false;
  String? _errorMessage;

  // --- NEW (Real-time Promo Preview feature) ---
  /// Result of the last successful/attempted preview call, or null if
  /// no code has been checked yet. Drives the live discount row in
  /// _PriceSummary.
  Map<String, dynamic>? _promoPreview;
  bool _checkingPromo = false;
  Timer? _promoDebounce;

  /// Whether this shop has set up their QR code — the "shop control
  /// toggle" from the spec. When false, "Online Payment" is still
  /// SHOWN (per the redesign) but rendered disabled with an inline
  /// explanation, rather than hidden outright — so the customer always
  /// sees the full set of possible payment methods, not a shrinking
  /// list that depends on shop configuration.
  bool get _onlinePaymentAvailable => widget.shop.qrCodeUrl != null;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_scheduleQuantityRecheck);
  }

  @override
  void dispose() {
    _promoDebounce?.cancel();
    _quantityController.dispose();
    _instructionsController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  String get _quantityLabel {
    switch (widget.service.pricingUnit) {
      case 'kg':
        return 'Weight (kg)';
      case 'piece':
        return 'Number of pieces';
      default:
        return 'Number of loads';
    }
  }

  double get _quantity => double.tryParse(_quantityController.text.trim()) ?? 0;

  double get _addOnsTotal => widget.shop.addOns
      .where((a) => _selectedAddOnIds.contains(a.id))
      .fold(0.0, (sum, a) => sum + a.price);

  double get _deliveryFee => _fulfillmentMode == 'delivery' ? widget.shop.deliveryFee : 0.0;

  double get _estimatedSubtotal => (widget.service.price * _quantity) + _addOnsTotal + _deliveryFee;

  /// NEW (Real-time Promo Preview) — discount amount from the last
  /// successful preview, 0 if none checked / invalid / cleared.
  double get _previewDiscount {
    if (_promoPreview == null || _promoPreview!['valid'] != true) return 0.0;
    return (_promoPreview!['discount_amount'] as num?)?.toDouble() ?? 0.0;
  }

  double get _estimatedTotalAfterPromo => (_estimatedSubtotal - _previewDiscount).clamp(0, double.infinity);

  void _syncPaymentMethodForFulfillment() {
    if (_fulfillmentMode == 'delivery' && _paymentMethod == 'cash') {
      _paymentMethod = 'cod';
    } else if (_fulfillmentMode == 'dropoff' && _paymentMethod == 'cod') {
      _paymentMethod = 'cash';
    }
  }

  /// NEW (Real-time Promo Preview feature) — quantity/add-ons/delivery
  /// changes shift the subtotal, which the discount amount (for a
  /// percent-based code) depends on — so re-check whenever they change
  /// and a code is already present, same debounce as typing the code.
  void _scheduleQuantityRecheck() {
    if (_promoController.text.trim().isNotEmpty) {
      _schedulePromoCheck();
    }
  }

  /// NEW (Real-time Promo Preview feature) — debounced call to
  /// POST /bookings/promo-preview, exactly the flow the backend was
  /// already built for (see PromoPreviewRequest/preview_promo_code()
  /// docstrings) but never wired up on this page until now.
  void _schedulePromoCheck() {
    _promoDebounce?.cancel();

    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _promoPreview = null;
        _checkingPromo = false;
      });
      return;
    }

    setState(() => _checkingPromo = true);

    _promoDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      try {
        final result = await _bookingService.previewPromoCode(
          shopId: widget.shop.id,
          code: code,
          subtotal: _estimatedSubtotal,
        );
        if (!mounted) return;
        // Guard against a stale response landing after the field has
        // since changed again.
        if (_promoController.text.trim() != code) return;
        setState(() {
          _promoPreview = result;
          _checkingPromo = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _promoPreview = null;
          _checkingPromo = false;
        });
      }
    });
  }

  Future<void> _ensureAddressesLoaded() async {
    if (_addresses != null || _loadingAddresses) return;

    setState(() {
      _loadingAddresses = true;
      _addressLoadError = null;
    });

    try {
      final addresses = await _addressService.getMyAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loadingAddresses = false;
        if (_selectedAddressId == null && addresses.isNotEmpty) {
          final defaults = addresses.where((a) => a.isDefault).toList();
          _selectedAddressId = defaults.isNotEmpty ? defaults.first.id : addresses.first.id;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAddresses = false;
        _addressLoadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAddresses = false;
        _addressLoadError = 'Unable to load your saved addresses.';
      });
    }
  }

  Future<void> _openAddAddress() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
    );
    if (!mounted) return;
    setState(() => _addresses = null);
    await _ensureAddressesLoaded();
  }

  Future<void> _pickPickupDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    setState(() {
      _pickupDatetime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_fulfillmentMode == 'delivery' && _pickupDatetime == null) {
      setState(() => _errorMessage = 'Please choose a pickup date and time for delivery.');
      return;
    }

    if (_fulfillmentMode == 'delivery' && _selectedAddressId == null) {
      setState(() => _errorMessage = 'Please select a delivery address.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final booking = await _bookingService.createBooking(
        shopId: widget.shop.id,
        shopName: widget.shop.shopName,
        serviceType: widget.service.name,
        quantity: _quantity,
        specialInstructions: _instructionsController.text,
        fulfillmentMode: _fulfillmentMode,
        pickupDatetime: _pickupDatetime,
        addressId: _fulfillmentMode == 'delivery' ? _selectedAddressId : null,
        addOnIds: _selectedAddOnIds.toList(),
        promoCode: _promoController.text,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BookingConfirmationPage(
            booking: booking,
            shop: widget.shop,
            onExit: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text('Book a service', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SectionCard(
              title: widget.service.name,
              subtitle: widget.shop.shopName,
              trailing: Text(
                '₱${widget.service.price.toStringAsFixed(0)} / ${widget.service.pricingUnit}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.primary),
              ),
            ),
            const SizedBox(height: 20),

            const _FieldLabel('Quantity'),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(context, hint: _quantityLabel),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) return 'Enter a valid ${_quantityLabel.toLowerCase()}.';
                return null;
              },
            ),

            const SizedBox(height: 20),
            const _FieldLabel('Fulfillment'),
            Row(
              children: [
                Expanded(
                  child: _ChoiceChipTile(
                    label: 'Drop-off',
                    icon: Icons.storefront_outlined,
                    selected: _fulfillmentMode == 'dropoff',
                    onTap: () => setState(() {
                      _fulfillmentMode = 'dropoff';
                      _pickupDatetime = null;
                      _syncPaymentMethodForFulfillment();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoiceChipTile(
                    label: 'Delivery',
                    icon: Icons.local_shipping_outlined,
                    selected: _fulfillmentMode == 'delivery',
                    enabled: widget.shop.hasDelivery,
                    onTap: widget.shop.hasDelivery
                        ? () {
                            setState(() {
                              _fulfillmentMode = 'delivery';
                              _syncPaymentMethodForFulfillment();
                            });
                            _ensureAddressesLoaded();
                          }
                        : null,
                  ),
                ),
              ],
            ),
            if (!widget.shop.hasDelivery) ...[
              const SizedBox(height: 6),
              Text(
                'This shop does not offer delivery.',
                style: TextStyle(fontSize: 11.5, color: colors.textMuted),
              ),
            ],

            if (_fulfillmentMode == 'delivery') ...[
              const SizedBox(height: 16),
              const _FieldLabel('Pickup date & time'),
              InkWell(
                onTap: _pickPickupDateTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        _pickupDatetime == null
                            ? 'Select pickup date & time'
                            : _formatDateTime(_pickupDatetime!),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _pickupDatetime == null ? colors.textMuted : colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.shop.deliveryFee > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Delivery fee: ₱${widget.shop.deliveryFee.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                ),
              ],

              const SizedBox(height: 16),
              const _FieldLabel('Delivery address'),
              _AddressSelector(
                loading: _loadingAddresses,
                error: _addressLoadError,
                addresses: _addresses ?? const [],
                selectedId: _selectedAddressId,
                onSelect: (id) => setState(() => _selectedAddressId = id),
                onAddNew: _openAddAddress,
                onRetry: () {
                  setState(() => _addressLoadError = null);
                  _ensureAddressesLoaded();
                },
              ),
            ],

            if (widget.shop.addOns.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _FieldLabel('Add-ons'),
              ...widget.shop.addOns.map(
                (addOn) => _AddOnCheckboxTile(
                  addOn: addOn,
                  selected: _selectedAddOnIds.contains(addOn.id),
                  onChanged: (checked) => setState(() {
                    if (checked) {
                      _selectedAddOnIds.add(addOn.id);
                    } else {
                      _selectedAddOnIds.remove(addOn.id);
                    }
                    _scheduleQuantityRecheck();
                  }),
                ),
              ),
            ],

            const SizedBox(height: 20),
            const _FieldLabel('Special instructions (optional)'),
            TextFormField(
              controller: _instructionsController,
              maxLines: 3,
              decoration: _inputDecoration(context, hint: 'e.g. Please use fragrance-free detergent'),
            ),

            // --- Payment Method selector ---
            // UPDATED: "Online Payment" is now ALWAYS rendered — no
            // longer hidden when the shop hasn't set up a QR. Instead
            // it's shown disabled with an inline explanation, same
            // pattern used for the Service Terminal's rider-gated
            // "Weigh & Price" button. Selection only — no payment
            // happens on this page (settled later once the shop
            // confirms the final weight; see the note below).
            const SizedBox(height: 20),
            const _FieldLabel('Payment Method'),
            _PaymentMethodSelector(
              selected: _paymentMethod,
              fulfillmentMode: _fulfillmentMode,
              onlineAvailable: _onlinePaymentAvailable,
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'You\'re only choosing a method now — you\'ll settle payment once the shop confirms the final weight, from your Bookings page.',
                style: TextStyle(fontSize: 11.5, color: colors.textMuted),
              ),
            ),
            if (!_onlinePaymentAvailable) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: colors.textMuted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'This shop hasn\'t set up online payments yet, so Online Payment is unavailable for now.',
                      style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            const _FieldLabel('Promo code (optional)'),
            TextFormField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(context, hint: 'e.g. WELCOME10').copyWith(
                suffixIcon: _checkingPromo
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : (_promoPreview != null && _promoPreview!['valid'] == true)
                        ? Icon(Icons.check_circle_rounded, color: colors.success)
                        : null,
              ),
              onChanged: (_) => _schedulePromoCheck(),
            ),
            // NEW (Real-time Promo Preview feature) — inline hint under
            // the field: green confirmation once valid, calm (not
            // scary) message when invalid, nothing while blank/typing.
            if (!_checkingPromo && _promoPreview != null) ...[
              const SizedBox(height: 6),
              if (_promoPreview!['valid'] == true)
                Text(
                  '"${_promoPreview!['code']}" applied — you save ₱${_previewDiscount.toStringAsFixed(2)}.',
                  style: TextStyle(fontSize: 11.5, color: colors.success, fontWeight: FontWeight.w600),
                )
              else if (_promoPreview!['message'] != null)
                Text(
                  _promoPreview!['message'] as String,
                  style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                ),
            ],

            const SizedBox(height: 24),
            _PriceSummary(
              basePrice: widget.service.price * _quantity,
              addOnsTotal: _addOnsTotal,
              deliveryFee: _deliveryFee,
              discount: _previewDiscount,
              total: _estimatedTotalAfterPromo,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.errorBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12.5, color: colors.error, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Send booking request', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The shop will need to accept your request before it starts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {required String hint}) {
    final colors = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.error),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$minute $period';
  }
}

class _AddressSelector extends StatelessWidget {
  const _AddressSelector({
    required this.loading,
    required this.error,
    required this.addresses,
    required this.selectedId,
    required this.onSelect,
    required this.onAddNew,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final List<Address> addresses;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddNew;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.errorBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(error!, style: TextStyle(fontSize: 12, color: colors.error)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (addresses.isEmpty) {
      return InkWell(
        onTap: onAddNew,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.primary, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_location_alt_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Add a delivery address',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.primary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final address in addresses) ...[
          _AddressTile(
            address: address,
            selected: address.id == selectedId,
            onTap: () => onSelect(address.id),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: onAddNew,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Add new address',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address, required this.selected, required this.onTap});

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? colors.primary : colors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(address.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: colors.successBg, borderRadius: BorderRadius.circular(20)),
                          child: Text('Default', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: colors.success)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(address.addressLine, style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UPDATED (payment method redesign): "Online Payment" is now always
/// rendered, never removed from the layout — when unavailable it's
/// simply disabled (greyed out, no onTap), so the customer always sees
/// the full set of methods the shop could support instead of the list
/// silently shrinking.
class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.fulfillmentMode,
    required this.onlineAvailable,
    required this.onChanged,
  });

  final String selected;
  final String fulfillmentMode;
  final bool onlineAvailable;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDelivery = fulfillmentMode == 'delivery';
    final cashLikeValue = isDelivery ? 'cod' : 'cash';
    final cashLikeLabel = isDelivery ? 'Cash on Delivery (COD)' : 'Cash on Counter';
    final cashLikeIcon = isDelivery ? Icons.local_shipping_outlined : Icons.payments_outlined;

    return Row(
      children: [
        Expanded(
          child: _PaymentOptionTile(
            label: cashLikeLabel,
            icon: cashLikeIcon,
            selected: selected == cashLikeValue,
            enabled: true,
            onTap: () => onChanged(cashLikeValue),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PaymentOptionTile(
            label: 'Online Payment (QR Ph)',
            icon: Icons.qr_code_2,
            selected: selected == 'online_qr',
            enabled: onlineAvailable,
            onTap: onlineAvailable ? () => onChanged('online_qr') : null,
          ),
        ),
      ],
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool isActive = selected && enabled;
    final Color activeColor = !enabled ? colors.textMuted : (isActive ? colors.primary : colors.textSecondary);

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isActive ? colors.chipBg : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? colors.primary : colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: activeColor),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: activeColor),
              ),
              if (!enabled) ...[
                const SizedBox(height: 3),
                Text(
                  'Not set up yet',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.trailing});
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
      );
}

class _ChoiceChipTile extends StatelessWidget {
  const _ChoiceChipTile({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color activeColor = !enabled ? colors.textMuted : (selected ? colors.primary : colors.textSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: activeColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: activeColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOnCheckboxTile extends StatelessWidget {
  const _AddOnCheckboxTile({required this.addOn, required this.selected, required this.onChanged});
  final AddOnItem addOn;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? colors.primary : colors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(addOn.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            ),
            Text('+₱${addOn.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// UPDATED (Real-time Promo Preview feature) — now shows a live
/// discount row and a recalculated total the moment a valid promo code
/// is confirmed, instead of only applying at submit time.
class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.basePrice,
    required this.addOnsTotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
  });
  final double basePrice;
  final double addOnsTotal;
  final double deliveryFee;
  final double discount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _row(context, 'Service', basePrice),
          if (addOnsTotal > 0) _row(context, 'Add-ons', addOnsTotal),
          if (deliveryFee > 0) _row(context, 'Delivery fee', deliveryFee),
          if (discount > 0) _row(context, 'Promo discount', -discount, highlight: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: colors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimated total', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              Text('₱${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double value, {bool highlight = false}) {
    final colors = context.colors;
    final color = highlight ? colors.success : colors.textSecondary;
    final sign = value < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: color, fontWeight: highlight ? FontWeight.w700 : FontWeight.normal)),
          Text(
            '$sign₱${value.abs().toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}