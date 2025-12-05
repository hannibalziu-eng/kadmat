// Deep Linking Configuration for Kadmat App
// GoRouter already supports deep linking via path parameters.
// This file documents the available deep link paths.

/// Available Deep Links:
/// 
/// 1. Login: kadmat://login
///    - Navigates to login screen
/// 
/// 2. Home: kadmat://
///    - Navigates to home screen
/// 
/// 3. Booking: kadmat://booking/[serviceId]
///    - Navigates to booking screen for specific service
///    - Example: kadmat://booking/1
/// 
/// 4. Tracking: kadmat://tracking/[bookingId]
///    - Navigates to tracking screen for specific booking
///    - Example: kadmat://tracking/abc-123
/// 
/// To enable deep linking in your app:
/// 
/// Android: Add intent filters in AndroidManifest.xml
/// iOS: Configure URL schemes in Info.plist
/// 
/// GoRouter automatically handles path-based navigation.
