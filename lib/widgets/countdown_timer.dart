import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _kNeonBlue = Color(0xFF00B8FF);

/// Self-contained "In Progress" countdown widget (spec §4).
///
/// Computes the remaining time LOCALLY using
/// `targetTime.difference(DateTime.now())` on a `Timer.periodic(1s)`
/// tick — no repeated network polling. Displays "MM:SS", with a
/// continuously pulsing neon-blue glow (BoxShadow blur/spread
/// animation) to mimic a live washing-machine drum cycle.
///
/// Once the countdown hits zero, the timer is cancelled and the label
/// switches to "Cycles Complete - Wrapping Up...".
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({super.key, required this.targetTime});

  /// The estimated completion time (booking.estimatedCompletionTime),
  /// already in local time or UTC — DateTime.difference() works
  /// correctly either way since both sides of the subtraction must
  /// just be consistent, and DateTime.now() is local.
  final DateTime targetTime;

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
      // DESTRUCTOR CYCLE HANG GUARD — stop the loop the instant we hit
      // zero, never let it tick into negative durations.
      timer.cancel();
      return;
    }

    setState(() => _remaining = remaining);
  }

  @override
  void didUpdateWidget(covariant CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a fresh Realtime push brings a NEW target time (e.g. staff
    // re-assigned a machine), restart the local loop against the new
    // target rather than keep counting down the stale one.
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
    // Required lifecycle guard — never leave a Timer.periodic running
    // past this widget's life, or it keeps firing setState() on a
    // disposed State and crashes.
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String get _formatted {
    if (_isComplete) return 'Cycles Complete - Wrapping Up...';
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowStrength = _isComplete ? 0.0 : (0.25 + _glowController.value * 0.35);
        final blur = _isComplete ? 0.0 : (10 + _glowController.value * 14);
        final spread = _isComplete ? 0.0 : (1 + _glowController.value * 3);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kNeonBlue.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: _kNeonBlue.withOpacity(glowStrength),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.local_laundry_service_rounded,
                color: _isComplete ? Colors.grey : _kNeonBlue,
                size: 26,
              ),
              const SizedBox(height: 10),
              Text(
                _isComplete ? 'Almost Done' : 'Washing In Progress',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatted,
                style: TextStyle(
                  fontSize: _isComplete ? 15 : 32,
                  fontWeight: FontWeight.bold,
                  color: _isComplete ? Colors.grey.shade700 : const Color(0xFF0091EA),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}