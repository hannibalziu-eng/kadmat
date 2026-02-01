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

  // Network Errors
  static const String noInternetConnection = 'لا يوجد اتصال بالإنترنت';
  static const String connectionTimeout = 'انتهت مهلة الاتصال';
  static const String serverError = 'خطأ في الخادم. يرجى المحاولة لاحقاً';
  static const String requestFailed = 'فشل الطلب';
  static const String unauthorized = 'غير مصرح. يرجى تسجيل الدخول مرة أخرى';

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
