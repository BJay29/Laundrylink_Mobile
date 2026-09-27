import 'dart:async';

import 'package:flutter/material.dart';

const Color _kNeonBlue = Color(0xFF00B8FF);

/// Self-contained "In Progress" countdown widget.
///
/// Computes the remaining time LOCALLY using
/// `targetTime.difference(DateTime.now())` on a `Timer.periodic(1s)`
/// tick — no repeated network polling. Displays "MM:SS", with a
/// continuously pulsing neon-blue glow to mimic a live washing-machine
/// drum cycle.
///
/// UPDATED (Booking & Order Tracking Flow Fix): two changes —
///   1. Sizing reduced across the board (padding, icon, digit font,
///      glow radius) — the previous version was oversized for a card
///      embedded inside a timeline node.
///   2. Accepts an optional [phase] ("washing" | "drying") so the
///      label reflects what's actually happening — previously always
///      hardcoded to "Washing In Progress" even once a load had moved
///      to the dryer.
///
/// Once the countdown hits zero, the timer is cancelled and the label
/// switches to "Cycle Complete - Wrapping Up...".
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({super.key, required this.targetTime, this.phase});

  /// The estimated completion time (booking.estimatedCompletionTime).
  final DateTime targetTime;

  /// "washing" | "drying" | null (defaults to "washing" label if null).
  final String? phase;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isComplete = false;

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _remaining = widget.targetTime.difference(DateTime.now());
    _isComplete = _remaining.isNegative || _remaining == Duration.zero;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (!_isComplete) {
      _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    }
  }

  void _onTick(Timer timer) {
    final target = widget.targetTime.toLocal();
    final remaining = target.difference(DateTime.now());

    if (remaining.isNegative || remaining == Duration.zero) {
      setState(() {
        _remaining = Duration.zero;
        _isComplete = true;
      });
      timer.cancel();
      return;
    }

    setState(() => _remaining = remaining);
  }

  @override
  void didUpdateWidget(covariant CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a fresh push brings a NEW target time (e.g. staff moved this
    // load to the dryer, resetting the cycle), restart the local loop
    // against the new target rather than keep counting down the stale
    // one.
    if (oldWidget.targetTime != widget.targetTime) {
      _timer?.cancel();
      final remaining = widget.targetTime.difference(DateTime.now());
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
        _isComplete = remaining.isNegative || remaining == Duration.zero;
      });
      if (!_isComplete) {
        _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String get _formatted {
    if (_isComplete) return 'Cycle Complete';
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _label {
    if (_isComplete) return 'Wrapping up';
    final isDrying = widget.phase == 'drying';
    return isDrying ? 'Drying in progress' : 'Washing in progress';
  }

  IconData get _icon {
    final isDrying = widget.phase == 'drying';
    return isDrying ? Icons.dry_rounded : Icons.local_laundry_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowStrength = _isComplete ? 0.0 : (0.20 + _glowController.value * 0.25);
        final blur = _isComplete ? 0.0 : (6 + _glowController.value * 8);
        final spread = _isComplete ? 0.0 : (0.5 + _glowController.value * 1.5);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kNeonBlue.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: _kNeonBlue.withOpacity(glowStrength),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                color: _isComplete ? Colors.grey : _kNeonBlue,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                _formatted,
                style: TextStyle(
                  fontSize: _isComplete ? 12 : 18,
                  fontWeight: FontWeight.bold,
                  color: _isComplete ? Colors.grey.shade700 : const Color(0xFF0091EA),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}