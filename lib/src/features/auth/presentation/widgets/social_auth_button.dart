import 'package:flutter/material.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24, color: iconColor),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        backgroundColor: isDarkMode ? const Color(0xFF1a2b32) : Colors.white,
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF233f48) : Colors.grey[300]!,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
