import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/booking_model.dart';

part 'booking_repository.g.dart';

class BookingRepository {
  Future<void> createBooking(BookingModel booking) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network
    // In a real app, we would send this to the backend
    debugPrint('Booking created: $booking');
  }
}

@riverpod
BookingRepository bookingRepository(Ref ref) {
  return BookingRepository();
}
