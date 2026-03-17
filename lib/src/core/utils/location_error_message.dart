import 'package:flutter/foundation.dart';

String resolveLocationErrorMessage(dynamic error) {
  final message = error.toString().toLowerCase();

  final isPermissionError =
      message.contains('permission') ||
      message.contains('denied') ||
      message.contains('not allowed');
  if (isPermissionError) {
    if (kIsWeb) {
      return 'اسمح للموقع من المتصفح ثم اضغط "تحديث موقعي الحالي".';
    }
    return 'اسمح بالوصول إلى الموقع من إعدادات الجهاز ثم أعد المحاولة.';
  }

  final isServiceDisabled =
      message.contains('service') ||
      message.contains('disabled') ||
      message.contains('not enabled');
  if (isServiceDisabled) {
    return 'فعّل خدمات الموقع على الجهاز ثم أعد المحاولة.';
  }

  final isTimeout =
      message.contains('timeout') ||
      message.contains('time limit') ||
      message.contains('timed out');
  if (isTimeout) {
    return 'تعذر تحديد الموقع الآن. تأكد من ثبات الشبكة ثم أعد المحاولة.';
  }

  final isUnsupported =
      message.contains('unsupported') || message.contains('unimplemented');
  if (isUnsupported) {
    return 'التحديد التلقائي للموقع غير مدعوم في هذا المتصفح حالياً.';
  }

  final isSecureContextIssue =
      message.contains('secure') ||
      message.contains('https') ||
      message.contains('origin') ||
      message.contains('geolocation api can only be used in secure contexts');
  if (isSecureContextIssue) {
    return 'تحديد الموقع من متصفح الهاتف يحتاج رابط HTTPS. النسخة المحلية المفتوحة عبر الشبكة لا تسمح للموقع بالعمل تلقائيًا على أغلب الهواتف.';
  }

  return 'تعذر تحديد الموقع الحالي الآن. أعد المحاولة بعد السماح بالموقع.';
}
