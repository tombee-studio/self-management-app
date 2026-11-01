import 'package:flutter_test/flutter_test.dart';
import 'package:iris_app/features/expenses/domain/services/calculator_parser.dart';

void main() {
  group('CalculatorParser.evaluate', () {
    test('単一の数値を正しく評価する', () {
      expect(CalculatorParser.evaluate('1200'), 1200);
      expect(CalculatorParser.evaluate('0'), 0);
      expect(CalculatorParser.evaluate(''), 0);
    });

    test('加算・減算を正しく評価する', () {
      expect(CalculatorParser.evaluate('100+200'), 300);
      expect(CalculatorParser.evaluate('500-150'), 350);
      expect(CalculatorParser.evaluate('1000-1500'), 0); // 0円未満クリップ
    });

    test('乗除優先順位を正しく評価する', () {
      expect(CalculatorParser.evaluate('100+200*3'), 700);
      expect(CalculatorParser.evaluate('100*2+300*3'), 1100);
      expect(CalculatorParser.evaluate('1000/2-100'), 400);
    });

    test('全角記号（×, ÷）および空白混在を正しく正規化して評価する', () {
      expect(CalculatorParser.evaluate('800 + 480 × 2'), 1760);
      expect(CalculatorParser.evaluate('2000 ÷ 4'), 500);
    });

    test('末尾の未完了演算子を安全に除去して評価する', () {
      expect(CalculatorParser.evaluate('1200+'), 1200);
      expect(CalculatorParser.evaluate('500*'), 500);
      expect(CalculatorParser.evaluate('100+-'), 100);
    });

    test('ゼロ除算時にもクラッシュせず安全にフォールバックする', () {
      expect(CalculatorParser.evaluate('1000/0'), 0);
    });

    test('上限超過は保存可能な金額へ丸めずエラーになる', () {
      expect(CalculatorParser.evaluate('9999999999'), 0);
      expect(
        CalculatorParser.calculate('9999999999').error,
        CalculationError.outOfRange,
      );
    });
  });
}
