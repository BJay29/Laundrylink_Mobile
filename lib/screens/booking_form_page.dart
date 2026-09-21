import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';

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

  final _quantityController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();
  final _promoController = TextEditingController();

  String _fulfillmentMode = 'dropoff'; // 'dropoff' | 'delivery'
  DateTime? _pickupDatetime;
  final Set<int> _selectedAddOnIds = {};

  /// NEW (Payment Method selector) — 'cash' | 'online_qr'. Defaults to
  /// 'cash' always, regardless of whether the shop supports online
  /// payment, so the form is always submittable even before the user
  /// touches this field.
  String _paymentMethod = 'cash';

  bool _submitting = false;
  String? _errorMessage;

  /// Whether this shop has set up their QR code — the "shop control
  /// toggle" from the spec. If the shop hasn't uploaded a QR
  /// (Shop.qr_code_url is null), only "Cash on Counter" is offered;
  /// "Online Payment (QR Ph)" is hidden entirely rather than shown
  /// disabled, since there'd be nothing to scan even if selected.
  bool get _onlinePaymentAvailable => widget.shop.qrCodeUrl != null;

  @override
  void dispose() {
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
        addOnIds: _selectedAddOnIds.toList(),
        promoCode: _promoController.text,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;

      final colors = context.colors;
      Navigator.pop(context, booking);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Booking request sent! Waiting for the shop to accept.'),
          backgroundColor: colors.success,
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
                        ? () => setState(() => _fulfillmentMode = 'delivery')
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

            // --- NEW: Payment Method selector — positioned directly
            // above the promo code field and the price summary, per
            // spec §1. Respects the shop's QR toggle: if the shop
            // hasn't uploaded a QR code, "Online Payment (QR Ph)" is
            // not rendered at all, only "Cash on Counter".
            const SizedBox(height: 20),
            const _FieldLabel('Payment Method'),
            _PaymentMethodSelector(
              selected: _paymentMethod,
              onlineAvailable: _onlinePaymentAvailable,
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            if (!_onlinePaymentAvailable) ...[
              const SizedBox(height: 6),
              Text(
                'This shop currently only accepts cash payments.',
                style: TextStyle(fontSize: 11.5, color: colors.textMuted),
              ),
            ],

            const SizedBox(height: 20),
            const _FieldLabel('Promo code (optional)'),
            TextFormField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(context, hint: 'e.g. WELCOME10'),
            ),

            const SizedBox(height: 24),
            _PriceSummary(
              basePrice: widget.service.price * _quantity,
              addOnsTotal: _addOnsTotal,
              deliveryFee: _deliveryFee,
              total: _estimatedSubtotal,
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

/// NEW — Payment Method selection block (spec §1). Two choices:
/// "Cash on Counter" ('cash') and "Online Payment (QR Ph)"
/// ('online_qr'). The online option is entirely omitted (not just
/// disabled) when [onlineAvailable] is false, since the shop hasn't
/// configured a QR to pay into.
class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.onlineAvailable,
    required this.onChanged,
  });

  final String selected;
  final bool onlineAvailable;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentOptionTile(
            label: 'Cash on Counter',
            icon: Icons.payments_outlined,
            selected: selected == 'cash',
            onTap: () => onChanged('cash'),
          ),
        ),
        if (onlineAvailable) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _PaymentOptionTile(
              label: 'Online Payment (QR Ph)',
              icon: Icons.qr_code_2,
              selected: selected == 'online_qr',
              onTap: () => onChanged('online_qr'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = selected ? colors.primary : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.border),
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
          ],
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

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.basePrice,
    required this.addOnsTotal,
    required this.deliveryFee,
    required this.total,
  });
  final double basePrice;
  final double addOnsTotal;
  final double deliveryFee;
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
          const SizedBox(height: 4),
          Text(
            'Promo discount, if any, is applied when your request is submitted.',
            style: TextStyle(fontSize: 10.5, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double value) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
          Text('₱${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textSecondary)),
        ],
      ),
    );
  }
}