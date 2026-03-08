/// Centralized navigation routes for the application.
/// Use these constants instead of raw strings to ensure type safety.
class AppRoutes {
  // Private constructor
  AppRoutes._();

  // ==================== AUTH ====================
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // ==================== TECHNICIAN AUTH ====================
  static const technicianLanding = '/technician/landing';
  static const technicianLogin = '/technician/login';
  static const technicianRegister = '/technician/register';
  static const technicianHome = '/technician/home';
  static const technicianSettings = '/technician/settings';
  static const technicianHelp = '/technician/help';
  static const admin = '/admin';
  static const adminDashboard = '/admin/dashboard';

  // ==================== CUSTOMER HOME & TABS ====================
  static const home = '/';
  static const booking = 'booking/:serviceId'; // Compatibility alias
  static const serviceDetails = 'service-details'; // Compatibility alias
  static const messages = 'messages'; // Sub-route of home
  static const tracking = 'tracking/:bookingId'; // Compatibility alias
  static const customerWallet = '/customer-wallet';
  static const customerWalletTransactions = '/customer-wallet/transactions';
  static const wallet = '/wallet';
  static const customerCreateRequest = '/customer/create-request';
  static const notifications = '/notifications';

  // ==================== SHARED JOB SCREENS ====================
  static const searchingForTechnician = '/searching-for-technician';
  static const technicianPriceInput = '/technician-price-input';
  static const customerConfirmation = '/customer-confirmation';

  // ==================== CUSTOMER JOB FLOW ====================
  static const customerJobSearching = '/jobs/:jobId/customer/searching';
  static const customerTechnicianFound =
      '/jobs/:jobId/customer/technician-found';
  static const customerPriceOffer = '/jobs/:jobId/customer/price-offer';
  static const customerInProgress = '/jobs/:jobId/customer/in-progress';
  static const customerRate = '/jobs/:jobId/customer/rate';
  static const customerCompleted = '/jobs/:jobId/customer/completed';
  static const customerConfirmCompletion =
      '/jobs/:jobId/customer/confirm-completion';
  static const customerPaymentApproval =
      '/jobs/:jobId/customer/payment-approval';
  static const customerPaymentProcessing =
      '/jobs/:jobId/customer/payment-processing';

  // ==================== TECHNICIAN JOB FLOW ====================
  static const technicianJobDetail =
      '/technician/job/:jobId'; // Compatibility alias
  static const technicianJobDetailV2 = '/jobs/:jobId/technician/detail';
  static const technicianAccepted = '/jobs/:jobId/technician/accepted';
  static const technicianSetPrice = '/jobs/:jobId/technician/set-price';
  static const technicianWaiting = '/jobs/:jobId/technician/waiting';
  static const technicianInProgress = '/jobs/:jobId/technician/in-progress';
  static const technicianCompleted = '/jobs/:jobId/technician/completed';
  static const technicianPrePhotos = '/jobs/:jobId/technician/pre-photos';
  static const technicianPostPhotos = '/jobs/:jobId/technician/post-photos';
  static const technicianPriceConfirmation =
      '/jobs/:jobId/technician/price-confirmation';
  static const technicianCompleteWorkInput =
      '/jobs/:jobId/technician/complete-work-input';
  static const technicianBidding = '/jobs/:jobId/technician/bidding';
  static const waitlistOffer = '/technician/waitlist-offer/:waitlistId';

  // ==================== OTHER ====================
  static const activeJob = '/active-job/:jobId';
  static const rateJob = '/rate-job/:jobId';
  static const technicianProfile = '/technician-profile/:technicianId';
  static const chat = '/jobs/:jobId/chat';

  // ==================== HELPER METHODS ====================

  static String buildBookingPath(String serviceId) => '/booking/$serviceId';
  static String buildTrackingPath(String bookingId) =>
      buildCustomerInProgressPath(bookingId);
  static String buildActiveJobPath(String jobId) => '/active-job/$jobId';

  static String buildJobChatPath(String jobId) => '/jobs/$jobId/chat';

  // Customer Builders
  static String buildCustomerSearchingPath(String jobId) =>
      '/jobs/$jobId/customer/searching';
  static String buildCustomerTechnicianFoundPath(String jobId) =>
      '/jobs/$jobId/customer/technician-found';
  static String buildCustomerPriceOfferPath(String jobId) =>
      '/jobs/$jobId/customer/price-offer';
  static String buildCustomerInProgressPath(String jobId) =>
      '/jobs/$jobId/customer/in-progress';
  static String buildCustomerRatePath(String jobId) =>
      '/jobs/$jobId/customer/rate';
  static String buildCustomerCompletedPath(String jobId) =>
      '/jobs/$jobId/customer/completed';
  static String buildCustomerConfirmCompletionPath(String jobId) =>
      '/jobs/$jobId/customer/confirm-completion';
  static String buildCustomerPaymentApprovalPath(String jobId) =>
      '/jobs/$jobId/customer/payment-approval';
  static String buildCustomerPaymentProcessingPath(String jobId) =>
      '/jobs/$jobId/customer/payment-processing';

  // Technician Builders
  static String buildTechnicianJobDetailPath(String jobId) =>
      '/jobs/$jobId/technician/detail';
  static String buildTechnicianAcceptedPath(String jobId) =>
      '/jobs/$jobId/technician/accepted';
  static String buildTechnicianSetPricePath(String jobId) =>
      '/jobs/$jobId/technician/set-price';
  static String buildTechnicianWaitingPath(String jobId) =>
      '/jobs/$jobId/technician/waiting';
  static String buildTechnicianInProgressPath(String jobId) =>
      '/jobs/$jobId/technician/in-progress';
  static String buildTechnicianCompletedPath(String jobId) =>
      '/jobs/$jobId/technician/completed';
  static String buildTechnicianPrePhotosPath(String jobId) =>
      '/jobs/$jobId/technician/pre-photos';
  static String buildTechnicianPostPhotosPath(String jobId) =>
      '/jobs/$jobId/technician/post-photos';
  static String buildTechnicianPriceConfirmationPath(String jobId) =>
      '/jobs/$jobId/technician/price-confirmation';
  static String buildTechnicianCompleteWorkInputPath(String jobId) =>
      '/jobs/$jobId/technician/complete-work-input';
  static String buildTechnicianBiddingPath(String jobId) =>
      '/jobs/$jobId/technician/bidding';
  static String buildWaitlistOfferPath(String waitlistId) =>
      '/technician/waitlist-offer/$waitlistId';

  static String buildTechnicianProfilePath(String technicianId) =>
      technicianId.trim().isEmpty
      ? home
      : '/technician-profile/${Uri.encodeComponent(technicianId.trim())}';

  /// Converts an absolute route to a child route path for nested GoRoute blocks.
  /// Example: `/wallet` -> `wallet`.
  static String asChild(String absolutePath) =>
      absolutePath.startsWith('/') ? absolutePath.substring(1) : absolutePath;
}
