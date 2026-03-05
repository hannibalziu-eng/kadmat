// lib/src/core/utils/error_messages.dart
/// Centralized error messages in Arabic for the application
class ErrorMessages {
  ErrorMessages._();

  // Photo Upload Errors
  static const String photoUploadFailed =
      'فشل رفع الصورة. يرجى المحاولة مرة أخرى';
  static const String photoUploadTimeout =
      'انتهت مهلة رفع الصورة. تحقق من اتصال الإنترنت';
  static const String photoTooLarge =
      'حجم الصورة كبير جداً. الحد الأقصى 5 ميجابايت';
  static const String photoFormatInvalid =
      'صيغة الصورة غير مدعومة. استخدم JPG أو PNG';
  static const String photoPickerFailed = 'فشل اختيار الصورة';
  static const String cameraPermissionDenied =
      'يجب السماح بالوصول إلى الكاميرا';
  static const String galleryPermissionDenied = 'يجب السماح بالوصول إلى المعرض';
  static const String minPhotosRequired = 'يجب إضافة صورة واحدة على الأقل';
  static const String maxPhotosExceeded = 'الحد الأقصى 5 صور';
  static const String descriptionRequired = 'يجب إضافة وصف';
  static const String notesRequired = 'يجب إضافة ملاحظات';

  // Technician Locking Errors
  static const String technicianLocked =
      'لديك طلب قيد التنفيذ. يجب إكماله قبل قبول طلبات جديدة';
  static const String cannotAcceptWhileLocked =
      'لا يمكنك قبول طلبات جديدة حالياً';
  static const String lockCheckFailed = 'فشل التحقق من حالة القفل';
  static const String activeJobLocked =
      'لديك طلب نشط حالياً. أكمل الطلب الحالي أولاً';
  static const String walletDebtLocked =
      'لا يمكنك قبول طلبات جديدة حتى سداد المديونية';

  // Payment Errors
  static const String priceRequired = 'يجب إدخال السعر';
  static const String priceInvalid = 'السعر غير صحيح';
  static const String priceTooLow = 'السعر منخفض جداً';
  static const String priceTooHigh = 'السعر مرتفع جداً';
  static const String paymentMethodRequired = 'يجب اختيار طريقة الدفع';
  static const String paymentConfirmationFailed = 'فشل تأكيد الدفع';
  static const String paymentApprovalFailed = 'فشل الموافقة على الدفع';
  static const String paymentRejectionFailed = 'فشل رفض الدفع';
  static const String rejectionReasonRequired = 'يجب إدخال سبب الرفض';

  // Job Errors
  static const String jobNotFound = 'لم يتم العثور على الطلب';
  static const String jobLoadFailed = 'فشل تحميل بيانات الطلب';
  static const String jobAcceptFailed = 'فشل قبول الطلب';
  static const String jobCancelFailed = 'فشل إلغاء الطلب';
  static const String jobCompleteFailed = 'فشل إتمام الطلب';
  static const String jobUpdateFailed = 'فشل تحديث الطلب';
  static const String invalidJobStatus = 'حالة الطلب غير صحيحة';
  static const String preServicePhotosRequired =
      'يجب رفع صور ما قبل الخدمة قبل بدء العمل';
  static const String postServicePhotosRequired =
      'يجب رفع صور ما بعد الخدمة قبل طلب الإنهاء';
  static const String cancellationRestricted =
      'لا يمكن إلغاء الطلب بعد وصول الفني أو بدء العمل';

  // Network Errors
  static const String noInternetConnection = 'لا يوجد اتصال بالإنترنت';
  static const String connectionTimeout = 'انتهت مهلة الاتصال';
  static const String serverError = 'خطأ في الخادم. يرجى المحاولة لاحقاً';
  static const String requestFailed = 'فشل الطلب';
  static const String unauthorized = 'غير مصرح. يرجى تسجيل الدخول مرة أخرى';
  static const String rateLimited = 'طلبات كثيرة. يرجى المحاولة بعد قليل';
  static const String forbidden = 'ليست لديك صلاحية لتنفيذ هذا الإجراء';
  static const String invalidInput = 'البيانات المدخلة غير صحيحة';

  // General Errors
  static const String unknownError = 'حدث خطأ غير متوقع';
  static const String tryAgain = 'يرجى المحاولة مرة أخرى';
  static const String operationCancelled = 'تم إلغاء العملية';
  static const String dataLoadFailed = 'فشل تحميل البيانات';

  // Success Messages
  static const String photoUploadSuccess = 'تم رفع الصور بنجاح';
  static const String jobAcceptSuccess = 'تم قبول الطلب بنجاح';
  static const String jobCompleteSuccess = 'تم إتمام الطلب بنجاح';
  static const String paymentConfirmSuccess = 'تم تأكيد الدفع بنجاح';
  static const String paymentApprovalSuccess = 'تم الموافقة على الدفع بنجاح';

  /// Resolve message from backend API error code.
  /// Falls back to backend message if provided.
  static String fromApiCode(String? code, {String? fallback}) {
    switch (code) {
      case 'JOB_ALREADY_ACCEPTED':
        return 'تم قبول الطلب من فني آخر';
      case 'INVALID_STATUS_TRANSITION':
        return 'حالة الطلب تغيرت. تم تحديث الشاشة';
      case 'JOB_NOT_FOUND':
      case 'NOT_FOUND':
        return jobNotFound;
      case 'UNAUTHORIZED':
        return unauthorized;
      case 'FORBIDDEN':
      case 'INSUFFICIENT_PERMISSIONS':
        return forbidden;
      case 'ACTIVE_JOB_LOCKED':
        return activeJobLocked;
      case 'TECHNICIAN_WALLET_DEBT_LOCKED':
        return walletDebtLocked;
      case 'PRE_SERVICE_PHOTOS_REQUIRED':
        return preServicePhotosRequired;
      case 'POST_SERVICE_PHOTOS_REQUIRED':
        return postServicePhotosRequired;
      case 'CANCELLATION_RESTRICTED':
        return cancellationRestricted;
      case 'CONFLICT':
        return (fallback != null && fallback.isNotEmpty) ? fallback : activeJobLocked;
      case 'VALIDATION_FAILED':
      case 'INVALID_INPUT':
        return (fallback != null && fallback.isNotEmpty)
            ? fallback
            : invalidInput;
      case 'RATE_LIMITED':
        return rateLimited;
      case 'DATABASE_ERROR':
      case 'SERVER_ERROR':
        if (fallback != null && fallback.isNotEmpty) {
          final lower = fallback.toLowerCase();
          if (lower.contains('accepted_bid_id')) {
            return 'قاعدة البيانات تحتاج تحديثًا (accepted_bid_id)';
          }
          if (lower.contains('failed to assign job')) {
            return 'تعذر تثبيت الطلب على الفني. حاول مرة أخرى';
          }
        }
        return serverError;
      case 'SERVICE_UNAVAILABLE':
        return 'الخدمة غير متاحة مؤقتاً';
      default:
        return (fallback != null && fallback.isNotEmpty)
            ? fallback
            : unknownError;
    }
  }

  /// Get user-friendly error message from exception
  static String fromException(dynamic error) {
    if (error == null) return unknownError;

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return noInternetConnection;
    }

    if (errorString.contains('timeout')) {
      return connectionTimeout;
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return unauthorized;
    }

    if (errorString.contains('500') || errorString.contains('server')) {
      return serverError;
    }

    // Photo errors
    if (errorString.contains('photo') || errorString.contains('image')) {
      return photoUploadFailed;
    }

    // Payment errors
    if (errorString.contains('payment') || errorString.contains('price')) {
      return paymentConfirmationFailed;
    }

    // Job errors
    if (errorString.contains('job')) {
      return jobUpdateFailed;
    }

    return unknownError;
  }
}
