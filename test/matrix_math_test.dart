import 'package:flutter_test/flutter_test.dart';
import 'package:matrices/core/matrix_math.dart';
import 'package:matrices/core/rational.dart';

void main() {
  group('Rational', () {
    test('lee enteros, decimales con coma y fracciones', () {
      expect(Rational.parse('3').format(), '3');
      expect(Rational.parse('-2,5').format(), '-2.5');
      expect(Rational.parse('6/4').format(asFraction: true), '3/2');
      expect(Rational.parse('−3/4').format(asFraction: true), '-3/4');
      expect(Rational.parse('.5').format(), '0.5');
    });

    test('rechaza lo que no es número', () {
      for (final v in ['', '-', 'abc', '1/0', '1..2', '1/']) {
        expect(Rational.tryParse(v), isNull, reason: v);
      }
    });

    test('suma exacta', () {
      expect((Rational.parse('0.1') + Rational.parse('0.2')).format(), '0.3');
      expect(
        (Rational.parse('1/3') + Rational.parse('1/6')).format(
          asFraction: true,
        ),
        '1/2',
      );
      // 1/3 no tiene decimal finito: va como fracción aunque se pida decimal.
      expect((Rational.parse('1/3') - Rational.parse('0')).format(), '1/3');
      expect(
        (Rational.parse('-0.05') - Rational.parse('0.07')).format(),
        '-0.12',
      );
    });
  });

  group('calculate', () {
    test('suma y resta 2x2', () {
      final a = [
        ['1', '2'],
        ['3', '4'],
      ];
      final b = [
        ['5', '6'],
        ['7', '8'],
      ];
      expect(calculate(MatrixOp.add, a, b).values, [
        ['6', '8'],
        ['10', '12'],
      ]);
      expect(calculate(MatrixOp.subtract, a, b).values, [
        ['-4', '-4'],
        ['-4', '-4'],
      ]);
    });

    test('fracción solo en las celdas con fracción', () {
      final r = calculate(
        MatrixOp.add,
        [
          ['1/2', '0.5'],
        ],
        [
          ['1/4', '1'],
        ],
      );
      expect(r.values, [
        ['3/4', '1.5'],
      ]);
    });

    test('marca celdas vacías o inválidas', () {
      final r = calculate(
        MatrixOp.add,
        [
          ['1', ''],
        ],
        [
          ['x', '2'],
        ],
      );
      expect(r.ok, isFalse);
      expect(r.errors, {
        const CellError('A', 0, 1),
        const CellError('B', 0, 0),
      });
    });
  });
}
