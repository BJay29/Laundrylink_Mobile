import 'dart:async';
import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/blocked_date.dart';
import '../models/shop.dart';
import '../services/address_service.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import '../widgets/time_window_selector.dart';
import 'booking_confirmation_page.dart';
import 'saved_addresses_page.dart';

/// Dedicated booking form page — opened after tapping "Book" on a
/// service in ShopDetailPage. Collects everything CustomerBookingCreate
/// needs (see app/schemas.py) and submits to POST /bookings/customer.
///
/// UPDATED (Flexible Booking feature): dinagdagan ng OPTIONAL na time
/// window chips (Morning/Afternoon/Evening/Anytime) sa ilalim ng
/// exact-time field, pareho para sa preferred drop-off at delivery
/// pickup. Independiyente ito sa exact date/time — pwedeng meron
/// window nang walang exact time, o pareho, o wala man lang.
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
  final ShopService _shopService = ShopService();

  /// NEW (Fully Booked dates) — mga petsang fully booked ng shop. Hindi
  /// mapipili sa date picker. Kung hindi ma-load, bakante lang (ang
  /// backend pa rin ang magre-reject).
  BlockedDateSet _blockedDates = const BlockedDateSet.empty();

  final _quantityController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();
  final _promoController = TextEditingController();

  String _fulfillmentMode = 'dropoff'; // 'dropoff' | 'delivery'
  DateTime? _pickupDatetime;

  /// Optional preferred drop-off time (dropoff mode lang).
  DateTime? _dropoffDatetime;

  /// NEW (Flexible Booking feature) — optional time window labels,
  /// independiyente sa exact *_datetime sa itaas.
  String? _dropoffWindow;
  String? _pickupWindow;

  final Set<int> _selectedAddOnIds = {};

  List<Address>? _addresses;
  bool _loadingAddresses = false;
  String? _addressLoadError;
  int? _selectedAddressId;

  String _paymentMethod = 'cash';

  bool _submitting = false;
  String? _errorMessage;

  /// Result of the last successful/attempted promo preview call, or
  /// null if no code has been checked yet. Drives the live discount row
  /// in _PriceSummary.
  Map<String, dynamic>? _promoPreview;
  bool _checkingPromo = false;
  Timer? _promoDebounce;

  /// Kailangan PAREHO: naka-ON ang "Online Payment" toggle ng shop
  /// (Shop.acceptsOnline) AT may na-upload nang QR.
  bool get _onlinePaymentAvailable => widget.shop.acceptsOnline && widget.shop.qrCodeUrl != null;

  /// Magkaibang paliwanag depende kung ALIN sa dalawang kondisyon ang
  /// kulang.
  String? get _onlinePaymentUnavailableReason {
    if (_onlinePaymentAvailable) return null;
    if (!widget.shop.acceptsOnline) {
      return 'This shop currently only accepts cash payments.';
    }
    return "This shop hasn't uploaded their QR code yet, so Online Payment is unavailable for now.";
  }

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_scheduleQuantityRecheck);
    _loadBlockedDates();
  }

  Future<void> _loadBlockedDates() async {
    try {
      final items = await _shopService.getBlockedDates(widget.shop.id);
      if (!mounted) return;
      setState(() => _blockedDates = BlockedDateSet(items));
    } catch (_) {
      // Tahimik lang — backend guard pa rin ang huling depensa.
    }
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

  /// Discount amount from the last successful preview, 0 if none
  /// checked / invalid / cleared.
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

  /// Quantity/add-ons/delivery changes shift the subtotal, which the
  /// discount amount (for a percent-based code) depends on — so
  /// re-check whenever they change and a code is already present.
  void _scheduleQuantityRecheck() {
    if (_promoController.text.trim().isNotEmpty) {
      _schedulePromoCheck();
    }
  }

  /// Debounced call to POST /bookings/promo-preview.
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

  /// Shared date → time picker, ginagamit ng pickup (delivery) at
  /// drop-off (optional). Nagbabalik ng null kung na-cancel.
  Future<DateTime?> _pickDateTime() async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 30));

    // Ang initialDate ay DAPAT puwedeng piliin (hindi fully booked).
    final initialDate = _blockedDates.firstSelectable(now.add(const Duration(hours: 1)), lastDate);
    if (initialDate == null) {
      setState(() => _errorMessage =
          'This shop is fully booked for the next 30 days. Please try again later or contact the shop.');
      return null;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: lastDate,
      // Naka-grey at hindi mapipili ang mga fully booked na petsa.
      selectableDayPredicate: (day) => !_blockedDates.isBlocked(day),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickPickupDateTime() async {
    final picked = await _pickDateTime();
    if (picked == null || !mounted) return;
    setState(() => _pickupDatetime = picked);
  }

  Future<void> _pickDropoffDateTime() async {
    final picked = await _pickDateTime();
    if (picked == null || !mounted) return;
    setState(() => _dropoffDatetime = picked);
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

    // Optional field, pero kung nilagyan, dapat hindi lumipas ang oras.
    if (_fulfillmentMode == 'dropoff' &&
        _dropoffDatetime != null &&
        _dropoffDatetime!.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'Your preferred drop-off time has already passed. Please pick a later time.');
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
        pickupDatetime: _fulfillmentMode == 'delivery' ? _pickupDatetime : null,
        dropoffDatetime: _fulfillmentMode == 'dropoff' ? _dropoffDatetime : null,
        dropoffWindow: _fulfillmentMode == 'dropoff' ? _dropoffWindow : null,
        pickupWindow: _fulfillmentMode == 'delivery' ? _pickupWindow : null,
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
            const SizedBox(height: 22),

            const _FieldLabel('Quantity'),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(context, hint: _quantityLabel, icon: Icons.scale_outlined),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) return 'Enter a valid ${_quantityLabel.toLowerCase()}.';
                return null;
              },
            ),

            const SizedBox(height: 22),
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
                      _pickupWindow = null;
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
                              // Drop-off time/window ay para sa
                              // drop-off lang.
                              _dropoffDatetime = null;
                              _dropoffWindow = null;
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

            // --- Preferred drop-off (optional, dropoff mode lang) ---
            if (_fulfillmentMode == 'dropoff') ...[
              const SizedBox(height: 18),
              const _FieldLabel('Preferred drop-off date & time (optional)'),
              _DateTimeField(
                value: _dropoffDatetime == null ? null : _formatDateTime(_dropoffDatetime!),
                placeholder: 'Select when you plan to drop off',
                icon: Icons.schedule_rounded,
                onTap: _pickDropoffDateTime,
                onClear: _dropoffDatetime == null ? null : () => setState(() => _dropoffDatetime = null),
              ),
              if (!_blockedDates.isEmpty) const _FullyBookedHint(),
              const SizedBox(height: 10),
              const _FieldLabel('Preferred time window (optional)'),
              TimeWindowSelector(
                selected: _dropoffWindow,
                onChanged: (v) => setState(() => _dropoffWindow = v),
              ),
              const SizedBox(height: 6),
              Text(
                'Just a heads-up for the shop — you can still drop off any time they\'re open.',
                style: TextStyle(fontSize: 11.5, color: colors.textMuted),
              ),
            ],

            if (_fulfillmentMode == 'delivery') ...[
              const SizedBox(height: 18),
              const _FieldLabel('Pickup date & time'),
              _DateTimeField(
                value: _pickupDatetime == null ? null : _formatDateTime(_pickupDatetime!),
                placeholder: 'Select pickup date & time',
                icon: Icons.event_outlined,
                onTap: _pickPickupDateTime,
              ),
              if (!_blockedDates.isEmpty) const _FullyBookedHint(),
              const SizedBox(height: 10),
              const _FieldLabel('Preferred time window (optional)'),
              TimeWindowSelector(
                selected: _pickupWindow,
                onChanged: (v) => setState(() => _pickupWindow = v),
              ),
              if (widget.shop.deliveryFee > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Delivery fee: ₱${widget.shop.deliveryFee.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                ),
              ],

              const SizedBox(height: 18),
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
              const SizedBox(height: 22),
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

            const SizedBox(height: 22),
            const _FieldLabel('Special instructions (optional)'),
            TextFormField(
              controller: _instructionsController,
              maxLines: 3,
              decoration: _inputDecoration(context, hint: 'e.g. Please use fragrance-free detergent'),
            ),

            // --- Payment Method selector (list-style redesign) ---
            const SizedBox(height: 22),
            const _FieldLabel('Payment Method'),
            _PaymentMethodSelector(
              selected: _paymentMethod,
              fulfillmentMode: _fulfillmentMode,
              onlineAvailable: _onlinePaymentAvailable,
              onlineUnavailableReason: _onlinePaymentUnavailableReason,
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: colors.textMuted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'You\'re only choosing a method now — you\'ll settle payment once the shop confirms the final weight, from your Bookings page.',
                      style: TextStyle(fontSize: 11.5, color: colors.textMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            const _FieldLabel('Promo code (optional)'),
            TextFormField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(context, hint: 'e.g. WELCOME10', icon: Icons.local_offer_outlined).copyWith(
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
            // Inline hint under the field: green confirmation once
            // valid, calm message when invalid, nothing while blank.
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

            const SizedBox(height: 26),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: colors.primary.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
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

  InputDecoration _inputDecoration(BuildContext context, {required String hint, IconData? icon}) {
    final colors = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
      prefixIcon: icon == null ? null : Icon(icon, size: 19, color: colors.textSecondary),
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
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

/// NEW (Fully Booked dates) — maliit na paalala sa ilalim ng date field
/// kapag may mga petsang fully booked ang shop.
class _FullyBookedHint extends StatelessWidget {
  const _FullyBookedHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_rounded, size: 13, color: colors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              "Fully booked dates can't be selected.",
              style: TextStyle(fontSize: 11.5, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable tappable date/time row, ginagamit ng pickup (delivery) at
/// preferred drop-off. May optional [onClear] na nagpapakita ng X
/// button kapag may napili na.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValue = value != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasValue ? colors.primary : colors.border),
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: hasValue ? colors.textPrimary : colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasValue && onClear != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
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
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: colors.chipBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_location_alt_rounded, size: 18, color: colors.primary),
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
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(color: colors.primary.withOpacity(0.16), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
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

/// Vertical list ng payment rows: colored icon badge sa kaliwa,
/// method name + subtitle sa gitna, radio indicator (o "Unavailable"
/// pill) sa kanan.
class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.fulfillmentMode,
    required this.onlineAvailable,
    required this.onlineUnavailableReason,
    required this.onChanged,
  });

  final String selected;
  final String fulfillmentMode;
  final bool onlineAvailable;
  final String? onlineUnavailableReason;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDelivery = fulfillmentMode == 'delivery';
    final cashLikeValue = isDelivery ? 'cod' : 'cash';
    final cashLikeLabel = isDelivery ? 'Cash on Delivery' : 'Cash on Counter';
    final cashLikeSubtitle = isDelivery ? 'Pay the rider when your order arrives' : 'Pay in person when you drop off/pick up';
    final cashLikeIcon = isDelivery ? Icons.local_shipping_rounded : Icons.payments_rounded;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _PaymentRow(
            label: cashLikeLabel,
            subtitle: cashLikeSubtitle,
            icon: cashLikeIcon,
            iconColor: colors.success,
            iconBg: colors.successBg,
            selected: selected == cashLikeValue,
            enabled: true,
            onTap: () => onChanged(cashLikeValue),
          ),
          Divider(height: 1, thickness: 1, color: colors.border, indent: 16, endIndent: 16),
          _PaymentRow(
            label: 'Online Payment',
            subtitle: onlineAvailable ? 'Pay securely via QR (GCash, Maya, banks)' : (onlineUnavailableReason ?? 'Not available for this shop'),
            icon: Icons.qr_code_2_rounded,
            iconColor: colors.primary,
            iconBg: colors.chipBg,
            selected: selected == 'online_qr',
            enabled: onlineAvailable,
            onTap: onlineAvailable ? () => onChanged('online_qr') : null,
          ),
        ],
      ),
    );
  }
}

/// A single row inside the payment method list — icon badge, label +
/// subtitle, and a trailing radio/status indicator.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool isActive = selected && enabled;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: isActive ? colors.chipBg.withOpacity(0.55) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? iconBg : colors.neutralBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: enabled ? iconColor : colors.textMuted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: enabled ? colors.textPrimary : colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.neutralBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Unavailable',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: colors.neutral),
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? colors.primary : Colors.transparent,
                      border: Border.all(color: isActive ? colors.primary : colors.border, width: 1.6),
                    ),
                    child: isActive
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : null,
                  ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.local_laundry_service_rounded, color: colors.primary, size: 22),
          ),
          const SizedBox(width: 14),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(color: colors.primary.withOpacity(0.16), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: activeColor),
            const SizedBox(height: 7),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(16),
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

/// Live discount row and recalculated total the moment a valid promo
/// code is confirmed, instead of only applying at submit time.
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.chipBg.withOpacity(0.4)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          _row(context, 'Service', basePrice),
          if (addOnsTotal > 0) _row(context, 'Add-ons', addOnsTotal),
          if (deliveryFee > 0) _row(context, 'Delivery fee', deliveryFee),
          if (discount > 0) _row(context, 'Promo discount', -discount, highlight: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: colors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimated total', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              Text('₱${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.primary)),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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