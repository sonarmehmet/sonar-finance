import 'package:flutter_test/flutter_test.dart';
import 'package:sonar_finance/core/money/money.dart';

void main() {
  test('formatMinor / formatMinorTry', () {
    expect(formatMinor(123456), '1.234,56');
    expect(formatMinor(7), '0,07');
    expect(formatMinor(-123456), '-1.234,56');
    expect(formatMinorTry(123456), '1.234,56 ₺');
  });

  test('parseMinor', () {
    expect(parseMinor('1.250,5'), 125050);
    expect(parseMinor('1250'), 125000);
    expect(parseMinor('0,07'), 7);
    expect(parseMinor('1,234'), isNull); // 3 ondalik gecersiz
    expect(parseMinor(''), isNull);
  });

  test('formatMilli / parseMilli', () {
    expect(formatMilli(2500), '2,5');
    expect(formatMilli(3000), '3');
    expect(formatMilli(1), '0,001');
    expect(parseMilli('2,5'), 2500);
    expect(parseMilli('1.000'), 1000000);
  });

  test('formatBp', () {
    expect(formatBp(2000), '%20');
    expect(formatBp(1250), '%12,5');
    expect(formatBp(100), '%1');
  });
}
