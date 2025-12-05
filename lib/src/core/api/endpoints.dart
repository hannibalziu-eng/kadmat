class Endpoints {
  // Base URL - Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator
  // For physical device, use your machine's IP address (e.g., http://192.168.1.5:3000)
  static const String baseUrl = 'http://localhost:3000/api';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Jobs
  static const String jobs = '/jobs';
  static const String nearbyJobs = '/jobs/nearby';
  static const String myJobs = '/jobs/my-jobs';
  static String acceptJob(String id) => '/jobs/$id/accept';
  static String setPrice(String id) => '/jobs/$id/set-price';
  static String confirmPrice(String id) => '/jobs/$id/confirm-price';
  static String completeJob(String id) => '/jobs/$id/complete';
  static String rateJob(String id) => '/jobs/$id/rate';
  static String cancelJob(String id) => '/jobs/$id/cancel';

  // Wallet
  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';

  // Technician
  static const String technicianLocation = '/technician/location';
  static const String technicianStatus = '/technician/status';

  // Services
  static const String services = '/services';
  static String serviceById(String id) => '/services/$id';
}
