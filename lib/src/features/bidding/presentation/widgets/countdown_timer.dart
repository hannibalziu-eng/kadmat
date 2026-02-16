import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime endsAt;
  final VoidCallback onExpired;
  final VoidCallback onExtend;
  final bool canExtend;
  final bool isExtended;
  final DateTime Function()? now;

  const CountdownTimer({
    super.key,
    required this.endsAt,
    required this.onExpired,
    required this.onExtend,
    this.canExtend = true,
    this.isExtended = false,
    this.now,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _hasExpired = false;
  bool _hasWarned = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    // Initial calculation without side effects
    final currentTime = (widget.now ?? DateTime.now)();
    _remaining = widget.endsAt.difference(currentTime);

    // Check if we need to warn immediately, but schedule it
    if (_remaining.inMinutes <= 2 && !_hasWarned && !_hasExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateRemaining();
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (!mounted) return;

    setState(() {
      final currentTime = (widget.now ?? DateTime.now)();
      _remaining = widget.endsAt.difference(currentTime);

      if (_remaining.isNegative && !_hasExpired) {
        _hasExpired = true;
        _timer?.cancel();
        widget.onExpired();
      }

      // Warning at 2 minutes
      if (_remaining.inMinutes <= 2 && !_hasWarned && !_hasExpired) {
        _hasWarned = true;
        HapticFeedback.heavyImpact();
        _showWarning();
      }
    });
  }

  void _showWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '⚠️ تبقى دقيقتان فقط!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: widget.canExtend && !widget.isExtended
            ? SnackBarAction(
                label: 'تمديد 5 دق',
                textColor: Colors.white,
                onPressed: widget.onExtend,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remaining.inMinutes <= 2 && !_hasExpired;
    final isExpired = _hasExpired;
    final totalSeconds = 15 * 60;
    final elapsedSeconds =
        totalSeconds - _remaining.inSeconds.clamp(0, totalSeconds);
    final progress = elapsedSeconds / totalSeconds;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [Colors.grey[800]!, Colors.grey[600]!]
              : isUrgent
              ? [Colors.red[900]!, Colors.red[600]!]
              : [const Color(0xFF13b6ec), const Color(0xFF0e8cb5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red : const Color(0xFF13b6ec)).withValues(
              alpha: 0.3,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isExpired ? 'انتهى الوقت' : 'الوقت المتبقي للمناقصة',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_remaining),
            style: TextStyle(
              color: Colors.white,
              fontSize: isUrgent ? 56 : 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto Mono',
            ),
          ),
          const SizedBox(height: 20),
          if (!isExpired) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  isUrgent ? Colors.yellow : Colors.white,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.canExtend &&
                !widget.isExtended &&
                _remaining.inMinutes <= 5)
              TextButton.icon(
                onPressed: widget.onExtend,
                icon: const Icon(Icons.more_time, color: Colors.white),
                label: const Text(
                  'تمديد 5 دقائق',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
