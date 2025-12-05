import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CustomerPriceConfirmationDialog extends StatelessWidget {
  final String price;
  final String technicianName;
  final String serviceName;

  const CustomerPriceConfirmationDialog({
    super.key,
    required this.price,
    required this.technicianName,
    required this.serviceName,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent dismissing without action
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        body: Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20.r,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 48.s,
                    color: Theme.of(context).primaryColor,
                  ),
                ).animate().scale(duration: 400.ms),
                SizedBox(height: 24.h),
                Text(
                  'تأكيد سعر الخدمة',
                  style: TextStyle(
                    fontSize: 20.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16.fz,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontFamily: 'Cairo',
                    ),
                    children: [
                      const TextSpan(text: 'قام الفني '),
                      TextSpan(
                        text: technicianName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' بإنهاء خدمة '),
                      TextSpan(
                        text: serviceName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' وطلب مبلغ:'),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  '$price ر.س',
                  style: TextStyle(
                    fontSize: 36.fz,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ).animate().fadeIn().scale(delay: 200.ms),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Handle dispute logic
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم رفع اعتراض على السعر'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'اعتراض',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16.fz,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle confirmation logic
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تأكيد السعر بنجاح'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'تأكيد ودفع',
                          style: TextStyle(
                            fontSize: 16.fz,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms),
        ),
      ),
    );
  }
}
