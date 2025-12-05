class Endpoints {
  // Base URL - Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator
  // For physical device, use your machine's IP address (e.g., http://192.168.1.5:3000)
  static const String baseUrl = 'http://192.168.1.145:3000/api';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Jobs
  static const String jobs = '/jobs';
  static const String nearbyJobs = '/jobs/nearby';
  static const String myJobs = '/jobs/my-jobs';
  static String acceptJob(String id) => '/jobs/$id/accept';
  static String completeJob(String id) => '/jobs/$id/complete';

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
