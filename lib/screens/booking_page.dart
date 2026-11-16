import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/blocked_date.dart';
import '../models/booking.dart';
import '../services/address_service.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import '../widgets/collapsible_invoice_card.dart';
import '../widgets/live_status_banner.dart';
import '../widgets/order_timeline_tracker.dart';
import '../widgets/rating_card.dart';
import 'edit_booking_page.dart';
import 'saved_addresses_page.dart';
import 'shop_selection_page.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key, this.createMode = false, this.focusBookingId});

  final bool createMode;
  final int? focusBookingId;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: createMode
            ? const _CreateBookingContent()
            : _BookingsContent(focusBookingId: focusBookingId),
      );
}

class BookingPageScaffold extends StatelessWidget {
  const BookingPageScaffold({super.key, this.focusBookingId});

  final int? focusBookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Your Bookings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: BookingPage(focusBookingId: focusBookingId),
    );
  }
}

class _BookingsContent extends StatefulWidget {
  const _BookingsContent({this.focusBookingId});

  final int? focusBookingId;

  @override
  State<_BookingsContent> createState() => _BookingsContentState();
}

class _BookingsContentState extends State<_BookingsContent> {
  final BookingService _bookingService = BookingService();

  static const int _historyLimit = 3;

  List<Booking>? _bookings;
  String? _error;
  bool _loading = true;
  bool _showAllHistory = false;
  Timer? _pollTimer;

  final Map<int, GlobalKey> _cardKeys = {};
  bool _hasHandledFocus = false;

  GlobalKey _keyFor(int bookingId) => _cardKeys.putIfAbsent(bookingId, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final bookings = await _bookingService.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
        _error = null;
      });
      _handleFocusIfNeeded();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _bookings == null) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _bookings == null) _error = 'Unable to load your bookings.';
      });
    }
  }

  void _handleFocusIfNeeded() {
    if (_hasHandledFocus || widget.focusBookingId == null) return;
    _hasHandledFocus = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[widget.focusBookingId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading && _bookings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _bookings == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.primaryLight),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      );
    }

    final bookings = _bookings ?? [];

    if (bookings.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 40, color: colors.primary),
          ),
          const SizedBox(height: 20),
          Text('No bookings yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text('Create your first booking using the + button.', textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
        ]),
      );
    }

    final active = bookings.where((b) => !b.status.isFinal).toList();
    final history = bookings.where((b) => b.status.isFinal).toList();

    final visibleHistory = _showAllHistory ? history : history.take(_historyLimit).toList();
    final hasMoreHistory = !_showAllHistory && history.length > _historyLimit;

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          if (active.isNotEmpty) ...[
            for (final booking in active) ...[
              _BookingCard(
                key: booking.id != null ? _keyFor(booking.id!) : null,
                booking: booking,
                onRefresh: () => _load(silent: true),
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (history.isNotEmpty) ...[
            if (active.isNotEmpty) const SizedBox(height: 6),
            Text('Booking history', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textSecondary)),
            const SizedBox(height: 12),
            for (final booking in visibleHistory) ...[
              _BookingCard(
                key: booking.id != null ? _keyFor(booking.id!) : null,
                booking: booking,
                onRefresh: () => _load(silent: true),
              ),
              const SizedBox(height: 16),
            ],
            if (hasMoreHistory)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAllHistory = true),
                  icon: Icon(Icons.expand_more_rounded, color: colors.primary),
                  label: Text(
                    'See previous bookings (${history.length - visibleHistory.length})',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Isang booking card, TOP / MID / BOTTOM na disenyo:
///   TOP    — LiveStatusBanner (+ "Edit" affordance habang Awaiting
///            Approval pa lang — see _canEdit below)
///   MID    — OrderTimelineTracker (buong vertical stepper, kasama na
///            ngayon ang Payment node/modal trigger)
///   BOTTOM — CollapsibleInvoiceCard, Edit/Cancel buttons, at (para sa
///            "Claimed" na booking) ang RatingCard
class _BookingCard extends StatefulWidget {
  const _BookingCard({super.key, required this.booking, required this.onRefresh});

  final Booking booking;
  final VoidCallback onRefresh;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  final BookingService _bookingService = BookingService();
  bool _cancelling = false;

  bool get _isCancellable =>
      widget.booking.status == BookingStatus.awaitingApproval || widget.booking.status == BookingStatus.pending;

  /// NEW (Flexible Booking — Edit Booking feature) — "Edit booking"
  /// lumalabas lang habang naghihintay pa ng Accept/Decline ang shop.
  /// Ito yung dating _canEdit sa order_tracking_page.dart — inilipat
  /// dito dahil OrderTrackingPage ay hindi na ginagamit ng navigation
  /// (booking_page.dart/BookingPageScaffold na ang tumatawag mula
  /// home_page.dart/booking_confirmation_page.dart/notifications), kaya
  /// dati walang lugar na makikita ang button na ito.
  bool get _canEdit => widget.booking.status == BookingStatus.awaitingApproval;

  /// NEW (Switch to Delivery) — "Change to delivery" lumalabas sa
  /// drop-off booking na nasa shop na ang laundry at pinal na ang
  /// presyo (Pending / In Progress / Ready). Hindi ito lalabas kung
  /// delivery na, o habang vine-verify pa ang bayad. Ang backend pa rin
  /// ang huling magpapasya (hal. kung walang delivery ang shop, ang
  /// mensahe nito ay ipapakita sa sheet).
  bool get _canSwitchToDelivery {
    final b = widget.booking;
    if (b.id == null) return false;
    if ((b.fulfillmentMode ?? 'dropoff') != 'dropoff') return false;
    if (b.paymentStatus == 'pending_verification') return false;
    return b.status == BookingStatus.pending ||
        b.status == BookingStatus.inProgress ||
        b.status == BookingStatus.ready;
  }

  Future<void> _openSwitchToDelivery() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryRequestSheet(booking: widget.booking),
    );
    if (done != true || !mounted) return;
    widget.onRefresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Delivery requested. The shop will assign a rider.'),
        backgroundColor: context.colors.neutral,
      ),
    );
  }

  /// NEW (Rating after order) — ipinapakita ang RatingCard kapag
  /// "Claimed" na ang booking (tapos na at kinuha na ang laundry). Ang
  /// card mismo ang nagpapasya kung form (hindi pa rated) o read-only
  /// na bituin (rated na) ang ipapakita.
  bool get _canRate => widget.booking.status == BookingStatus.claimed && widget.booking.id != null;

  /// NEW — opens EditBookingPage. Walang [Shop] object na ipinapasa
  /// dito dahil ang listahan ng bookings (getMyBookings()) ay hindi
  /// nagdadala ng buong shop detail per row — kaya ang EditBookingPage
  /// ay babalik sa read-only na display ng kasalukuyang payment method
  /// (see _buildPaymentSection doon: `if (widget.shop == null) ...`).
  /// Kung gusto mong ma-edit din ang payment method mula rito, kailangan
  /// muna nating i-fetch ang Shop detail base sa booking.shopId bago
  /// buksan ang page — sabihin mo lang kung priority ito.
  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditBookingPage(booking: widget.booking)),
    );
    if (!mounted) return;
    widget.onRefresh();
  }

  Future<void> _confirmAndCancel() async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          'This will cancel your ${widget.booking.serviceName} booking'
          '${widget.booking.shopName.isNotEmpty ? ' at ${widget.booking.shopName}' : ''}. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep booking')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await _bookingService.cancelBooking(widget.booking.id!);
      if (!mounted) return;
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Booking cancelled.'), backgroundColor: colors.neutral),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: colors.error));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Unable to cancel booking. Please try again.'), backgroundColor: colors.error),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Hero(
          tag: 'booking-${booking.id}-header',
          child: Material(
            color: Colors.transparent,
            child: LiveStatusBanner(booking: booking),
          ),
        ),

        const SizedBox(height: 14),

        // MID — full vertical timeline, kasama na ang Payment node +
        // modal trigger (see OrderTimelineTracker).
        OrderTimelineTracker(booking: booking, onRefresh: widget.onRefresh),

        const SizedBox(height: 14),

        CollapsibleInvoiceCard(booking: booking),

        // NEW (Rating after order) — "Rate your experience" para sa
        // Claimed na booking. Pagkatapos mag-submit, nagre-refresh ang
        // listahan (onRefresh) para dumating ang hasRated mula sa backend.
        if (_canRate) ...[
          const SizedBox(height: 12),
          RatingCard(booking: booking, onSubmitted: widget.onRefresh),
        ],

        // NEW (Switch to Delivery) — para sa drop-off booking na
        // nasa shop na ang laundry.
        if (_canSwitchToDelivery) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openSwitchToDelivery,
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Change to delivery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],

        // BOTTOM — Edit / Cancel actions. Kapag pareho silang
        // applicable (parehong "Awaiting Approval" ang kondisyon),
        // magkatabi sila sa isang Row; kapag Edit lang o Cancel lang,
        // buong-lapad na button na lang.
        if (_canEdit || _isCancellable) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (_canEdit) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_isCancellable) const SizedBox(width: 10),
              ],
              if (_isCancellable)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _confirmAndCancel,
                    icon: _cancelling
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.error))
                        : const Icon(Icons.close_rounded, size: 16),
                    label: Text(_cancelling ? 'Cancelling...' : 'Cancel booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.errorBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CreateBookingContent extends StatelessWidget {
  const _CreateBookingContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create booking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Choose a shop to see their available services and book directly from the shop page.',
          style: TextStyle(color: colors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopSelectionPage())),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Browse shops'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}


/// NEW (Switch to Delivery) — bottom sheet: pumili ng saved address at
/// (opsyonal) preferred na petsa ng hatid, tapos kumpirmahin. Nagpa-pop
/// ng `true` kapag nagtagumpay ang request.
class _DeliveryRequestSheet extends StatefulWidget {
  const _DeliveryRequestSheet({required this.booking});

  final Booking booking;

  @override
  State<_DeliveryRequestSheet> createState() => _DeliveryRequestSheetState();
}

class _DeliveryRequestSheetState extends State<_DeliveryRequestSheet> {
  final BookingService _bookingService = BookingService();
  final AddressService _addressService = AddressService();
  final ShopService _shopService = ShopService();

  List<Address>? _addresses;
  bool _loadingAddresses = true;
  String? _addressError;
  int? _selectedAddressId;

  BlockedDateSet _blockedDates = const BlockedDateSet.empty();
  DateTime? _deliveryDate;

  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadBlockedDates();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _addressError = null;
    });
    try {
      final addresses = await _addressService.getMyAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loadingAddresses = false;
        if (_selectedAddressId == null && addresses.length == 1) {
          _selectedAddressId = addresses.first.id;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAddresses = false;
        _addressError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAddresses = false;
        _addressError = 'Unable to load your saved addresses.';
      });
    }
  }

  Future<void> _loadBlockedDates() async {
    final shopId = widget.booking.shopId;
    if (shopId == null) return;
    try {
      final items = await _shopService.getBlockedDates(shopId);
      if (!mounted) return;
      setState(() => _blockedDates = BlockedDateSet(items));
    } catch (_) {
      // Silent — ang backend pa rin ang magre-reject ng fully booked na petsa.
    }
  }

  Future<void> _openAddAddress() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
    );
    if (!mounted) return;
    await _loadAddresses();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 60));
    final initial = _deliveryDate != null && !_blockedDates.isBlocked(_deliveryDate!)
        ? _deliveryDate!
        : _blockedDates.firstSelectable(firstDate, lastDate);

    if (initial == null) {
      setState(() => _errorMessage = 'No available delivery dates in the next 60 days.');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => !_blockedDates.isBlocked(day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _deliveryDate = picked;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedAddressId == null) {
      setState(() => _errorMessage = 'Please select a delivery address.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await _bookingService.requestDelivery(
        bookingId: widget.booking.id!,
        addressId: _selectedAddressId!,
        // 12:00 PM local para hindi tumawid sa ibang araw sa conversion.
        deliveryDatetime: _deliveryDate == null
            ? null
            : DateTime(_deliveryDate!.year, _deliveryDate!.month, _deliveryDate!.day, 12),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Unable to request delivery. Please try again.';
      });
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Change to delivery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Have your laundry delivered instead of picking it up. The shop\'s delivery fee '
              'may be added to your total, and this can\'t be changed back to drop-off.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text('Delivery address',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 8),
            _buildAddresses(colors),
            const SizedBox(height: 16),
            Text('Preferred delivery date (optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _submitting ? null : _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _deliveryDate == null ? 'Any day the shop is available' : _formatDate(_deliveryDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: _deliveryDate == null ? colors.textSecondary : colors.textPrimary,
                        ),
                      ),
                    ),
                    if (_deliveryDate != null)
                      GestureDetector(
                        onTap: _submitting ? null : () => setState(() => _deliveryDate = null),
                        child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            if (!_blockedDates.isEmpty) ...[
              const SizedBox(height: 6),
              Text("Fully booked dates can't be selected.",
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.errorBorder),
                ),
                child: Text(_errorMessage!, style: TextStyle(fontSize: 12.5, color: colors.error)),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm delivery', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
              child: Text('Keep as drop-off', style: TextStyle(color: colors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddresses(AppColors colors) {
    if (_loadingAddresses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_addressError != null) {
      return Row(
        children: [
          Expanded(child: Text(_addressError!, style: TextStyle(fontSize: 12, color: colors.error))),
          TextButton(onPressed: _loadAddresses, child: const Text('Retry')),
        ],
      );
    }

    final addresses = _addresses ?? const <Address>[];

    return Column(
      children: [
        for (final address in addresses) ...[
          InkWell(
            onTap: _submitting ? null : () => setState(() => _selectedAddressId = address.id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: address.id == _selectedAddressId ? colors.chipBg : colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: address.id == _selectedAddressId ? colors.primary : colors.border,
                  width: address.id == _selectedAddressId ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    address.id == _selectedAddressId
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: address.id == _selectedAddressId ? colors.primary : colors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address.label,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(address.addressLine,
                            style: TextStyle(fontSize: 12, height: 1.35, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: _submitting ? null : _openAddAddress,
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
                Text('Add new address',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}