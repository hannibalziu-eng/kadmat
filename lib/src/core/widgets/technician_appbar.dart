import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'connection_quality_indicator.dart';
import '../navigation/app_routes.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/notifications/data/notification_repository.dart';

/// Advanced AppBar for Technician Dashboard
/// Features:
/// - Profile avatar with fallback initials
/// - Name display with RTL support
/// - Online/offline status indicator
/// - Notification badge with counter
/// - Popup menu (Settings, Profile, Help, Logout)
/// - Gradient background
/// - Smooth animations
/// - Arabic accessibility labels
class TechnicianAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isOnline;
  final VoidCallback onToggleOnline;
  final String? title;

  const TechnicianAppBar({
    super.key,
    required this.isOnline,
    required this.onToggleOnline,
    this.title,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final unreadCount = ref.watch(liveUnreadNotificationsCountProvider);

    // Extract user info with fallbacks
    final fullName = userProfile?['full_name'] as String? ?? 'الفني';
    final avatarUrl = userProfile?['avatar_url'] as String?;
    final initials = _getInitials(fullName);

    final titleColor = Theme.of(context).textTheme.bodyLarge?.color;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      titleSpacing: 12.w,
      title: Row(
        children: [
          _buildProfileAvatar(
            context,
            avatarUrl: avatarUrl,
            initials: initials,
            isOnline: isOnline,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  style: TextStyle(
                    fontSize: 15.fz,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: 'اسم الفني: $fullName',
                ),
                SizedBox(height: 2.h),
                GestureDetector(
                  onTap: onToggleOnline,
                  child: Row(
                    children: [
                      _buildStatusDot(context, isOnline),
                      SizedBox(width: 4.w),
                      Text(
                        isOnline ? 'متصل - يستقبل الطلبات' : 'غير متصل',
                        style: TextStyle(
                          fontSize: 11.fz,
                          color: isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const ConnectionQualityIndicator(),
        SizedBox(width: 4.w),
        _buildNotificationBell(context, unreadCount),
        _buildPopupMenu(context, ref),
        SizedBox(width: 8.w),
      ],
    );
  }

  /// Build profile avatar with online status indicator
  Widget _buildProfileAvatar(
    BuildContext context, {
    String? avatarUrl,
    required String initials,
    required bool isOnline,
  }) {
    return Semantics(
      label: 'صورة الملف الشخصي',
      child: Stack(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 19.r,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: TextStyle(
                        fontSize: 13.fz,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          // Online Status Dot
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildStatusDot(context, isOnline, size: 10),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Build animated status dot
  Widget _buildStatusDot(
    BuildContext context,
    bool isOnline, {
    double size = 8,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.redAccent,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.red).withValues(
              alpha: 0.4,
            ),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  /// Build notification bell with badge counter
  Widget _buildNotificationBell(BuildContext context, int unreadCount) {
    return Semantics(
      label: unreadCount > 0
          ? 'الإشعارات، لديك $unreadCount إشعارات غير مقروءة'
          : 'الإشعارات',
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active
                    : Icons.notifications_outlined,
                color: Theme.of(context).iconTheme.color,
                size: 22.s,
              ),
              onPressed: () => context.push(AppRoutes.notifications),
              tooltip: 'الإشعارات',
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: 6,
              right: 6,
              child:
                  Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minWidth: 18.w,
                          minHeight: 18.w,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.fz,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: 800.ms,
                      ),
            ),
        ],
      ),
    );
  }

  /// Build popup menu with options
  Widget _buildPopupMenu(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'القائمة',
      button: true,
      child: PopupMenuButton<String>(
        icon: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Icon(
            Icons.more_vert,
            color: Theme.of(context).iconTheme.color,
            size: 20.s,
          ),
        ),
        tooltip: 'المزيد',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        offset: Offset(0, 45.h),
        onSelected: (value) => _handleMenuSelection(context, ref, value),
        itemBuilder: (context) => [
          _buildMenuItem(
            icon: Icons.person_outline,
            label: 'الملف الشخصي',
            value: 'profile',
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            label: 'الإعدادات',
            value: 'settings',
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            label: 'المساعدة',
            value: 'help',
          ),
          const PopupMenuDivider(),
          _buildMenuItem(
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            value: 'logout',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// Build single menu item
  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20.s, color: isDestructive ? Colors.red : null),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.fz,
              color: isDestructive ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle menu item selection
  void _handleMenuSelection(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'profile':
        final userId =
            ref.read(authRepositoryProvider).userProfile?['id'] as String?;
        if (userId != null) {
          context.push(AppRoutes.buildTechnicianProfilePath(userId));
        }
        break;
      case 'settings':
        context.push(AppRoutes.technicianSettings);
        break;
      case 'help':
        context.push(AppRoutes.technicianHelp);
        break;
      case 'logout':
        _showLogoutConfirmation(context, ref);
        break;
    }
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red, size: 24.s),
            SizedBox(width: 8.w),
            const Text('تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authRepositoryProvider).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  /// Get initials from full name
  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return 'ف';
    if (parts.length == 1) return parts[0].isNotEmpty ? parts[0][0] : 'ف';
    return '${parts[0][0]}${parts[1][0]}';
  }
}
