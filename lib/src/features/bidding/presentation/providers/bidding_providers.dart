import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadmat/src/core/network/rate_limiter.dart';
import 'package:kadmat/src/features/bidding/data/repositories/bidding_repository_impl.dart';
import 'package:kadmat/src/features/bidding/domain/repositories/bidding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for BiddingRepository
final biddingRepositoryProvider = Provider<BiddingRepository>((ref) {
  final supabase = Supabase.instance.client;
  final rateLimiter = RateLimiter();

  return BiddingRepositoryImpl(supabase, rateLimiter);
});
