import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kadmat/src/core/constants.dart';

class TechnicianHelpScreen extends StatelessWidget {
  const TechnicianHelpScreen({super.key});

  String get _supportPhone {
    final phone = AppConstants.supportPhone.trim();
    return phone.isEmpty ? '966500000000' : phone;
  }

  String get _supportEmail {
    final email = AppConstants.supportEmail.trim();
    return email.isEmpty ? 'support@kadmat.app' : email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة والدعم')),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildActionCard(
            context,
            icon: Icons.support_agent,
            title: 'التواصل عبر واتساب',
            subtitle: 'للدعم الفوري بخصوص الطلبات والمشاكل التقنية',
            onTap: () => _openWhatsApp(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.call_outlined,
            title: 'الاتصال بالدعم',
            subtitle: _supportPhone,
            onTap: () => _makePhoneCall(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.email_outlined,
            title: 'الدعم عبر البريد',
            subtitle: _supportEmail,
            onTap: () => _sendEmail(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.copy_outlined,
            title: 'نسخ رقم الدعم',
            subtitle: 'انسخ رقم الدعم لاستخدامه في أي تطبيق',
            onTap: () => _copySupportPhone(context),
          ),
          SizedBox(height: 18.h),
          _buildFaqCard(context),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(
          title,
          style: TextStyle(fontSize: 15.fz, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12.fz, color: Colors.grey.shade400),
        ),
        trailing: Icon(Icons.chevron_right, size: 20.s),
      ),
    );
  }

  Widget _buildFaqCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.quiz_outlined,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          'أسئلة متكررة',
          style: TextStyle(fontSize: 15.fz, fontWeight: FontWeight.w700),
        ),
        childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
        children: [
          _buildFaqItem(
            'لماذا لا تظهر الطلبات؟',
            'تأكد من تفعيل حالة "متصل"، صلاحية الموقع، وتحديد الخدمة في ملفك.',
          ),
          _buildFaqItem(
            'ألغى العميل الطلب وما زال ظاهرًا؟',
            'اسحب للتحديث. إذا استمر الظهور تواصل مع الدعم وارسل رقم الطلب.',
          ),
          _buildFaqItem(
            'كيف أتابع حالة السحب من المحفظة؟',
            'من تبويب المحفظة > طلبات السحب ستجد الحالة محدثة.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(answer),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(
      'مرحباً، أحتاج مساعدة بخصوص حساب الفني في Kadmat.',
    );
    final deepLink = Uri.parse(
      'whatsapp://send?phone=$_supportPhone&text=$message',
    );
    final webFallback = Uri.parse('https://wa.me/$_supportPhone?text=$message');
    final ok = await _launch(deepLink, fallback: webFallback);
    if (ok || !context.mounted) return;
    _showError(context, 'تعذر فتح واتساب على هذا الجهاز.');
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    final uri = Uri.parse('tel:$_supportPhone');
    final ok = await _launch(uri);
    if (ok || !context.mounted) return;
    _showError(context, 'تعذر بدء الاتصال من هذا الجهاز.');
  }

  Future<void> _sendEmail(BuildContext context) async {
    final subject = Uri.encodeComponent('طلب دعم فني - تطبيق الفني');
    final uri = Uri.parse('mailto:$_supportEmail?subject=$subject');
    final ok = await _launch(uri);
    if (ok || !context.mounted) return;
    _showError(context, 'تعذر فتح تطبيق البريد الإلكتروني.');
  }

  Future<void> _copySupportPhone(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _supportPhone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الدعم')));
  }

  Future<bool> _launch(Uri primary, {Uri? fallback}) async {
    if (await canLaunchUrl(primary)) {
      return launchUrl(primary, mode: LaunchMode.externalApplication);
    }
    if (fallback != null && await canLaunchUrl(fallback)) {
      return launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
