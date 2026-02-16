import 'package:flutter/material.dart';
import 'package:kadmat/src/features/bidding/domain/entities/bid_entity.dart';

class BidCard extends StatelessWidget {
  final BidEntity bid;
  final bool isCheapest;
  final bool isFastest;
  final bool isHighestRated;
  final VoidCallback onAccept;

  const BidCard({
    super.key,
    required this.bid,
    this.isCheapest = false,
    this.isFastest = false,
    this.isHighestRated = false,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isCheapest ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCheapest
            ? const BorderSide(color: Color(0xFF13b6ec), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Name + Badges
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: bid.technicianAvatar != null
                      ? NetworkImage(bid.technicianAvatar!)
                      : null,
                  child: bid.technicianAvatar == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.technicianName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          Text(' ${bid.rating}'),
                          Text(' • ${bid.completedJobs} مهمة'),
                          if (bid.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Badges
            if (isCheapest || isFastest || isHighestRated) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (isCheapest) _buildBadge('الأرخص', Colors.green),
                  if (isFastest) _buildBadge('الأسرع', Colors.orange),
                  if (isHighestRated)
                    _buildBadge('الأعلى تقييماً', Colors.purple),
                ],
              ),
            ],

            const Divider(height: 24),

            // Price & Duration
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bid.formattedAmount,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF13b6ec),
                      ),
                    ),
                    if (bid.estimatedDurationText != null)
                      Text(
                        'المدة: ${bid.estimatedDurationText}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13b6ec),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('قبول العرض'),
                ),
              ],
            ),

            // Notes
            if (bid.notes != null && bid.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bid.notes!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
