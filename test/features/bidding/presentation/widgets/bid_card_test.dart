import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/bidding/domain/entities/bid_entity.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/bid_card.dart';

void main() {
  final mockBid = BidEntity(
    id: '1',
    jobId: 'job1',
    technicianId: 'tech1',
    amount: 100.0,
    technicianName: 'Ahmed Technician',
    rating: 4.8,
    completedJobs: 50,
    isVerified: true,
    submittedAt: DateTime.now(),
    status: BidStatus.pending,
  );

  group('BidCard', () {
    testWidgets('renders bid details correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BidCard(bid: mockBid, onAccept: () {}),
          ),
        ),
      );

      expect(find.text('Ahmed Technician'), findsOneWidget);
      expect(find.text('100 ريال'), findsOneWidget);
      expect(find.textContaining('50 مهمة'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('shows badges when flags are true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BidCard(
              bid: mockBid,
              isCheapest: true,
              isFastest: true,
              isHighestRated: true,
              onAccept: () {},
            ),
          ),
        ),
      );

      expect(find.text('الأرخص'), findsOneWidget);
      expect(find.text('الأسرع'), findsOneWidget);
      expect(find.text('الأعلى تقييماً'), findsOneWidget);
    });

    testWidgets('calls onAccept when button pressed', (tester) async {
      var accepted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BidCard(bid: mockBid, onAccept: () => accepted = true),
          ),
        ),
      );

      await tester.pumpAndSettle(); // Ensure frame is settled

      await tester.tap(find.text('قبول العرض'));
      expect(accepted, isTrue);
    });
  });
}
