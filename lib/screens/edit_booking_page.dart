import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/blocked_date.dart';
import '../models/booking.dart';
import '../models/shop.dart';
import '../services/address_service.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import '../widgets/time_window_selector.dart';
import 'saved_addresses_page.dart';

/// NEW (Flexible Booking — Edit Booking feature) — pinapayagan ang
/// customer na baguhin ang sarili niyang booking HABANG "Awaiting
/// Approval" pa lang (bago pa man tanggapin ng shop). Pagkatapos
/// tanggapin, hindi na maaaring i-edit — cancel na lang o makipag-ugnayan
/// sa shop.
///
/// [shop] ay optional — kung meron nito, alam natin kung available ba
/// ang Online Payment (shop.acceptsOnline + shop.qrCodeUrl), kaya
/// pwedeng payagan baguhin ang payment method. Kung wala/null, itinatago
/// na lang ang kasalukuyang payment method bilang read-only info.
///
/// Mga hindi maaaring baguhin dito: fulfillment mode, quantity, add-ons,
/// promo code — nakakaapekto ang mga ito sa presyo, at ang presyo ay
/// hawak na ng weighing/finalize flow ng shop.
///
/// UPDATED (timezone fix): `.toLocal()` ang ginagamit sa initial
/// datetimes at sa pag-format, para laging local time ng device ang
/// ipinapakita — kahit UTC ang dumating mula sa backend.
class EditBookingPage extends StatefulWidget {
  const EditBookingPage({super.key, required this.booking, this.shop});

  final Booking booking;
  final Shop? shop;

  @override
  State<EditBookingPage> createState() => _EditBookingPageState();
}

class _EditBookingPageState extends State<EditBookingPage> {
  final BookingService _bookingService = BookingService();
  final AddressService _addressService = AddressService();
  final ShopService _shopService = ShopService();

  /// NEW (Fully Booked dates) — hindi mapipili sa date picker.
  BlockedDateSet _blockedDates = const BlockedDateSet.empty();

  late final TextEditingController _instructionsController;

  bool get _isDelivery => widget.booking.fulfillmentMode == 'delivery';
  bool get _isEditable => widget.booking.status == BookingStatus.awaitingApproval;

  DateTime? _dropoffDatetime;
  String? _dropoffWindow;

  DateTime? _pickupDatetime;
  String? _pickupWindow;

  List<Address>? _addresses;
  bool _loadingAddresses = false;
  String? _addressLoadError;
  int? _selectedAddressId;

  late String _paymentMethod;

  bool _submitting = false;
  String? _errorMessage;

  bool get _onlinePaymentAvailable =>
      widget.shop != null && widget.shop!.acceptsOnline && widget.shop!.qrCodeUrl != null;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _instructionsController = TextEditingController(text: b.specialInstructions ?? '');
    _dropoffDatetime = b.dropoffDatetime?.toLocal();
    _dropoffWindow = b.dropoffWindow;
    _pickupDatetime = b.pickupDatetime?.toLocal();
    _pickupWindow = b.pickupWindow;
    _selectedAddressId = b.deliveryAddressId;
    _paymentMethod = b.paymentMethod ?? (_isDelivery ? 'cod' : 'cash');

    if (_isDelivery && _isEditable) {
      _loadAddresses();
    }
    if (_isEditable) {
      _loadBlockedDates();
    }
  }

  Future<void> _loadBlockedDates() async {
    final shopId = widget.shop?.id ?? widget.booking.shopId;
    if (shopId == null) return;
    try {
      final items = await _shopService.getBlockedDates(shopId);
      if (!mounted) return;
      setState(() => _blockedDates = BlockedDateSet(items));
    } catch (_) {
      // Tahimik lang — backend guard pa rin ang huling depensa.
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
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
    await _loadAddresses();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 30));

    final preferred = (initial != null && initial.isAfter(now)) ? initial : now.add(const Duration(hours: 1));
    // Ang initialDate ay DAPAT puwedeng piliin (hindi fully booked).
    final initialDate = _blockedDates.firstSelectable(preferred, lastDate);
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
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDropoffDateTime() async {
    final picked = await _pickDateTime(_dropoffDatetime);
    if (picked == null || !mounted) return;
    setState(() => _dropoffDatetime = picked);
  }

  Future<void> _pickPickupDateTime() async {
    final picked = await _pickDateTime(_pickupDatetime);
    if (picked == null || !mounted) return;
    setState(() => _pickupDatetime = picked);
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_isDelivery && _pickupDatetime == null) {
      setState(() => _errorMessage = 'Please choose a pickup date and time for delivery.');
      return;
    }
    if (_isDelivery && _pickupDatetime!.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'Your pickup time has already passed. Please pick a later time.');
      return;
    }
    if (_isDelivery && _selectedAddressId == null) {
      setState(() => _errorMessage = 'Please select a delivery address.');
      return;
    }
    if (!_isDelivery && _dropoffDatetime != null && _dropoffDatetime!.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'Your preferred drop-off time has already passed. Please pick a later time or clear it.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await _bookingService.updateBooking(
        bookingId: widget.booking.id!,
        // Cross-mode fields ay HINDI isinasama (nananatiling kUnset),
        // para hindi ito i-reject ng backend guard (delivery-only
        // field sa dropoff booking, atbp).
        dropoffDatetime: _isDelivery ? kUnset : _dropoffDatetime,
        dropoffWindow: _isDelivery ? kUnset : _dropoffWindow,
        pickupDatetime: _isDelivery ? _pickupDatetime : kUnset,
        pickupWindow: _isDelivery ? _pickupWindow : kUnset,
        addressId: _isDelivery ? _selectedAddressId : kUnset,
        specialInstructions: _instructionsController.text,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDateTime(DateTime value) {
    // FIXED (timezone): laging local time ng device ang ipinapakita.
    final dt = value.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$minute $period';
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
        title: Text('Edit booking', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: _isEditable ? _buildForm(colors) : _buildNotEditable(colors),
    );
  }

  /// Fallback kung sakaling ma-navigate dito ang isang booking na hindi
  /// na "Awaiting Approval" (hal. na-accept na ng shop habang bukas ang
  /// page na ito). Bihira, pero mas malinaw kaysa sa isang crash o
  /// silent na 400 error mula sa backend.
  Widget _buildNotEditable(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock_rounded, size: 44, color: colors.textMuted),
            const SizedBox(height: 14),
            Text(
              'This booking can no longer be edited',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'The shop has already accepted or updated this booking. You can cancel it or contact the shop directly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.chipBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can edit this booking until the shop accepts it.',
                  style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!_isDelivery) ...[
          const _FieldLabel('Preferred drop-off date & time (optional)'),
          _DateTimeRow(
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
        ],

        if (_isDelivery) ...[
          const _FieldLabel('Pickup date & time'),
          _DateTimeRow(
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
          const SizedBox(height: 20),
          const _FieldLabel('Delivery address'),
          _buildAddressSection(colors),
        ],

        const SizedBox(height: 20),
        const _FieldLabel('Special instructions (optional)'),
        TextFormField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Please use fragrance-free detergent',
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 1.5)),
          ),
        ),

        const SizedBox(height: 20),
        const _FieldLabel('Payment Method'),
        _buildPaymentSection(colors),

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
                  child: Text(_errorMessage!, style: TextStyle(fontSize: 12.5, color: colors.error, height: 1.4)),
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection(AppColors colors) {
    if (_loadingAddresses) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_addressLoadError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.errorBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.errorBorder)),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
            const SizedBox(width: 10),
            Expanded(child: Text(_addressLoadError!, style: TextStyle(fontSize: 12, color: colors.error))),
            TextButton(onPressed: _loadAddresses, child: const Text('Retry')),
          ],
        ),
      );
    }

    final addresses = _addresses ?? const [];

    return Column(
      children: [
        for (final address in addresses) ...[
          _AddressRow(
            address: address,
            selected: address.id == _selectedAddressId,
            onTap: () => setState(() => _selectedAddressId = address.id),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: _openAddAddress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text('Add new address', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection(AppColors colors) {
    // Kung walang Shop object (hindi ipinasa ng caller), hindi natin
    // masisiguro kung available ba ang Online Payment ngayon — sa
    // halip na payagang mag-guess ang UI, ipinapakita na lang natin
    // ang kasalukuyang paraan bilang read-only info.
    if (widget.shop == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.payments_outlined, size: 18, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Current method: ${_paymentMethodLabel(_paymentMethod)}. Open this from a shop page to change it.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final cashLikeValue = _isDelivery ? 'cod' : 'cash';
    final cashLikeLabel = _isDelivery ? 'Cash on Delivery' : 'Cash on Counter';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _PaymentOptionRow(
            label: cashLikeLabel,
            icon: _isDelivery ? Icons.local_shipping_rounded : Icons.payments_rounded,
            selected: _paymentMethod == cashLikeValue,
            enabled: true,
            onTap: () => setState(() => _paymentMethod = cashLikeValue),
          ),
          Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
          _PaymentOptionRow(
            label: 'Online Payment',
            icon: Icons.qr_code_2_rounded,
            selected: _paymentMethod == 'online_qr',
            enabled: _onlinePaymentAvailable,
            onTap: _onlinePaymentAvailable ? () => setState(() => _paymentMethod = 'online_qr') : null,
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String value) {
    switch (value) {
      case 'cod':
        return 'Cash on Delivery';
      case 'cash':
        return 'Cash on Counter';
      case 'online_qr':
        return 'Online Payment (QR)';
      default:
        return value;
    }
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

/// NEW (Fully Booked dates) — paalala sa ilalim ng date field.
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

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
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
                style: TextStyle(fontSize: 13.5, color: hasValue ? colors.textPrimary : colors.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
            if (hasValue && onClear != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.selected, required this.onTap});

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? colors.chipBg : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: selected ? colors.primary : colors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
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

class _PaymentOptionRow extends StatelessWidget {
  const _PaymentOptionRow({
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
    final isActive = selected && enabled;
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
                Icon(icon, size: 20, color: enabled ? (isActive ? colors.primary : colors.textSecondary) : colors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: enabled ? colors.textPrimary : colors.textMuted)),
                ),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: colors.neutralBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('Unavailable', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: colors.neutral)),
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? colors.primary : Colors.transparent,
                      border: Border.all(color: isActive ? colors.primary : colors.border, width: 1.6),
                    ),
                    child: isActive ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}