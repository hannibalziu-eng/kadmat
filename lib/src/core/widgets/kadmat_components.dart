import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../app_theme.dart';
import '../design/kadmat_tokens.dart';

class KadmatPrimaryButton extends StatelessWidget {
  const KadmatPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.maxLines = 2,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final int maxLines;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 20.s,
            height: 20.s,
            child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.s),
                SizedBox(width: KadmatSpacing.xs.w),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight.h),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: backgroundColor == null && foregroundColor == null
            ? null
            : ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                padding: EdgeInsets.symmetric(
                  horizontal: KadmatSpacing.md.w,
                  vertical: 12.h,
                ),
              ),
        child: child,
      ),
    );
  }
}

class KadmatSecondaryButton extends StatelessWidget {
  const KadmatSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.maxLines = 2,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final int maxLines;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight.h),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: KadmatSpacing.md.w,
            vertical: 12.h,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.circle_outlined, size: 18.s),
            SizedBox(width: KadmatSpacing.xs.w),
            Flexible(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KadmatTextField extends StatelessWidget {
  const KadmatTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class KadmatCard extends StatelessWidget {
  const KadmatCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: AppTheme.glassDecoration(
        radius: KadmatRadius.lg.r,
        color: AppTheme.surfaceDark,
      ),
      padding: padding ?? EdgeInsets.all(KadmatSpacing.md.w),
      child: child,
    );

    if (onTap == null) {
      return body;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KadmatRadius.lg.r),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class KadmatSectionHeader extends StatelessWidget {
  const KadmatSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              if (subtitle != null) ...[
                SizedBox(height: KadmatSpacing.xxs.h),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
