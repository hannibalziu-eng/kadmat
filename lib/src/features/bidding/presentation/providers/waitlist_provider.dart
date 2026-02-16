import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/waitlist_model.dart';
import '../../domain/entities/waitlist_entity.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/presentation/job_controller.dart';
import 'bidding_providers.dart';

/// Stream active waitlist offer for current technician
final waitlistOfferStreamProvider = StreamProvider<WaitlistEntity?>((ref) {
  // Watch auth state changes to trigger rebuilds
  ref.watch(authStateChangesProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) return Stream.value(null);

  final supabase = Supabase.instance.client;

  return supabase
      .from('bid_waitlist')
      .stream(primaryKey: ['id'])
      .eq('technician_id', userId)
      .order('created_at', ascending: false)
      .map((data) {
        // Client-side filtering as stream() with eq() might be limited in some versions
        // or just to be safe. Actually .eq() is supported in recent versions.
        final offered = data
            .where((element) => element['status'] == 'offered')
            .toList();

        if (offered.isEmpty) return null;
        return WaitlistModel.fromJson(offered.first).toEntity();
      });
});

/// Provider for waitlist actions (accept/decline)
final waitlistActionsProvider = Provider((ref) => WaitlistActions(ref));

class WaitlistActions {
  final Ref _ref;

  WaitlistActions(this._ref);

  Future<void> acceptOffer(String waitlistId) async {
    final repository = _ref.read(biddingRepositoryProvider);
    final result = await repository.acceptWaitlistOffer(waitlistId);

    result.fold((failure) => throw Exception(failure.message), (_) {
      // Invalidate streams to refresh data
      _ref.invalidate(waitlistOfferStreamProvider);
      _ref.invalidate(myJobsProvider);
    });
  }

  Future<void> declineOffer(String waitlistId) async {
    final supabase = Supabase.instance.client;

    await supabase
        .from('bid_waitlist')
        .update({'status': 'declined'})
        .eq('id', waitlistId);

    _ref.invalidate(waitlistOfferStreamProvider);
  }
}
