import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/data/auth_repository.dart';
import 'edit_technician_profile_screen.dart';
import 'add_portfolio_work_screen.dart';
import '../../../../common_widgets/badge_widget.dart';

class TechnicianProfileScreen extends ConsumerWidget {
  const TechnicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final fullName = userProfile?['full_name'] ?? 'مستخدم';
    final phone = userProfile?['phone'] ?? '';
    // final title = userProfile?['title'] ?? 'فني'; // If title is in DB

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: () {
            ref.read(authRepositoryProvider).signOut();
            context.go('/technician/login');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditTechnicianProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4.w),
                  ),
                  child: CircleAvatar(
                    radius: 48.r,
                    backgroundImage: const NetworkImage(
                      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 20.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        phone, // Display phone or title
                        style: TextStyle(
                          fontSize: 16.fz,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'الرياض، المملكة العربية السعودية',
                        style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn().slideX(),

            // Badges Section
            if (userProfile != null &&
                userProfile['badges'] != null &&
                (userProfile['badges'] as List).isNotEmpty) ...[
              SizedBox(height: 16.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: (userProfile['badges'] as List).map((badge) {
                  return BadgeWidget(
                    label: badge['label'] ?? '',
                    iconName: badge['icon_name'] ?? '',
                    badgeType: badge['badge_type'] ?? '',
                  );
                }).toList(),
              ).animate().fadeIn(delay: 100.ms),
            ],

            SizedBox(height: 24.h),

            // Professional Experience Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخبرة المهنية',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '8+',
                              style: TextStyle(
                                fontSize: 24.fz,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'سنوات الخبرة',
                              style: TextStyle(
                                fontSize: 12.fz,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${userProfile?['reviews_count'] ?? 0}+',
                              style: TextStyle(
                                fontSize: 24.fz,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'تقييم إيجابي',
                              style: TextStyle(
                                fontSize: 12.fz,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.2, delay: 100.ms),
            SizedBox(height: 24.h),

            // Bio Section
            Text(
              'نبذة شخصية',
              style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'سباك محترف بخبرة تمتد لأكثر من 8 سنوات في مجال تركيب وصيانة أنظمة السباكة للمنازل والمباني التجارية. متخصص في اكتشاف التسريبات وإصلاحها بكفاءة عالية، وتركيب الأدوات الصحية الحديثة. ألتزم بتقديم أعلى مستويات الجودة في العمل مع ضمان رضا العميل. أسعى دائمًا لاستخدام أفضل المواد والتقنيات لضمان حلول دائمة وموثوقة.',
                style: TextStyle(
                  fontSize: 14.fz,
                  height: 1.6,
                  color: Colors.grey[700],
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2, delay: 250.ms),
            SizedBox(height: 24.h),

            // Certifications Section
            Text(
              'الشهادات والدورات التدريبية',
              style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 300.ms),
            SizedBox(height: 12.h),
            _buildCertificationItem(
              context,
              icon: Icons.school,
              title: 'شهادة سباك معتمد',
              subtitle: 'المعهد المهني للتدريب، 2015',
            ).animate().fadeIn().slideX(delay: 350.ms),
            SizedBox(height: 12.h),
            _buildCertificationItem(
              context,
              icon: Icons.workspace_premium,
              title: 'دورة متقدمة في أنظمة المياه',
              subtitle: 'الجمعية السعودية للمهنيين، 2019',
            ).animate().fadeIn().slideX(delay: 400.ms),
            SizedBox(height: 24.h),

            // Portfolio Section
            Text(
              'معرض الأعمال',
              style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 450.ms),
            SizedBox(height: 12.h),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.7,
              children: [
                _buildPortfolioItem(
                  context,
                  imageUrl:
                      'https://images.unsplash.com/photo-1607400201889-565b1ee75f8e?w=400',
                  title: 'تركيب نظام سباكة',
                  date: 'مارس 2023',
                ),
                _buildPortfolioItem(
                  context,
                  imageUrl:
                      'https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=400',
                  title: 'إصلاح تسريب كبير',
                  date: 'يناير 2023',
                ),
                _buildPortfolioItem(
                  context,
                  imageUrl:
                      'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=400',
                  title: 'تجديد حمام بالكامل',
                  date: 'أكتوبر 2022',
                ),
                _buildPortfolioItem(
                  context,
                  imageUrl:
                      'https://images.unsplash.com/photo-1620626011761-996317b8d101?w=400',
                  title: 'تركيب سخان مياه',
                  date: 'يونيو 2022',
                ),
                _buildAddNewWorkCard(context),
              ],
            ).animate().fadeIn(delay: 500.ms),
            SizedBox(height: 80.h), // Bottom nav padding
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewWorkCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddPortfolioWorkScreen(),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8.r,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 32.s,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'إضافة عمل جديد',
              style: TextStyle(
                fontSize: 13.fz,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 28.s,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioItem(
    BuildContext context, {
    required String imageUrl,
    required String title,
    required String date,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.fz,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  date,
                  style: TextStyle(fontSize: 10.fz, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
