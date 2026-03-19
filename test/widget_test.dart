import 'package:flutter_test/flutter_test.dart';
import 'package:health_predictor/models/prediction.dart';

void main() {
  group('Prediction', () {
    test('riskLabel returns correct labels for each range', () {
      expect(
        Prediction(dateKey: 'd', pToday: 0.7, confidence: 'high').riskLabel,
        '高め',
      );
      expect(
        Prediction(dateKey: 'd', pToday: 0.45, confidence: 'high').riskLabel,
        'やや注意',
      );
      expect(
        Prediction(dateKey: 'd', pToday: 0.25, confidence: 'high').riskLabel,
        '低め',
      );
      expect(
        Prediction(dateKey: 'd', pToday: 0.1, confidence: 'high').riskLabel,
        '良好',
      );
    });

    test('displayPToday clips probability when confidence is low', () {
      final pred = Prediction(dateKey: 'd', pToday: 0.05, confidence: 'low');
      expect(pred.displayPToday, 0.15);

      final pred2 = Prediction(dateKey: 'd', pToday: 0.9, confidence: 'low');
      expect(pred2.displayPToday, 0.65);
    });

    test('displayPToday does not clip when confidence is high', () {
      final pred = Prediction(dateKey: 'd', pToday: 0.05, confidence: 'high');
      expect(pred.displayPToday, 0.05);

      final pred2 = Prediction(dateKey: 'd', pToday: 0.9, confidence: 'high');
      expect(pred2.displayPToday, 0.9);
    });

    test('riskPercent formats correctly', () {
      final pred = Prediction(dateKey: 'd', pToday: 0.456, confidence: 'high');
      expect(pred.riskPercent, '46%');
    });

    test('confidenceLabel returns Japanese labels', () {
      expect(
        Prediction(dateKey: 'd', confidence: 'high').confidenceLabel,
        '高',
      );
      expect(
        Prediction(dateKey: 'd', confidence: 'medium').confidenceLabel,
        '中',
      );
      expect(
        Prediction(dateKey: 'd', confidence: 'low').confidenceLabel,
        '低',
      );
    });

    test('confidenceNote only shown for low confidence', () {
      expect(
        Prediction(dateKey: 'd', confidence: 'low').confidenceNote,
        isNotNull,
      );
      expect(
        Prediction(dateKey: 'd', confidence: 'high').confidenceNote,
        isNull,
      );
    });
  });

  group('FeatureContribution', () {
    test('label returns Japanese name for known features', () {
      final c = FeatureContribution(feature: 'mood_lag1', value: 0.5);
      expect(c.label, '前日の体調');
    });

    test('label returns raw feature name for unknown features', () {
      final c = FeatureContribution(feature: 'unknown_feat', value: 0.1);
      expect(c.label, 'unknown_feat');
    });

    test('isRiskIncrease is true for positive values', () {
      expect(
        FeatureContribution(feature: 'x', value: 0.1).isRiskIncrease,
        true,
      );
      expect(
        FeatureContribution(feature: 'x', value: -0.1).isRiskIncrease,
        false,
      );
    });
  });
}
