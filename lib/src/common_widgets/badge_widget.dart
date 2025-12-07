import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

class BadgeWidget extends StatelessWidget {
  final String label;
  final String iconName;
  final String badgeType; // 'verified_pro', 'top_rated', etc.
  final bool isCompact;

  const BadgeWidget({
    super.key,
    required this.label,
    required this.iconName,
    required this.badgeType,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on badge type
    Color backgroundColor;
    Color contentColor;
    IconData iconData;

    switch (badgeType) {
      case 'verified_pro':
        backgroundColor = Colors.blue.withOpacity(0.15);
        contentColor = Colors.blue;
        iconData = Icons.verified;
        break;
      case 'top_rated':
        backgroundColor = Colors.amber.withOpacity(0.15);
        contentColor = Colors.amber;
        iconData = Icons.star;
        break;
      case 'quick_responder':
        backgroundColor = Colors.green.withOpacity(0.15);
        contentColor = Colors.green;
        iconData = Icons.flash_on;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.15);
        contentColor = Colors.grey;
        iconData = Icons.stars;
    }

    if (isCompact) {
      return Tooltip(
        message: label,
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: contentColor.withOpacity(0.5), width: 1),
          ),
          child: Icon(iconData, size: 14.s, color: contentColor),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: contentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16.s, color: contentColor),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.fz,
              fontWeight: FontWeight.bold,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }
}
