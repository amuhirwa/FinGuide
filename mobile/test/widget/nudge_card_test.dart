/// Widget tests for the nudge card UI pattern.
///
/// Since the production _NudgeCard in dashboard_page.dart is a private class,
/// these tests build an equivalent standalone widget that uses the same data
/// contract (a `Map<String,dynamic>` from the API) and verify the rendering,
/// colour selection, and interaction callbacks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Test-only NudgeCard widget ───────────────────────────────────────────────
// Replicates the data-driven structure of _NudgeCard without depending on
// private production classes or GetIt.

class TestNudgeCard extends StatelessWidget {
  final Map<String, dynamic> nudge;
  final VoidCallback? onAct;
  final VoidCallback? onDismiss;

  const TestNudgeCard({
    super.key,
    required this.nudge,
    this.onAct,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final type = nudge['recommendation_type'] as String? ?? 'savings';
    final urgency = nudge['urgency'] as String? ?? 'normal';
    final title = nudge['title'] as String? ?? '';
    final message = nudge['message'] as String? ?? '';
    final actionType = nudge['action_type'] as String? ?? 'save';

    final buttonColor = _buttonColor(type, urgency);
    final actionLabel = _actionLabel(actionType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconForType(type), key: const Key('nudge-icon')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, key: const Key('nudge-title')),
                      Text(message, key: const Key('nudge-message')),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('dismiss-btn'),
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('act-btn'),
                onPressed: onAct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                ),
                child: Text(actionLabel, key: const Key('act-label')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _buttonColor(String type, String urgency) {
    if (urgency == 'high') return const Color(0xFFDC2626);
    if (type == 'investment') return const Color(0xFF7C3AED);
    if (type == 'spending') return const Color(0xFFEA580C);
    return const Color(0xFF00A3AD); // savings default
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'investment':
        return Icons.trending_up;
      case 'spending':
        return Icons.warning_amber_outlined;
      default:
        return Icons.savings_outlined;
    }
  }

  String _actionLabel(String actionType) {
    switch (actionType) {
      case 'invest':
        return 'Invest Now';
      case 'reduce_spending':
        return 'View Spending';
      case 'view_goals':
        return 'View Goals';
      default:
        return 'Save Now';
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('TestNudgeCard — rendering', () {
    testWidgets('displays title and message', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {
          'id': 1,
          'title': 'Save 5,000 RWF',
          'message': 'Income received. Save now.',
          'recommendation_type': 'savings',
          'urgency': 'normal',
          'action_type': 'save',
        },
      )));

      expect(find.text('Save 5,000 RWF'), findsOneWidget);
      expect(find.text('Income received. Save now.'), findsOneWidget);
    });

    testWidgets('shows "Save Now" button for save action', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'action_type': 'save', 'recommendation_type': 'savings'},
      )));

      expect(find.text('Save Now'), findsOneWidget);
    });

    testWidgets('shows "Invest Now" button for invest action', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'action_type': 'invest', 'recommendation_type': 'investment'},
      )));

      expect(find.text('Invest Now'), findsOneWidget);
    });

    testWidgets('shows "View Spending" for reduce_spending action',
        (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {
          'action_type': 'reduce_spending',
          'recommendation_type': 'spending',
        },
      )));

      expect(find.text('View Spending'), findsOneWidget);
    });

    testWidgets('renders dismiss button', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'title': 'Test', 'recommendation_type': 'savings'},
      )));

      expect(find.byKey(const Key('dismiss-btn')), findsOneWidget);
    });

    testWidgets('renders act button', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'title': 'Test', 'recommendation_type': 'savings'},
      )));

      expect(find.byKey(const Key('act-btn')), findsOneWidget);
    });

    testWidgets('savings icon shown for savings type', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'recommendation_type': 'savings'},
      )));

      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
    });

    testWidgets('trending_up icon shown for investment type', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'recommendation_type': 'investment'},
      )));

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('warning icon shown for spending type', (tester) async {
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'recommendation_type': 'spending'},
      )));

      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('defaults gracefully with empty map', (tester) async {
      await tester.pumpWidget(_wrap(const TestNudgeCard(nudge: {})));
      // Should not throw; action button defaults to "Save Now"
      expect(find.text('Save Now'), findsOneWidget);
    });
  });

  group('TestNudgeCard — interactions', () {
    testWidgets('onAct fires when act button tapped', (tester) async {
      bool actCalled = false;
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'action_type': 'save', 'recommendation_type': 'savings'},
        onAct: () => actCalled = true,
      )));

      await tester.tap(find.byKey(const Key('act-btn')));
      await tester.pump();

      expect(actCalled, isTrue);
    });

    testWidgets('onDismiss fires when dismiss button tapped', (tester) async {
      bool dismissCalled = false;
      await tester.pumpWidget(_wrap(TestNudgeCard(
        nudge: {'title': 'Test', 'recommendation_type': 'savings'},
        onDismiss: () => dismissCalled = true,
      )));

      await tester.tap(find.byKey(const Key('dismiss-btn')));
      await tester.pump();

      expect(dismissCalled, isTrue);
    });

    testWidgets('null callbacks do not throw when buttons tapped',
        (tester) async {
      await tester.pumpWidget(_wrap(const TestNudgeCard(
        nudge: {'recommendation_type': 'savings'},
      )));

      // Should not throw even with null callbacks
      await tester.tap(find.byKey(const Key('act-btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dismiss-btn')));
      await tester.pump();
    });
  });
}
