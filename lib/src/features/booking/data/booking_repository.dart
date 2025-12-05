import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/booking_model.dart';

part 'booking_repository.g.dart';

class BookingRepository {
  Future<void> createBooking(BookingModel booking) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network
    // In a real app, we would send this to the backend
    print('Booking created: $booking');
  }
}

@riverpod
BookingRepository bookingRepository(BookingRepositoryRef ref) {
  return BookingRepository();
}
