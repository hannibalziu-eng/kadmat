import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/oauth_service.dart';

class OAuthLoginScreen extends ConsumerWidget {
  const OAuthLoginScreen({super.key});

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oAuthService = ref.watch(oAuthServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول الاجتماعي')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'اختر مزود تسجيل الدخول',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final success = await oAuthService.signInWithGoogle();
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.of(context).pop(true);
                  } else {
                    _showError(context, 'تعذر تسجيل الدخول عبر Google.');
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  _showError(
                    context,
                    'حدث خطأ أثناء تسجيل الدخول عبر Google. حاول مرة أخرى.',
                  );
                }
              },
              icon: const Icon(Icons.g_mobiledata_sharp, color: Colors.red),
              label: const Text('Google'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final success = await oAuthService.signInWithApple();
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.of(context).pop(true);
                  } else {
                    _showError(context, 'تعذر تسجيل الدخول عبر Apple.');
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  _showError(
                    context,
                    'حدث خطأ أثناء تسجيل الدخول عبر Apple. حاول مرة أخرى.',
                  );
                }
              },
              icon: const Icon(Icons.phone_iphone, color: Colors.black),
              label: const Text('Apple'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final success = await oAuthService.signInWithFacebook();
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.of(context).pop(true);
                  } else {
                    _showError(context, 'تعذر تسجيل الدخول عبر Facebook.');
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  _showError(
                    context,
                    'حدث خطأ أثناء تسجيل الدخول عبر Facebook. حاول مرة أخرى.',
                  );
                }
              },
              icon: const Icon(Icons.facebook, color: Colors.blue),
              label: const Text('Facebook'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'سيتم فتح موفر تسجيل الدخول الخارجي لإكمال العملية ثم إعادتك إلى التطبيق.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
