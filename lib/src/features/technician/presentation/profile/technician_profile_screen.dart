import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/technician_repository.dart';
import '../../domain/technician_profile.dart';
import 'edit_technician_profile_screen.dart';
import 'add_portfolio_work_screen.dart';

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
          _loadProfile(); // Reload to refresh list
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
    // If loading for the first time
    if (_isLoading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If error
    if (_errorMessage != null && _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملفي الشخصي')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('فشل تحميل البيانات: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    // If loaded (or loading refresh)
    final profile = _profile!;

    // Fallback values if profile fields are missing
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
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'تسجيل الخروج',
            onPressed: _confirmSignOut,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditTechnicianProfileScreen(),
                ),
              ).then((_) => _loadProfile());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: _networkImageOrNull(
                        profile.profileImageUrl,
                      ),
                      child:
                          _networkImageOrNull(profile.profileImageUrl) == null
                          ? Icon(Icons.person, color: Colors.white, size: 34.s)
                          : null,
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
                          title,
                          style: TextStyle(
                            fontSize: 16.fz,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          location,
                          style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn().slideX(),

              SizedBox(height: 24.h),

              // Stats Card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8.r,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${profile.stats.completedJobs}',
                            style: TextStyle(
                              fontSize: 24.fz,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'وظائف مكتملة',
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
                            profile.stats.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 24.fz,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'التقييم العام',
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
              ).animate().fadeIn().slideY(begin: 0.2, delay: 100.ms),
              SizedBox(height: 24.h),

              // Bio Section
              Text(
                'نبذة شخصية',
                style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 200.ms),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8.r,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  bio,
                  style: TextStyle(
                    fontSize: 14.fz,
                    height: 1.6,
                    color: Colors.grey[700],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, delay: 250.ms),
              SizedBox(height: 24.h),

              // Portfolio Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'معرض الأعمال',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 450.ms),
              SizedBox(height: 12.h),

              if (profile.portfolio.isEmpty)
                _buildEmptyPortfolioState()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: profile.portfolio.length + 1, // +1 for Add button
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
                          ? "${work.projectDate!.year}-${work.projectDate!.month}"
                          : '',
                    );
                  },
                ).animate().fadeIn(delay: 500.ms),

              if (profile.portfolio.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 16.h),
                  child: _buildAddNewWorkCard(context),
                ),

              SizedBox(height: 80.h),
            ],
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48.s,
            color: Colors.grey,
          ),
          SizedBox(height: 8.h),
          Text(
            'لا توجد أعمال سابقة',
            style: TextStyle(color: Colors.grey[600]),
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
        height: 156.h,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            width: 2.w,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 24.s,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'إضافة عمل',
              style: TextStyle(
                fontSize: 13.fz,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16.r),
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
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
                        fontWeight: FontWeight.bold,
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
          Positioned(
            top: 4,
            left: 4,
            child: CircleAvatar(
              radius: 14.r,
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              child: IconButton(
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                onPressed: () => _confirmDeleteWork(id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
