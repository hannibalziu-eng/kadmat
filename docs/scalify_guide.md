# دليل تطبيق Responsive Dimensions باستخدام `flutter_scalify`

هذا الدليل يوضح الخطوات العملية لتطبيق مكتبة `flutter_scalify` على مشروع Flutter الحالي لجعل الواجهة متجاوبة مع مختلف أحجام الشاشات.

## 1. الخطوات الأولية

### إضافة المكتبة
أضف `flutter_scalify` إلى ملف `pubspec.yaml` في قسم `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_scalify: ^1.0.0 # تأكد من استخدام أحدث إصدار
```

ثم قم بتشغيل الأمر التالي في التيرمينال لتثبيت المكتبة:

```bash
flutter pub get
```

---

## 2. التهيئة (Initialization)

يجب تهيئة المكتبة في نقطة الدخول الرئيسية للتطبيق (عادةً في `main.dart`) قبل استخدام أي من خصائصها.

### تعديل `main.dart`

1.  استورد المكتبة:
    ```dart
    import 'package:flutter_scalify/flutter_scalify.dart';
    ```

2.  استخدم `Scalify.init` داخل الـ `build` method لأول Widget (مثل `MyApp` أو `MaterialApp`). يفضل وضعها في `builder` الخاص بـ `MaterialApp` لضمان توفر الـ `Context` الصحيح.

    **مثال:**

    ```dart
    class MyApp extends StatelessWidget {
      const MyApp({super.key});

      @override
      Widget build(BuildContext context) {
        // الأبعاد التصميمية (Design Size) التي صمم عليها المصمم (مثلاً 375x812 لـ iPhone X)
        const designSize = Size(375, 812);

        return MaterialApp(
          title: 'Kadmat',
          // ... بقية الإعدادات
          builder: (context, child) {
            // تهيئة Scalify
            Scalify.init(context, designSize: designSize);
            return child!;
          },
          home: const WelcomeScreen(),
        );
      }
    }
    ```

---

## 3. تطبيق الأبعاد (Usage)

استبدل القيم الثابتة (Hardcoded Values) بالإكستنشنات التي توفرها المكتبة.

### الإكستنشنات المتاحة:
*   `.w`: للعرض (Width) - يحسب القيمة بناءً على عرض الشاشة.
*   `.h`: للارتفاع (Height) - يحسب القيمة بناءً على ارتفاع الشاشة.
*   `.fz`: لحجم الخط (Font Size) - يحسب القيمة بناءً على مقياس النص.
*   `.s`: للمساحات المربعة (Square) - يستخدم الأصغر بين العرض والارتفاع (مفيد للأيقونات).
*   `.r`: لنصف القطر (Radius) - مفيد لـ `borderRadius`.
*   `.p`: للحشوة (Padding) - يمكن استخدامه كقيمة عامة.

### أمثلة عملية:

#### 1. Container (Width & Height)
**قبل:**
```dart
Container(
  width: 200,
  height: 100,
  color: Colors.red,
)
```
**بعد:**
```dart
Container(
  width: 200.w, // يتكيف مع عرض الشاشة
  height: 100.h, // يتكيف مع ارتفاع الشاشة
  color: Colors.red,
)
```

#### 2. Text (Font Size)
**قبل:**
```dart
Text(
  'مرحباً بك',
  style: TextStyle(fontSize: 16),
)
```
**بعد:**
```dart
Text(
  'مرحباً بك',
  style: TextStyle(fontSize: 16.fz), // يتكيف مع إعدادات الخط وحجم الشاشة
)
```

#### 3. Icon (Size)
**قبل:**
```dart
Icon(Icons.home, size: 24)
```
**بعد:**
```dart
Icon(Icons.home, size: 24.s) // يستخدم .s للحفاظ على نسبة الأيقونة مربعة
```

#### 4. SizedBox (Spacing)
**قبل:**
```dart
SizedBox(height: 20)
SizedBox(width: 10)
```
**بعد:**
```dart
SizedBox(height: 20.h) // مسافة رأسية
SizedBox(width: 10.w)  // مسافة أفقية
```

#### 5. Padding (EdgeInsets)
**قبل:**
```dart
Padding(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: ...
)
```
**بعد:**
```dart
Padding(
  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
  child: ...
)
```
*ملاحظة: لـ `EdgeInsets.all(10)` يمكن استخدام `EdgeInsets.all(10.w)` أو `10.p` إذا كانت مدعومة.*

#### 6. BorderRadius
**قبل:**
```dart
BorderRadius.circular(12)
```
**بعد:**
```dart
BorderRadius.circular(12.r) // يتكيف نصف القطر بشكل متناسق
```

---

## 4. الحفاظ على الكود (Best Practices)

*   **لا تغير المنطق:** ركز فقط على الأرقام (القيم) داخل `build` methods. لا تلمس الـ Logic أو الـ State Management.
*   **ابدأ بالمكونات العامة:** ابدأ بتطبيق التغييرات على الـ Widgets المشتركة (Common Widgets) في مجلد `core` أو `shared`، ثم انتقل للشاشات.
*   **القيم الصغيرة:** القيم الصغيرة جداً (مثل 1 بكسل للحدود) قد لا تحتاج لتحويل، أو يمكن استخدام `.w` لها بحذر.

---

## 5. اختبارات وتقييم (Testing)

### كيف تتأكد من التجاوب؟
1.  **Device Preview:** استخدم مكتبة `device_preview` لتجربة التطبيق على أحجام شاشات مختلفة (iPhone SE, iPhone 14 Pro Max, iPad) مباشرة من المحاكي.
2.  **تغيير حجم النافذة:** إذا كنت تشغل التطبيق على macOS/Windows، قم بتغيير حجم النافذة وتأكد من أن العناصر تتمدد وتتقلص بشكل صحيح ولا يحدث Overflow.
3.  **Orientation:** جرب تدوير الشاشة (إذا كان التطبيق يدعم الوضع الأفقي) وتأكد من أن `Scalify` يعيد الحساب بشكل صحيح.

### اختبار عدم وجود مشاكل (Regression Testing):
*   تأكد من أن النصوص لا تختفي أو تخرج عن حدود الحاويات في الشاشات الصغيرة.
*   تأكد من أن الصور لا تصبح مشوهة (Aspect Ratio) عند استخدام `.w` و `.h` معاً؛ يفضل استخدام `.w` للارتفاع أيضاً إذا كنت تريد الحفاظ على النسبة، أو استخدام `BoxFit`.

---

## 6. نصائح احترافية (Pro Tips)

*   **القيم الثابتة:** في بعض الحالات النادرة، قد تحتاج لقيمة ثابتة لا تتغير بتغير الشاشة (مثلاً سمك إطار معين). في هذه الحالة، اترك الرقم كما هو دون إكستنشن.
*   **التداخل:** تجنب استخدام `flutter_screenutil` و `flutter_scalify` معاً لتجنب تضارب الأسماء.
*   **الخطوط:** انتبه عند استخدام `.fz` مع نصوص داخل أزرار ثابتة الارتفاع. قد يكبر الخط ويخرج عن الزر. في هذه الحالة، اجعل ارتفاع الزر متجاوباً أيضاً (`.h`).
