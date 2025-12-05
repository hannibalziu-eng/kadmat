import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:shimmer/shimmer.dart';
import '../data/service_repository.dart';
import '../domain/service.dart';
import '../../auth/data/auth_repository.dart';

class HomeScreenContent extends ConsumerStatefulWidget {
  const HomeScreenContent({super.key});

  @override
  ConsumerState<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<HomeScreenContent> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allServicesProvider);
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final userName = userProfile?['full_name'] ?? 'مرحباً بك';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF13b6ec),
                        width: 2.w,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24.r,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 20.fz,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Greeting & Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$userName 👋',
                          style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16.s,
                              color: const Color(0xFF13b6ec),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'الرياض، السعودية',
                              style: TextStyle(
                                fontSize: 16.fz,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16.s,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Notification Bell
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: EdgeInsets.all(16.0.w),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن خدمة...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Category Filters from API
            servicesAsync.when(
              data: (services) => _buildCategoryFilters(services),
              loading: () => _buildCategoryFiltersShimmer(),
              error: (_, __) => _buildCategoryFiltersShimmer(),
            ),

            SizedBox(height: 16.h),

            // Service Cards from API
            Expanded(
              child: servicesAsync.when(
                data: (services) => _buildServicesList(services),
                loading: () => _buildServicesShimmer(),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48.s, color: Colors.grey),
                      SizedBox(height: 16.h),
                      Text('فشل تحميل الخدمات', style: TextStyle(fontSize: 16.fz)),
                      SizedBox(height: 8.h),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(allServicesProvider),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(List<Service> services) {
    return SizedBox(
      height: 50.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _buildCategoryChip('الكل', 'all', Icons.explore),
          ...services.map((s) => _buildCategoryChip(
            s.nameAr ?? s.name,
            s.id,
            _getIconForService(s.name),
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryFiltersShimmer() {
    return SizedBox(
      height: 50.h,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            width: 80.w,
            margin: EdgeInsets.only(left: 8.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesList(List<Service> services) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: services.length + 1, // +1 for bottom padding
      itemBuilder: (context, index) {
        if (index == services.length) {
          return SizedBox(height: 80.h);
        }
        final service = services[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: _buildServiceCard(
            context,
            service: service,
            title: service.nameAr ?? service.name,
            subtitle: 'السعر يبدأ من ${service.basePrice.toStringAsFixed(0)} ر.س',
            imageUrl: service.iconUrl ?? 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800',
            tag: index == 0 ? 'خدمة مميزة' : null,
            tagColor: const Color(0xFF13b6ec),
          ),
        );
      },
    );
  }

  Widget _buildServicesShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 200.h,
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }

  IconData _getIconForService(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('كهرب') || nameLower.contains('electric')) return Icons.electrical_services;
    if (nameLower.contains('سباك') || nameLower.contains('plumb')) return Icons.plumbing;
    if (nameLower.contains('نجار') || nameLower.contains('carpent')) return Icons.carpenter;
    if (nameLower.contains('دهان') || nameLower.contains('paint')) return Icons.format_paint;
    if (nameLower.contains('تكييف') || nameLower.contains('ac')) return Icons.ac_unit;
    return Icons.build;
  }

  Widget _buildCategoryChip(String label, String value, IconData icon) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: EdgeInsets.only(left: 8.0.w),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18.s,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).iconTheme.color,
            ),
            SizedBox(width: 6.w),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = value);
        },
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required Service service,
    required String title,
    required String subtitle,
    required String imageUrl,
    String? tag,
    Color? tagColor,
  }) {
    return GestureDetector(
      onTap: () => context.push(
        '/service-details',
        extra: {'serviceId': service.id, 'serviceName': title},
      ),
      child: Container(
        height: 200.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor ?? Colors.blue,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.fz,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white, fontSize: 14.fz),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
