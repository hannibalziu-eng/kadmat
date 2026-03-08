import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';
import '../../auth/data/auth_repository.dart';
import '../data/service_repository.dart';
import '../domain/service.dart';

class HomeScreenContent extends ConsumerStatefulWidget {
  const HomeScreenContent({super.key});

  @override
  ConsumerState<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<HomeScreenContent> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allServicesProvider);
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final rawName = (userProfile?['full_name'] as String?)?.trim();
    final userName = rawName == null || rawName.isEmpty
        ? 'ضيف Kadmat'
        : rawName;
    final firstName = userName.split(' ').first.trim();
    final address =
        ((userProfile?['address'] ?? userProfile?['city']) as String?)?.trim();
    final locationLabel = (address == null || address.isEmpty)
        ? 'حدّد موقع الخدمة داخل الطلب'
        : address;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
                      child: Column(
                        children: [
                          _buildTopBar(
                            context,
                            userName: userName,
                            locationLabel: locationLabel,
                          ),
                          SizedBox(height: 16.h),
                          _buildHeroPanel(context, firstName: firstName),
                          SizedBox(height: 18.h),
                          _buildSearchField(context),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: servicesAsync.when(
                      data: (services) => Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: _buildCategoryFilters(context, services),
                      ),
                      loading: () => Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: _buildCategoryFiltersShimmer(),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 10.h),
                      child: servicesAsync.when(
                        data: (services) {
                          final filtered = _filterServices(services);
                          return KadmatSectionHeader(
                            title: 'الخدمات المناسبة لك',
                            subtitle: filtered.isEmpty
                                ? 'غيّر البحث أو الفئة لإظهار نتائج أخرى'
                                : '${filtered.length} خدمة جاهزة للطلب الآن',
                            trailing: TextButton(
                              onPressed: () =>
                                  context.push(AppRoutes.customerCreateRequest),
                              child: const Text('طلب مخصص'),
                            ),
                          );
                        },
                        loading: () => const KadmatSectionHeader(
                          title: 'الخدمات المناسبة لك',
                          subtitle: 'جاري تحميل الخدمات',
                        ),
                        error: (_, __) => const KadmatSectionHeader(
                          title: 'الخدمات المناسبة لك',
                          subtitle: 'تعذر تحميل القائمة الآن',
                        ),
                      ),
                    ),
                  ),
                  servicesAsync.when(
                    data: (services) => _buildServicesGrid(context, services),
                    loading: () => _buildServicesShimmer(),
                    error: (err, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 46.s,
                                color: KadmatColors.lightTextSecondary,
                              ),
                              SizedBox(height: 14.h),
                              Text(
                                'تعذر تحميل الخدمات الآن',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                'أعد المحاولة أو ادخل مباشرة إلى إنشاء طلب جديد.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              SizedBox(height: 16.h),
                              KadmatPrimaryButton(
                                label: 'إعادة المحاولة',
                                icon: Icons.refresh_rounded,
                                onPressed: () =>
                                    ref.invalidate(allServicesProvider),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    required String userName,
    required String locationLabel,
  }) {
    return Row(
      children: [
        Container(
          width: 52.w,
          height: 52.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [KadmatColors.brandPrimary, KadmatColors.brandSecondary],
            ),
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Text(
            userName.characters.first.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلًا، $userName',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: KadmatColors.brandSecondary,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      locationLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        IconButton.filledTonal(
          onPressed: () => context.push(AppRoutes.notifications),
          icon: const Icon(Icons.notifications_none_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0C171C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPanel(BuildContext context, {required String firstName}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17303A), Color(0xFF0F232A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ماذا تحتاج اليوم يا $firstName؟',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26.fz,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'ابدأ طلبًا جديدًا وحدد الخدمة، وسنجهز لك عروض الفنيين مع المتابعة خطوة بخطوة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14.fz,
              height: 1.6,
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: KadmatPrimaryButton(
                  label: 'طلب سريع',
                  icon: Icons.add_task_rounded,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF102127),
                  onPressed: () =>
                      context.push(AppRoutes.customerCreateRequest),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.messages),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('الرسائل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: const [
              _HeroTag(label: 'وصول واضح للفني', icon: Icons.route_rounded),
              _HeroTag(label: 'توثيق بالصور', icon: Icons.photo_camera_back),
              _HeroTag(label: 'تقييمات حقيقية', icon: Icons.stars_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
      decoration: InputDecoration(
        hintText: 'ابحث عن خدمة أو تخصص',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _searchQuery = ''),
              ),
      ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context, List<Service> services) {
    return SizedBox(
      height: 46.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        children: [
          _buildCategoryChip(context, 'الكل', 'all', Icons.dashboard_customize),
          ...services.map(
            (service) => _buildCategoryChip(
              context,
              service.nameAr ?? service.name,
              service.id,
              _getIconForService(service.nameAr ?? service.name),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFiltersShimmer() {
    return SizedBox(
      height: 46.h,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            width: 110.w,
            margin: EdgeInsets.only(left: 10.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
        ),
      ),
    );
  }

  SliverPadding _buildServicesGrid(
    BuildContext context,
    List<Service> services,
  ) {
    final filtered = _filterServices(services);
    if (filtered.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 120.h),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: KadmatColors.lightBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 42.s,
                  color: KadmatColors.lightTextSecondary,
                ),
                SizedBox(height: 12.h),
                Text(
                  'لا توجد نتائج مطابقة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 6.h),
                Text(
                  'جرّب حذف البحث أو اختيار فئة أخرى.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 120.h),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.crossAxisExtent > 720 ? 3 : 2;
          return SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final service = filtered[index];
              return _ServiceCard(
                service: service,
                icon: _getIconForService(service.nameAr ?? service.name),
              );
            }, childCount: filtered.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: constraints.crossAxisExtent > 720 ? 1.12 : 0.92,
            ),
          );
        },
      ),
    );
  }

  SliverPadding _buildServicesShimmer() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 120.h),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
          ),
          childCount: 4,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 0.92,
        ),
      ),
    );
  }

  List<Service> _filterServices(List<Service> services) {
    final query = _searchQuery.trim().toLowerCase();
    return services.where((service) {
      final inCategory =
          _selectedCategory == 'all' || service.id == _selectedCategory;
      final name = (service.nameAr ?? service.name).toLowerCase();
      final matchesQuery = query.isEmpty || name.contains(query);
      return inCategory && matchesQuery;
    }).toList();
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = value),
        backgroundColor: Colors.white,
        selectedColor: KadmatColors.brandPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999.r),
          side: BorderSide(
            color: isSelected ? Colors.transparent : KadmatColors.lightBorder,
          ),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.s,
              color: isSelected
                  ? Colors.white
                  : KadmatColors.lightTextSecondary,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0C171C),
                fontSize: 12.fz,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForService(String name) {
    final value = name.toLowerCase();
    if (value.contains('كهرب') || value.contains('electric')) {
      return Icons.electrical_services_rounded;
    }
    if (value.contains('سباك') || value.contains('plumb')) {
      return Icons.plumbing_rounded;
    }
    if (value.contains('نجار') || value.contains('carpent')) {
      return Icons.carpenter_rounded;
    }
    if (value.contains('دهان') || value.contains('paint')) {
      return Icons.format_paint_rounded;
    }
    if (value.contains('تكييف') || value.contains('ac')) {
      return Icons.ac_unit_rounded;
    }
    return Icons.handyman_rounded;
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15.s),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.fz,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.icon});

  final Service service;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final title = service.nameAr ?? service.name;
    final palette = _paletteForService(title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.customerCreateRequest,
          extra: {'serviceId': service.id, 'serviceName': title},
        ),
        borderRadius: BorderRadius.circular(24.r),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: palette,
            ),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        'من ${service.basePrice.toStringAsFixed(0)} ر.س',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.fz,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.fz,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'اطلب الخدمة، استقبل العروض، وتابع التنفيذ من نفس الشاشة.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.fz,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Text(
                      'ابدأ الطلب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.fz,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 16.s,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _paletteForService(String name) {
    final value = name.toLowerCase();
    if (value.contains('تكييف') || value.contains('ac')) {
      return const [Color(0xFF1696C7), Color(0xFF0F5C7A)];
    }
    if (value.contains('كهرب') || value.contains('electric')) {
      return const [Color(0xFFF59F00), Color(0xFFB96F00)];
    }
    if (value.contains('سباك') || value.contains('plumb')) {
      return const [Color(0xFF2DA0A8), Color(0xFF196C72)];
    }
    if (value.contains('دهان') || value.contains('paint')) {
      return const [Color(0xFF7A5AF8), Color(0xFF4F36C5)];
    }
    return const [Color(0xFF17303A), Color(0xFF102127)];
  }
}
