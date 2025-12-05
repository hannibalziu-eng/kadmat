class Validators {
  static String? validateLibyanPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال رقم الهاتف';
    }
    // Remove spaces and dashes
    final cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');

    // Check format: 09x or +2189x
    final libyanPhoneRegex = RegExp(r'^(09[1-6]\d{7}|\+2189[1-6]\d{7})$');

    if (!libyanPhoneRegex.hasMatch(cleanValue)) {
      return 'رقم الهاتف غير صحيح (مثال: 0912345678)';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال الاسم';
    }
    if (value.length < 3) {
      return 'الاسم يجب أن يكون 3 أحرف على الأقل';
    }
    // Optional: Enforce Arabic characters only if strict
    // final arabicRegex = RegExp(r'^[\u0600-\u06FF\s]+$');
    // if (!arabicRegex.hasMatch(value)) return 'الرجاء استخدام أحرف عربية';

    return null;
  }

  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال الرمز';
    }
    if (value.length != 6 || int.tryParse(value) == null) {
      return 'الرمز يجب أن يتكون من 6 أرقام';
    }
    return null;
  }
}
