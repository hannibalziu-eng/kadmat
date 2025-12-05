import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'طلباتي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.search), onPressed: () {}),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.red),
            tooltip: 'محاكاة الفني',
            onPressed: () {
              context.push(
                '/technician-price-input',
                extra: {
                  'orderId': '#ORD-SIM-001',
                  'serviceName': 'إصلاح تسريب مياه',
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                _buildFilterChip('الكل'),
                SizedBox(width: 8.w),
                _buildFilterChip('قيد التنفيذ'),
                SizedBox(width: 8.w),
                _buildFilterChip('مكتملة'),
                SizedBox(width: 8.w),
                _buildFilterChip('ملغاة'),
              ],
            ).animate().fadeIn().slideX(),
          ),

          // Orders List
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children:
                  [
                        _buildOrderCard(
                          title: 'إصلاح تسريب حوض المطبخ',
                          subtitle: 'مقدم الخدمة: يوسف علي',
                          status: 'قيد التنفيذ',
                          statusColor: Colors.blue,
                          statusBgColor: Colors.blue[50]!,
                          price: '150 ر.س',
                          orderId: '#ORD-12345',
                          actions: [
                            _buildActionButton(
                              icon: Icons.chat_bubble_outline,
                              label: 'مراسلة',
                              color: Colors.grey[800]!,
                              bgColor: Colors.grey[200]!,
                              onTap: () {},
                            ),
                            SizedBox(width: 8.w),
                            _buildActionButton(
                              icon: Icons.cancel_outlined,
                              label: 'إلغاء',
                              color: Colors.red[600]!,
                              bgColor: Colors.red[50]!,
                              onTap: () {},
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildOrderCard(
                          title: 'تركيب إضاءة جديدة للغرفة',
                          subtitle: 'المشتري: فاطمة عمر',
                          status: 'مكتمل',
                          statusColor: Colors.green,
                          statusBgColor: Colors.green[50]!,
                          price: '250 ر.س',
                          orderId: '#ORD-12344',
                          actions: [
                            _buildActionButton(
                              icon: Icons.star_outline,
                              label: 'تقييم',
                              color: Colors.white,
                              bgColor: const Color(0xFF13b6ec),
                              onTap: () {},
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildOrderCard(
                          title: 'تصليح باب خشبي',
                          subtitle: 'مقدم الخدمة: أحمد محمد',
                          status: 'ملغي',
                          statusColor: Colors.grey[600]!,
                          statusBgColor: Colors.grey[200]!,
                          price: '100 ر.س',
                          orderId: '#ORD-12343',
                          actions: [
                            _buildActionButton(
                              icon: Icons.info_outline,
                              label: 'عرض التفاصيل',
                              color: Colors.grey[800]!,
                              bgColor: Colors.grey[200]!,
                              onTap: () {},
                            ),
                          ],
                        ),
                        SizedBox(height: 80.h), // Bottom nav padding
                      ]
                      .animate(interval: 100.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
            fontSize: 14.fz,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
    required String price,
    required String orderId,
    required List<Widget> actions,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16.fz,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14.fz,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12.fz,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'السعر الإجمالي',
                          style: TextStyle(
                            fontSize: 12.fz,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 18.fz,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      orderId,
                      style: TextStyle(
                        fontSize: 12.fz,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: actions.map((e) => Expanded(child: e)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40.h,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: bgColor == const Color(0xFF13b6ec)
              ? Theme.of(context).primaryColor
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.s,
              color: bgColor == const Color(0xFF13b6ec)
                  ? Colors.white
                  : Theme.of(context).iconTheme.color,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: bgColor == const Color(0xFF13b6ec)
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13.fz,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
