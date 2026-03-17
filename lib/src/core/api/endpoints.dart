import 'package:flutter/foundation.dart';

class Endpoints {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      final origin = Uri.base;
      final host = origin.host.isEmpty ? 'localhost' : origin.host;
      final scheme = origin.scheme.isEmpty ? 'http' : origin.scheme;
      return '$scheme://$host:3000/api';
    }

    // Default local mobile/native development target.
    return 'http://localhost:3000/api';
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Jobs
  static const String jobs = '/jobs';
  static const String nearbyJobs = '/jobs/nearby';
  static const String myJobs = '/jobs/my-jobs';
  static String acceptJob(String id) => '/jobs/$id/accept';
  static String submitOffer(String id) => '/jobs/$id/submit-offer';
  static String acceptOffer(String id) => '/jobs/$id/accept-offer';
  static String setPrice(String id) => '/jobs/$id/set-price';
  static String confirmPrice(String id) => '/jobs/$id/confirm-price';
  static String technicianProgress(String id) =>
      '/jobs/$id/technician-progress';
  static String completeJob(String id) => '/jobs/$id/complete';
  static String rateJob(String id) => '/jobs/$id/rate';
  static String cancelJob(String id) => '/jobs/$id/cancel';

  // Wallet
  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletWithdraw = '/wallet/withdraw';
  static const String walletWithdrawals = '/wallet/withdrawals';

  // Messages
  static const String messageConversations = '/messages/conversations';
  static const String messageUnreadCount = '/messages/unread-count';
  static String messagesForJob(String jobId) => '/messages/$jobId';
  static String markMessagesRead(String jobId) => '/messages/$jobId/read';

  // Technician
  static const String technicianLocation = '/technician/location';
  static const String technicianStatus = '/technician/status';
  static const String updateProfile = '/technician/profile';
  static const String addPortfolioWork = '/technician/portfolio';

  // Services
  static const String services = '/services';
  static String serviceById(String id) => '/services/$id';
  static String serviceCatalogItems(String id) => '/services/$id/catalog-items';
}