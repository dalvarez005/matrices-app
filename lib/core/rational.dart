/// Número racional exacto: 0.1 + 0.2 da 0.3 y 1/3 + 1/6 da 1/2.
/// Es la misma aritmética que usa la API.
class Rational {
  Rational._(this.num, this.den);

  factory Rational(BigInt num, BigInt den) {
    if (den == BigInt.zero) throw const FormatException('División entre cero');
    if (den.isNegative) {
      num = -num;
      den = -den;
    }
    final g = num.gcd(den);
    return g == BigInt.zero || g == BigInt.one
        ? Rational._(num, den)
        : Rational._(num ~/ g, den ~/ g);
  }

  final BigInt num;
  final BigInt den;

  static final _decimal = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$');

  /// Acepta "3", "-2.5", "2,5", "1/2", "-3/4" y "1.5/2". Lanza
  /// [FormatException] si el texto no es un número.
  static Rational parse(String raw) {
    final text = raw.trim().replaceAll(',', '.').replaceAll('−', '-');
    if (text.isEmpty) throw const FormatException('Vacío');
    final slash = text.indexOf('/');
    if (slash >= 0) {
      final n = _parseDecimal(text.substring(0, slash));
      final d = _parseDecimal(text.substring(slash + 1));
      return Rational(n.num * d.den, n.den * d.num);
    }
    return _parseDecimal(text);
  }

  static Rational? tryParse(String raw) {
    try {
      return parse(raw);
    } on FormatException {
      return null;
    }
  }

  static Rational _parseDecimal(String raw) {
    final text = raw.trim();
    if (!_decimal.hasMatch(text)) {
      throw FormatException('No es un número: $raw');
    }
    final negative = text.startsWith('-');
    final body = text.replaceFirst(RegExp(r'^[+-]'), '');
    final parts = body.split('.');
    final decimals = parts.length > 1 ? parts[1] : '';
    final digits = '${parts[0]}$decimals';
    final n = BigInt.parse(digits.isEmpty ? '0' : digits);
    return Rational(negative ? -n : n, BigInt.from(10).pow(decimals.length));
  }

  Rational operator +(Rational o) =>
      Rational(num * o.den + o.num * den, den * o.den);
  Rational operator -(Rational o) =>
      Rational(num * o.den - o.num * den, den * o.den);

  @override
  bool operator ==(Object other) =>
      other is Rational && other.num == num && other.den == den;

  @override
  int get hashCode => Object.hash(num, den);

  /// Como fracción ("5/2") o como decimal ("2.5"). Si el decimal no es
  /// finito (1/3) siempre va como fracción.
  String format({bool asFraction = false}) {
    if (den == BigInt.one) return num.toString();
    if (asFraction || !_finiteDecimal) return '$num/$den';
    var d = den;
    var k = 0;
    final two = BigInt.two, five = BigInt.from(5);
    while (d % two == BigInt.zero || d % five == BigInt.zero) {
      d = d % two == BigInt.zero ? d ~/ two : d ~/ five;
      k++;
    }
    final scaled = (num.abs() * BigInt.from(10).pow(k)) ~/ den;
    final s = scaled.toString().padLeft(k + 1, '0');
    final intPart = s.substring(0, s.length - k);
    final frac = s.substring(s.length - k).replaceFirst(RegExp(r'0+$'), '');
    return '${num.isNegative ? '-' : ''}$intPart${frac.isEmpty ? '' : '.$frac'}';
  }

  bool get _finiteDecimal {
    var d = den;
    for (final p in [BigInt.two, BigInt.from(5)]) {
      while (d % p == BigInt.zero) {
        d = d ~/ p;
      }
    }
    return d == BigInt.one;
  }

  @override
  String toString() => format();
}
