import 'package:flutter/material.dart';
import '../../../app_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('لوحة تحكم المشرف'),
        backgroundColor: Colors.transparent,
      ),
      body: const Center(
        child: Text(
          'قريباً',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
