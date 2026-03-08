import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';

class MFAPromptScreen extends ConsumerWidget {
  final String email;
  final String password;
  final VoidCallback onSuccess;

  const MFAPromptScreen({
    super.key,
    required this.email,
    required this.password,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfaService = ref.watch(mfaServiceProvider);
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('التحقق الثنائي')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'أدخل رمز التحقق',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل الرمز المكوّن من 6 أرقام من تطبيق المصادقة أو جهازك',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'رمز من 6 أرقام',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final success = await mfaService.authenticateWithMFA(
                    email,
                    password,
                    controller.text.trim(),
                  );

                  if (success) {
                    onSuccess();
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('رمز التحقق غير صحيح')),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تعذر التحقق من الرمز حالياً. حاول مرة أخرى.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('تحقق'),
            ),
          ],
        ),
      ),
    );
  }
}
