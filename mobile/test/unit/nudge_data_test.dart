/// Unit tests for nudge data parsing and action-label mapping.
///
/// Verifies the nudge map extraction logic used across
/// dashboard_page.dart (_NudgeCard) and sms_service.dart
/// (_showPendingIncomeNudge) correctly handles complete, partial, and
/// empty API response maps.
library;

import 'package:flutter_test/flutter_test.dart';

// ─── Mirrored helpers (same logic as in _NudgeCard.build and ─────────────────
//     _showPendingIncomeNudge in sms_service.dart)                             //
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> extractNudgeDisplayData(Map<String, dynamic> nudge) {
  return {
    'id': nudge['id'] as int? ?? nudge.hashCode,
    'title': nudge['title'] as String? ?? 'FinGuide Nudge',
    'message': nudge['message'] as String? ?? '',
    'type': nudge['recommendation_type'] as String? ?? 'savings',
    'urgency': nudge['urgency'] as String? ?? 'normal',
    'action_type': nudge['action_type'] as String? ?? 'save',
  };
}

String actionLabel(String actionType) {
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

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('extractNudgeDisplayData — complete map', () {
    late Map<String, dynamic> nudge;

    setUp(() {
      nudge = {
        'id': 42,
        'title': 'Save 5,000 RWF',
        'message': 'You received income. Save 10%.',
        'recommendation_type': 'savings',
        'urgency': 'high',
        'action_type': 'save',
      };
    });

    test('extracts id', () {
      expect(extractNudgeDisplayData(nudge)['id'], 42);
    });

    test('extracts title', () {
      expect(extractNudgeDisplayData(nudge)['title'], 'Save 5,000 RWF');
    });

    test('extracts message', () {
      expect(
        extractNudgeDisplayData(nudge)['message'],
        'You received income. Save 10%.',
      );
    });

    test('extracts recommendation_type', () {
      expect(extractNudgeDisplayData(nudge)['type'], 'savings');
    });

    test('extracts urgency', () {
      expect(extractNudgeDisplayData(nudge)['urgency'], 'high');
    });

    test('extracts action_type', () {
      expect(extractNudgeDisplayData(nudge)['action_type'], 'save');
    });
  });

  group('extractNudgeDisplayData — missing fields use defaults', () {
    test('missing id falls back to hashCode (int)', () {
      final data = extractNudgeDisplayData({'title': 'Test'});
      expect(data['id'], isA<int>());
    });

    test('missing title defaults to "FinGuide Nudge"', () {
      expect(extractNudgeDisplayData({})['title'], 'FinGuide Nudge');
    });

    test('missing message defaults to empty string', () {
      expect(extractNudgeDisplayData({})['message'], '');
    });

    test('missing recommendation_type defaults to "savings"', () {
      expect(extractNudgeDisplayData({})['type'], 'savings');
    });

    test('missing urgency defaults to "normal"', () {
      expect(extractNudgeDisplayData({})['urgency'], 'normal');
    });

    test('missing action_type defaults to "save"', () {
      expect(extractNudgeDisplayData({})['action_type'], 'save');
    });
  });

  group('extractNudgeDisplayData — nudge type variants', () {
    test('investment nudge preserves type and action', () {
      final nudge = {
        'id': 7,
        'title': 'Invest in Ejo Heza',
        'message': 'Grow your wealth.',
        'recommendation_type': 'investment',
        'urgency': 'normal',
        'action_type': 'invest',
      };
      final data = extractNudgeDisplayData(nudge);
      expect(data['type'], 'investment');
      expect(data['action_type'], 'invest');
    });

    test('spending nudge preserves type', () {
      final nudge = {
        'id': 8,
        'title': 'Cut entertainment',
        'message': 'You overspent this week.',
        'recommendation_type': 'spending',
        'urgency': 'high',
        'action_type': 'reduce_spending',
      };
      final data = extractNudgeDisplayData(nudge);
      expect(data['type'], 'spending');
      expect(data['urgency'], 'high');
    });
  });

  group('actionLabel — button copy mapping', () {
    test('"save" → "Save Now"', () {
      expect(actionLabel('save'), 'Save Now');
    });

    test('"invest" → "Invest Now"', () {
      expect(actionLabel('invest'), 'Invest Now');
    });

    test('"reduce_spending" → "View Spending"', () {
      expect(actionLabel('reduce_spending'), 'View Spending');
    });

    test('"view_goals" → "View Goals"', () {
      expect(actionLabel('view_goals'), 'View Goals');
    });

    test('unknown action type defaults to "Save Now"', () {
      expect(actionLabel('unknown_action'), 'Save Now');
    });

    test('empty string defaults to "Save Now"', () {
      expect(actionLabel(''), 'Save Now');
    });
  });
}
