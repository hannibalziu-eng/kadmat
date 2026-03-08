import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';
import '../domain/technician_profile.dart';
import 'technician_profile_controller.dart';

class TechnicianPublicProfileScreen extends ConsumerWidget {
  final String technicianId;

  const TechnicianPublicProfileScreen({super.key, required this.technicianId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (technicianId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('بروفايل الفني'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Text(
            'تعذر فتح الملف الشخصي: معرف الفني غير صالح',
            style: TextStyle(color: Colors.white70, fontSize: 14.fz),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final profileAsync = ref.watch(technicianProfileProvider(technicianId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('بروفايل الفني'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              // ============ بيانات الفني الأساسية ============
              _buildTechnicianHeader(context, profile),
              SizedBox(height: 24.h),

              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                _buildAboutSection(profile.bio!),
                SizedBox(height: 24.h),
              ],

              // ============ الإحصائيات ============
              _buildStatisticsSection(profile),
              SizedBox(height: 24.h),

              // ============ الأعمال السابقة (Portfolio) ============
              _buildPortfolioSection(profile),
              SizedBox(height: 24.h),

              // ============ التقييمات والآراء ============
              _buildReviewsSection(profile),
              SizedBox(height: 24.h),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 40.s,
                ),
                SizedBox(height: 10.h),
                Text(
                  _friendlyProfileError(err),
                  style: TextStyle(color: Colors.white70, fontSize: 14.fz),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(technicianProfileProvider(technicianId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyProfileError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('timeout')) {
      return 'تعذر تحميل ملف الفني الآن. تحقق من اتصال الإنترنت ثم حاول مجددًا.';
    }
    if (normalized.contains('jwt') || normalized.contains('unauthorized')) {
      return 'انتهت الجلسة الحالية. أعد تسجيل الدخول للمتابعة.';
    }
    return 'حدث خطأ أثناء تحميل ملف الفني. حاول مرة أخرى.';
  }

  ImageProvider? _networkImageOrNull(String? rawUrl) {
    final url = rawUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return NetworkImage(url);
  }

  // بيانات الفني الأساسية
  Widget _buildTechnicianHeader(
    BuildContext context,
    TechnicianProfile profile,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: AppTheme.glassDecoration(radius: 20.r),
      child: Column(
        children: [
          // صورة الفني
          CircleAvatar(
            radius: 60.r,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: _networkImageOrNull(profile.profileImageUrl),
            child: _networkImageOrNull(profile.profileImageUrl) == null
                ? Icon(Icons.person, color: Colors.white, size: 60.s)
                : null,
          ),
          SizedBox(height: 16.h),

          // اسم الفني
          Text(
            profile.fullName,
            style: TextStyle(
              fontSize: 24.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),

          Text(
            profile.title?.trim().isNotEmpty == true
                ? profile.title!
                : (profile.specialization ?? 'فني خدمات عامة'),
            style: TextStyle(fontSize: 14.fz, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          if (profile.title?.trim().isNotEmpty == true &&
              profile.specialization?.trim().isNotEmpty == true &&
              profile.specialization != profile.title) ...[
            SizedBox(height: 6.h),
            Text(
              profile.specialization!,
              style: TextStyle(fontSize: 12.fz, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: 16.h),

          // التقييم
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < profile.rating.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 20.s,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${profile.rating.toStringAsFixed(1)} (${profile.stats.totalReviews} تقييم)',
                style: TextStyle(
                  fontSize: 14.fz,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // الموقع
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: AppTheme.primaryColor, size: 16.s),
              SizedBox(width: 4.w),
              Text(
                profile.location?.trim().isNotEmpty == true
                    ? profile.location!
                    : 'الموقع غير مضاف',
                style: TextStyle(fontSize: 14.fz, color: Colors.white70),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // أزرار الاتصال والمراسلة
          Row(
            children: [
              // Hidden for now or implement direct call/chat logic if job exists
              // Usually you can only contact if you have an active job
              // For profile view, maybe just show "Hire Me" if coming from search?
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نبذة عن الفني',
          style: TextStyle(
            fontSize: 18.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: AppTheme.glassDecoration(radius: 16.r),
          child: Text(
            bio,
            style: TextStyle(
              fontSize: 14.fz,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // الإحصائيات
  Widget _buildStatisticsSection(TechnicianProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإحصائيات',
          style: TextStyle(
            fontSize: 18.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'الطلبات المكتملة',
                value: '${profile.stats.completedJobs}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                title: 'التقييم العام',
                value: profile.rating.toStringAsFixed(1),
                icon: Icons.thumb_up,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        // Additional rows if needed
      ],
    );
  }

  // بطاقة الإحصائية
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.s),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.fz,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.fz, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // الأعمال السابقة (Portfolio)
  Widget _buildPortfolioSection(TechnicianProfile profile) {
    if (profile.portfolio.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأعمال السابقة',
          style: TextStyle(
            fontSize: 18.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1,
          ),
          itemCount: profile.portfolio.length,
          itemBuilder: (context, index) {
            return _buildPortfolioItem(item: profile.portfolio[index]);
          },
        ),
      ],
    );
  }

  // بطاقة عمل سابق
  Widget _buildPortfolioItem({required PortfolioItem item}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة المشروع
          Expanded(
            child: _networkImageOrNull(item.imageUrl) == null
                ? Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.r),
                        topRight: Radius.circular(12.r),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white70,
                        size: 28.s,
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.r),
                        topRight: Radius.circular(12.r),
                      ),
                      image: DecorationImage(
                        image: _networkImageOrNull(item.imageUrl)!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
          // معلومات المشروع
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title != null && item.title!.isNotEmpty)
                  Text(
                    item.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  if (item.title != null && item.title!.isNotEmpty)
                    SizedBox(height: 4.h),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.fz, color: Colors.white70),
                  ),
                ],
                if (item.projectDate != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    DateFormat('yyyy-MM-dd').format(item.projectDate!),
                    style: TextStyle(fontSize: 10.fz, color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // التقييمات والآراء
  Widget _buildReviewsSection(TechnicianProfile profile) {
    if (profile.reviews.isEmpty) {
      return Center(
        child: Text(
          'لا توجد تقييمات بعد',
          style: TextStyle(color: Colors.white54, fontSize: 14.fz),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'آراء العملاء',
          style: TextStyle(
            fontSize: 18.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12.h),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profile.reviews.length,
          itemBuilder: (context, index) {
            return _buildReviewCard(review: profile.reviews[index]);
          },
        ),
      ],
    );
  }

  // بطاقة تقييم واحد
  Widget _buildReviewCard({required Review review}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppTheme.glassDecoration(radius: 12.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس التقييم
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: _networkImageOrNull(review.reviewerImage),
                child: _networkImageOrNull(review.reviewerImage) == null
                    ? Text(
                        review.reviewerName.isNotEmpty
                            ? review.reviewerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.fz,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: TextStyle(
                        fontSize: 14.fz,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14.s,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          DateFormat('yyyy-MM-dd').format(review.createdAt),
                          style: TextStyle(
                            fontSize: 10.fz,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 13.fz,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
