import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/widgets/kadmat_components.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/technician_repository.dart';
import '../../domain/technician_profile.dart';
import 'add_portfolio_work_screen.dart';
import 'edit_technician_profile_screen.dart';

class TechnicianProfileScreen extends ConsumerStatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  ConsumerState<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState
    extends ConsumerState<TechnicianProfileScreen> {
  TechnicianProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  ImageProvider? _networkImageOrNull(String? rawUrl) {
    final url = rawUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await ref
          .read(technicianRepositoryProvider)
          .getTechnicianProfile(user.id);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyProfileError(e);
        });
      }
    }
  }

  Future<void> _confirmDeleteWork(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العمل'),
        content: const Text('هل أنت متأكد من حذف هذا العمل من معرض أعمالك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(technicianRepositoryProvider).deletePortfolioWork(id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف العمل بنجاح')));
          _loadProfile();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_friendlyProfileError(e))));
        }
      }
    }
  }

  String _friendlyProfileError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت الآن.';
    }
    if (normalized.contains('invalidjwttoken') ||
        normalized.contains('jwt') ||
        normalized.contains('expired')) {
      return 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';
    }
    return 'تعذر إتمام العملية حالياً. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null && _profile == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: KadmatColors.lightBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: KadmatColors.stateError,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: 16.h),
                    KadmatPrimaryButton(
                      label: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: _loadProfile,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final profile = _profile!;
    final fullName = profile.fullName;
    final title = profile.title?.trim().isNotEmpty == true
        ? profile.title!
        : (profile.specialization?.trim().isNotEmpty == true
              ? profile.specialization!
              : 'فني');
    final bio = profile.bio ?? 'لا توجد نبذة شخصية';
    final location = profile.location ?? 'غير محدد';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHero(
                  fullName: fullName,
                  title: title,
                  location: location,
                  profileImage: _networkImageOrNull(profile.profileImageUrl),
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const EditTechnicianProfileScreen(),
                      ),
                    ).then((_) => _loadProfile());
                  },
                  onSignOut: _confirmSignOut,
                ),
                SizedBox(height: 18.h),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'وظائف مكتملة',
                        value: '${profile.stats.completedJobs}',
                        icon: Icons.verified_outlined,
                        accent: KadmatColors.stateSuccess,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _StatCard(
                        label: 'التقييم العام',
                        value: profile.stats.rating.toStringAsFixed(1),
                        icon: Icons.star_outline_rounded,
                        accent: KadmatColors.stateWarning,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                _SectionCard(
                  title: 'نبذة شخصية',
                  subtitle:
                      'هذه النبذة تظهر للعميل في ملفك العام، لذلك اجعلها واضحة ومباشرة.',
                  child: Text(
                    bio,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ),
                SizedBox(height: 18.h),
                _SectionCard(
                  title: 'معرض الأعمال',
                  subtitle:
                      'اعرض نماذج فعلية من أعمالك السابقة حتى تزيد الثقة وتحسن قرار العميل.',
                  child: Column(
                    children: [
                      if (profile.portfolio.isEmpty) ...[
                        _buildEmptyPortfolioState(),
                        SizedBox(height: 16.h),
                        _buildAddNewWorkCard(context),
                      ] else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12.w,
                                mainAxisSpacing: 12.h,
                                childAspectRatio: 0.82,
                              ),
                          itemCount: profile.portfolio.length + 1,
                          itemBuilder: (context, index) {
                            if (index == profile.portfolio.length) {
                              return _buildAddNewWorkCard(context);
                            }
                            final work = profile.portfolio[index];
                            return _buildPortfolioItem(
                              context,
                              id: work.id,
                              imageUrl: work.imageUrl,
                              title: work.title ?? 'عمل سابق',
                              date: work.projectDate != null
                                  ? '${work.projectDate!.year}-${work.projectDate!.month}'
                                  : '',
                            );
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 80.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      context.go(AppRoutes.technicianLogin);
    }
  }

  Widget _buildEmptyPortfolioState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48.s,
            color: KadmatColors.lightTextSecondary,
          ),
          SizedBox(height: 8.h),
          Text(
            'لا توجد أعمال سابقة',
            style: TextStyle(color: KadmatColors.lightTextSecondary),
          ),
        ],
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
        ).then((_) => _loadProfile());
      },
      child: Container(
        height: 172.h,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: KadmatColors.brandPrimary.withValues(alpha: 0.35),
            width: 2.w,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: const BoxDecoration(
                color: KadmatColors.brandAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 24.s,
                color: KadmatColors.brandSecondary,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'إضافة عمل',
              style: TextStyle(
                fontSize: 13.fz,
                fontWeight: FontWeight.w700,
                color: KadmatColors.brandSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioItem(
    BuildContext context, {
    required String id,
    required String imageUrl,
    required String title,
    required String date,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20.r),
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 8,
            child: CircleAvatar(
              radius: 16.r,
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteWork(id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.fullName,
    required this.title,
    required this.location,
    required this.profileImage,
    required this.onEdit,
    required this.onSignOut,
  });

  final String fullName;
  final String title;
  final String location;
  final ImageProvider? profileImage;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF19323C), Color(0xFF0E2028)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34.r,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                backgroundImage: profileImage,
                child: profileImage == null
                    ? Text(
                        fullName.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.fz,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '$title\n$location',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13.fz,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: KadmatPrimaryButton(
                  label: 'تعديل الملف',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: KadmatSecondaryButton(
                  label: 'تسجيل الخروج',
                  icon: Icons.logout_rounded,
                  onPressed: onSignOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: accent, size: 18.s),
          ),
          SizedBox(height: 12.h),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 4.h),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6.h),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}
