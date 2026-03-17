import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../design/kadmat_tokens.dart';

class KadmatShellNavItemData {
  const KadmatShellNavItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
}

class KadmatShellBottomBar extends StatelessWidget {
  const KadmatShellBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
  });

  final List<KadmatShellNavItemData> items;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 18.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: KadmatColors.lightSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _KadmatShellNavItem(
                data: items[i],
                isSelected: i == currentIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class _KadmatShellNavItem extends StatelessWidget {
  const _KadmatShellNavItem({required this.data, required this.isSelected});

  final KadmatShellNavItemData data;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final labelColor = isSelected ? primary : KadmatColors.lightTextSecondary;

    return Semantics(
      button: true,
      label: data.label,
      selected: isSelected,
      child: Tooltip(
        message: data.label,
        child: GestureDetector(
          onTap: data.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: KadmatMotion.medium,
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: isSelected
                    ? primary.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      data.icon,
                      size: 22.s,
                      color: isSelected ? primary : KadmatColors.lightTextSecondary,
                    ),
                    if (data.badgeCount > 0)
                      Positioned(
                        top: -7,
                        left: -10,
                        child: Container(
                          constraints: BoxConstraints(minWidth: 18.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: KadmatColors.stateError,
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Text(
                            data.badgeCount > 9
                                ? '+9'
                                : data.badgeCount.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.fz,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11.fz,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
