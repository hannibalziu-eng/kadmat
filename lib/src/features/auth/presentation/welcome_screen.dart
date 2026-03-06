import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'widgets/social_auth_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Image Section
                  SizedBox(
                    height: 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=800',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.grey[900]);
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سوقك للمواهب الاحترافية',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28.fz,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'تواصل مع أفضل المستقلين لإنجاز مشاريعك',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16.fz,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Carousel Section
                  SizedBox(
                    height: 280,
                    child: PageView(
                      controller: _pageController,
                      padEnds: false,
                      children: [
                        _buildFeatureCard(
                          title: 'ابحث عن خبراء',
                          subtitle:
                              'اعثر على المحترفين المناسبين لمشروعك بسهولة',
                          imageUrl:
                              'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=800',
                        ),
                        _buildFeatureCard(
                          title: 'مدفوعات آمنة',
                          subtitle: 'نضمن لك معاملات آمنة وموثوقة لكل خدمة',
                          imageUrl:
                              'https://images.unsplash.com/photo-1580519542036-c47de6196ba5?w=800',
                        ),
                        _buildFeatureCard(
                          title: 'جودة مضمونة',
                          subtitle: 'خبراء معتمدون لضمان أفضل النتائج لمشاريعك',
                          imageUrl:
                              'https://images.unsplash.com/photo-1513224502586-d254a5245511?w=800',
                        ),
                      ],
                    ),
                  ),

                  // Button Group Section
                  Padding(
                    padding: EdgeInsets.all(24.0.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KadmatPrimaryButton(
                          label: 'إنشاء حساب',
                          icon: Icons.person_add_alt_1_rounded,
                          onPressed: () {
                            context.push(AppRoutes.register);
                          },
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: SocialAuthButton(
                                text: 'جوجل',
                                icon: Icons.g_mobiledata,
                                iconColor: Colors.red,
                                onPressed: () {},
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: SocialAuthButton(
                                text: 'فيسبوك',
                                icon: Icons.facebook,
                                iconColor: Colors.blue,
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        KadmatSecondaryButton(
                          label: 'تسجيل الدخول',
                          icon: Icons.login_rounded,
                          onPressed: () => context.push(AppRoutes.login),
                        ),
                        SizedBox(height: 24.h),
                        // Technician Login Option
                        KadmatSecondaryButton(
                          label: 'هل أنت فني؟ سجل دخولك من هنا',
                          icon: Icons.engineering,
                          onPressed: () {
                            context.push(AppRoutes.technicianLanding);
                          },
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'بالمتابعة، أنت توافق على شروط الخدمة وسياسة الخصوصية.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12.fz),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required String imageUrl,
  }) {
    return Container(
      margin: EdgeInsets.only(left: 16.w, top: 16.h, bottom: 16.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(KadmatRadius.lg.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(KadmatRadius.lg.r),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Icon(
                      Icons.broken_image,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.0.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
