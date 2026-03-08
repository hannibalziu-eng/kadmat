import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kadmat/src/core/constants.dart';
import 'package:kadmat/src/core/design/kadmat_tokens.dart';
import 'package:kadmat/src/features/technician/presentation/widgets/technician_flow_widgets.dart';

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
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('المساعدة والدعم')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 940.w),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                TechnicianFlowHero(
                  icon: Icons.support_agent_outlined,
                  eyebrow: 'دعم الفني',
                  title: 'اطلب المساعدة بالطريقة الأسرع',
                  subtitle:
                      'إذا تعطل طلب، تأخرت الإشعارات، أو احتجت دعمًا تشغيليًا، استخدم القنوات التالية حسب سرعتك المفضلة.',
                  bottom: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: const [
                      TechnicianFlowPill(
                        icon: Icons.chat_bubble_outline,
                        label: 'واتساب للدعم السريع',
                      ),
                      TechnicianFlowPill(
                        icon: Icons.call_outlined,
                        label: 'اتصال مباشر',
                      ),
                      TechnicianFlowPill(
                        icon: Icons.email_outlined,
                        label: 'بريد للتفاصيل',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                const TechnicianFlowSurface(
                  child: TechnicianFlowNextStepCard(
                    icon: Icons.flash_on_outlined,
                    title: 'متى تستخدم كل قناة؟',
                    description:
                        'للمشكلة العاجلة ابدأ بواتساب أو الاتصال. وللحالات التي تحتاج وصفًا أطول أو مرفقات استخدم البريد الإلكتروني.',
                  ),
                ),
                SizedBox(height: 16.h),
                _SectionLabel(
                  title: 'قنوات التواصل',
                  subtitle: 'اختر القناة حسب سرعة الاستجابة التي تحتاجها.',
                ),
                SizedBox(height: 10.h),
                TechnicianFlowSurface(
                  child: Column(
                    children: [
                      _SupportActionRow(
                        icon: Icons.support_agent,
                        title: 'التواصل عبر واتساب',
                        subtitle:
                            'الأسرع للمشاكل العاجلة بخصوص الطلبات أو التطبيق.',
                        emphasis: 'استجابة أسرع عادة',
                        onTap: () => _openWhatsApp(context),
                      ),
                      Divider(height: 22.h, color: KadmatColors.lightBorder),
                      _SupportActionRow(
                        icon: Icons.call_outlined,
                        title: 'الاتصال بالدعم',
                        subtitle: _supportPhone,
                        emphasis: 'للحالات التي تحتاج شرحًا مباشرًا',
                        onTap: () => _makePhoneCall(context),
                      ),
                      Divider(height: 22.h, color: KadmatColors.lightBorder),
                      _SupportActionRow(
                        icon: Icons.email_outlined,
                        title: 'الدعم عبر البريد',
                        subtitle: _supportEmail,
                        emphasis: 'مناسب للتفاصيل الطويلة أو المتابعة',
                        onTap: () => _sendEmail(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                TechnicianFlowSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'انسخ رقم الدعم',
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 15.5.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'إذا أردت استخدام تطبيق آخر، انسخ الرقم واستخدمه مباشرة.',
                              style: TextStyle(
                                color: KadmatColors.lightTextSecondary,
                                fontSize: 12.5.fz,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      OutlinedButton.icon(
                        onPressed: () => _copySupportPhone(context),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('نسخ'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                _SectionLabel(
                  title: 'أسئلة متكررة',
                  subtitle: 'إجابات سريعة لأكثر ما يواجه الفني أثناء العمل.',
                ),
                SizedBox(height: 10.h),
                TechnicianFlowSurface(child: _buildFaqList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqList() {
    return Column(
      children: [
        _FaqItem(
          question: 'لماذا لا تظهر الطلبات؟',
          answer:
              'تأكد من تفعيل حالة الاتصال، ومنح صلاحية الموقع، وتحديد الخدمات التي تعمل عليها في ملفك الشخصي.',
        ),
        Divider(color: KadmatColors.lightBorder, height: 22.h),
        _FaqItem(
          question: 'ألغى العميل الطلب وما زال ظاهرًا؟',
          answer:
              'اسحب للتحديث أولًا. إذا استمر الظهور، تواصل مع الدعم واذكر رقم الطلب حتى تتم مراجعته بسرعة.',
        ),
        Divider(color: KadmatColors.lightBorder, height: 22.h),
        _FaqItem(
          question: 'كيف أتابع حالة السحب من المحفظة؟',
          answer:
              'من تبويب المحفظة ثم طلبات السحب ستجد الحالة الأحدث، وإذا تأخر التحديث استخدم قناة الدعم المناسبة.',
        ),
      ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: KadmatColors.lightTextPrimary,
            fontSize: 16.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 12.4.fz,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SupportActionRow extends StatelessWidget {
  const _SupportActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasis,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: KadmatColors.brandAccent,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(icon, color: KadmatColors.brandSecondary, size: 22.s),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 14.8.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: KadmatColors.lightTextSecondary,
                      fontSize: 12.3.fz,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    emphasis,
                    style: TextStyle(
                      color: KadmatColors.brandPrimary,
                      fontSize: 11.8.fz,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Icon(
              Icons.chevron_left_rounded,
              color: KadmatColors.lightTextSecondary,
              size: 22.s,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            color: KadmatColors.lightTextPrimary,
            fontSize: 14.2.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          answer,
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 12.4.fz,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
