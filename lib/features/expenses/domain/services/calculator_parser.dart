class DivisionByZero implements Exception {}

enum CalculationError { empty, invalid, divisionByZero, outOfRange }

class CalculationResult {
  final int? amount;
  final CalculationError? error;
  const CalculationResult.valid(this.amount) : error = null;
  const CalculationResult.invalid(this.error) : amount = null;
  bool get isValid => error == null;
}

/// 電卓テンキーの計算式をパース・評価するユーティリティクラス
class CalculatorParser {
  static const int maxAmount = 99999999;

  /// 入力文字列（例: "800+480*2"）をパース・評価して整数（JPY）を返す。
  static int evaluate(String input) => calculate(input).amount ?? 0;

  static CalculationResult calculate(String input) {
    if (input.trim().isEmpty) {
      return const CalculationResult.invalid(CalculationError.empty);
    }

    // 表記の正規化（全角・記号の統一: ×, ÷ を *, / に置換）
    final normalized = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(' ', '')
        .replaceAll(',', '');

    // 末尾の未完了演算子を除去
    final sanitized = _sanitizeTrailingOperators(normalized);
    if (sanitized.isEmpty) {
      return const CalculationResult.invalid(CalculationError.invalid);
    }

    try {
      final tokens = _tokenize(sanitized);
      if (tokens.isEmpty) {
        return const CalculationResult.invalid(CalculationError.invalid);
      }

      final rpn = _toRPN(tokens);
      final result = _evaluateRPN(rpn);
      if (!result.isFinite || result < 1 || result > maxAmount) {
        return const CalculationResult.invalid(CalculationError.outOfRange);
      }
      return CalculationResult.valid(result.toInt());
    } on DivisionByZero {
      return const CalculationResult.invalid(CalculationError.divisionByZero);
    } catch (_) {
      return const CalculationResult.invalid(CalculationError.invalid);
    }
  }

  /// 末尾に演算子が残っている場合、それを取り除く（例: "1000+" -> "1000"）
  static String _sanitizeTrailingOperators(String input) {
    var s = input;
    while (s.isNotEmpty && _isOperator(s[s.length - 1])) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static bool _isOperator(String ch) {
    return ch == '+' || ch == '-' || ch == '*' || ch == '/';
  }

  /// 式をトークン列（数値と演算子）に分解する
  static List<String> _tokenize(String expr) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];

      if (_isOperator(ch)) {
        // 負の数の先頭（例: "-500" や "*-5"）のハンドリング
        if (ch == '-' && (i == 0 || _isOperator(expr[i - 1]))) {
          buffer.write(ch);
          continue;
        }

        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(ch);
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else {
        throw const FormatException("不正な計算式");
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// 操車場アルゴリズム (Shunting-yard algorithm) による逆ポーランド記法 (RPN) への変換
  static List<String> _toRPN(List<String> tokens) {
    final output = <String>[];
    final opStack = <String>[];

    final precedence = {'+': 1, '-': 1, '*': 2, '/': 2};

    for (final token in tokens) {
      if (_isOperator(token)) {
        while (opStack.isNotEmpty &&
            _isOperator(opStack.last) &&
            precedence[opStack.last]! >= precedence[token]!) {
          output.add(opStack.removeLast());
        }
        opStack.add(token);
      } else {
        output.add(token);
      }
    }

    while (opStack.isNotEmpty) {
      output.add(opStack.removeLast());
    }

    return output;
  }

  /// 逆ポーランド記法の評価
  static double _evaluateRPN(List<String> rpn) {
    final stack = <double>[];

    for (final token in rpn) {
      if (_isOperator(token)) {
        if (stack.length < 2) throw const FormatException("不正な計算式");
        final b = stack.removeLast();
        final a = stack.removeLast();

        switch (token) {
          case '+':
            stack.add(a + b);
            break;
          case '-':
            stack.add(a - b);
            break;
          case '*':
            stack.add(a * b);
            break;
          case '/':
            if (b == 0) {
              throw DivisionByZero();
            } else {
              stack.add(a / b);
            }
            break;
        }
      } else {
        stack.add(double.tryParse(token) ?? 0);
      }
    }

    if (stack.length != 1) throw const FormatException("不正な計算式");
    return stack.single;
  }
}
