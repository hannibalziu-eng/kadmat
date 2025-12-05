import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TechnicianPriceInputScreen extends StatefulWidget {
  final String orderId;
  final String serviceName;

  const TechnicianPriceInputScreen({
    super.key,
    required this.orderId,
    required this.serviceName,
  });

  @override
  State<TechnicianPriceInputScreen> createState() =>
      _TechnicianPriceInputScreenState();
}

class _TechnicianPriceInputScreenState
    extends State<TechnicianPriceInputScreen> {
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إتمام الخدمة'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80.s,
                color: Colors.green,
              ).animate().scale(duration: 500.ms),
              SizedBox(height: 24.h),
              Text(
                'تم إنجاز الخدمة بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.fz,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ).animate().fadeIn().slideY(begin: 0.5),
              SizedBox(height: 8.h),
              Text(
                'يرجى إدخال السعر النهائي للخدمة المقدمة لـ ${widget.serviceName}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.fz, color: Colors.grey),
              ).animate().fadeIn().slideY(begin: 0.5, delay: 100.ms),
              SizedBox(height: 48.h),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32.fz,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  suffixText: 'ر.س',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال السعر';
                  }
                  if (double.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم صحيح';
                  }
                  return null;
                },
              ).animate().fadeIn().slideX(delay: 200.ms),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Simulate sending notification to customer
                    context.push(
                      '/customer-confirmation',
                      extra: {
                        'price': _priceController.text,
                        'technicianName': 'أحمد محمد', // Mock name
                        'serviceName': widget.serviceName,
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'إرسال للعميل',
                  style: TextStyle(
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 1, delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
