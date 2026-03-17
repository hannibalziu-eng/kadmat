import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadmat/src/core/app_theme.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/utils/error_handler.dart';
import 'package:kadmat/src/core/widgets/kadmat_toast.dart';
import 'package:kadmat/src/features/bidding/presentation/providers/waitlist_provider.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/countdown_timer.dart';
import 'package:kadmat/src/features/bidding/domain/entities/waitlist_entity.dart';

class WaitlistOfferScreen extends ConsumerStatefulWidget {
  final String waitlistId;

  const WaitlistOfferScreen({super.key, required this.waitlistId});

  @override
  ConsumerState<WaitlistOfferScreen> createState() =>
      _WaitlistOfferScreenState();
}

class _WaitlistOfferScreenState extends ConsumerState<WaitlistOfferScreen> {
  bool _isAccepting = false;
  bool _isDeclining = false;
  Timer? _expiryCheckTimer;

  @override
  void initState() {
    super.initState();
    // Check expiry every second
    _expiryCheckTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkExpiry(),
    );
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    super.dispose();
  }

  void _checkExpiry() {
    final offerAsync = ref.read(waitlistOfferStreamProvider);
    offerAsync.whenData((offer) {
      if (offer == null || offer.isExpired) {
        _handleExpiry();
      }
    });
  }

  void _handleExpiry() {
    if (mounted) {
      KadmatToast.showInfo(
        context,
        title: 'انتهى الوقت',
        message: 'انتهت صلاحية العرض',
      );
      context.pop();
    }
  }

  Future<void> _acceptOffer() async {
    setState(() => _isAccepting = true);

    try {
      await ref.read(waitlistActionsProvider).acceptOffer(widget.waitlistId);

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم بنجاح',
          message: 'تم قبول العرض',
        );
        context.go(AppRoutes.technicianHome);
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: ErrorHandler.getMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _declineOffer() async {
    setState(() => _isDeclining = true);

    try {
      await ref.read(waitlistActionsProvider).declineOffer(widget.waitlistId);

      if (mounted) {
        KadmatToast.showInfo(
          context,
          title: 'تم الرفض',
          message: 'تم رفض العرض',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: ErrorHandler.getMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeclining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offerAsync = ref.watch(waitlistOfferStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('عرض عاجل!'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: offerAsync.when(
        data: (offer) {
          if (offer == null) {
            return const Center(
              child: Text(
                'لا يوجد عروض متاحة',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Countdown Timer
                if (offer.expiresAt != null)
                  CountdownTimer(
                    endsAt: offer.expiresAt!,
                    onExpired: _handleExpiry,
                    onExtend: () {}, // Not allowed for waitlist
                    canExtend: false,
                  ),

                const SizedBox(height: 24),

                // Offer Details Card
                _buildOfferCard(offer),

                const SizedBox(height: 32),

                // Accept Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isAccepting || _isDeclining
                        ? null
                        : _acceptOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isAccepting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'قبول العرض',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Decline Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isAccepting || _isDeclining
                        ? null
                        : _declineOffer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isDeclining
                        ? const CircularProgressIndicator(color: Colors.red)
                        : const Text('رفض', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.getMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(WaitlistEntity offer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'تفاصيل العرض',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildDetailRow(
            'رقم الترتيب',
            '#${offer.rank}',
            Icons.format_list_numbered,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'السعر المقترح',
            '${offer.amount.toStringAsFixed(0)} د.ل',
            Icons.monetization_on,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أنت في قائمة الانتظار. قبول العرض يعني التزامك بإنجاز المهمة.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
