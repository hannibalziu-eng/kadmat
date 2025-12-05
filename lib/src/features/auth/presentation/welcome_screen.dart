import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
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
      body: Column(
        children: [
          // Header Image Section
          Expanded(
            flex: 3,
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
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.8),
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
          Expanded(
            flex: 4,
            child: PageView(
              controller: _pageController,
              padEnds: false,
              children: [
                _buildFeatureCard(
                  title: 'ابحث عن خبراء',
                  subtitle: 'اعثر على المحترفين المناسبين لمشروعك بسهولة',
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
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24.0.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        context.push('/register');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13b6ec),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'إنشاء حساب',
                        style: TextStyle(
                          fontSize: 16.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: const Color(0xFF13b6ec),
                          fontSize: 16.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Technician Login Option
                    Center(
                      child: TextButton(
                        onPressed: () {
                          context.push('/technician/landing');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.engineering, size: 18.s),
                            SizedBox(width: 8.w),
                            Text(
                              'هل أنت فني؟ سجل دخولك من هنا',
                              style: TextStyle(fontSize: 14.fz),
                            ),
                          ],
                        ),
                      ),
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
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
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
