import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBase extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBase({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final containerColor = isDark ? Colors.grey[850]! : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100.0,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      padding: const EdgeInsets.all(16.0),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, __) => _buildListItem(context),
    );
  }

  Widget _buildListItem(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? Colors.grey[850]! : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBase(width: 60, height: 60, borderRadius: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBase(width: 150, height: 16),
                const SizedBox(height: 8),
                const SkeletonBase(width: 100, height: 14),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBase(width: 80, height: 14),
                    SkeletonBase(width: 60, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBase(
            width: double.infinity,
            height: 200,
            borderRadius: 16,
          ),
          const SizedBox(height: 24),
          const SkeletonBase(width: 200, height: 24),
          const SizedBox(height: 16),
          const SkeletonBase(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          const SkeletonBase(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          const SkeletonBase(width: 250, height: 16),
          const SizedBox(height: 32),
          const SkeletonBase(width: 150, height: 20),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: SkeletonBase(width: double.infinity, height: 100),
              ),
              SizedBox(width: 16),
              Expanded(
                child: SkeletonBase(width: double.infinity, height: 100),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CardSkeleton extends StatelessWidget {
  final double height;

  const CardSkeleton({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final containerColor = isDark ? Colors.grey[850]! : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: double.infinity,
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
