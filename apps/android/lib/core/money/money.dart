/// Para, miktar ve oran yardımcıları (docs/02 "Genel kurallar", docs/04 §2).
///
/// Para: tam sayı kuruş (`...Minor`). Miktar: 1/1000 birim (`...Milli`).
/// Oran: baz puan (`...Bp`). Hiçbir yerde `double` kullanılmaz.
library;

/// `roundHalfUp(a / b)` = `(2*a + b) ~/ (2*b)` (a >= 0, b > 0).
/// Negatif `a` için `sign * roundHalfUp(|a| / b)`.
int roundHalfUp(int a, int b) {
  if (b <= 0) {
    throw ArgumentError.value(b, 'b', 'bölen pozitif olmalı');
  }
  final sign = a < 0 ? -1 : 1;
  final abs = a.abs();
  return sign * ((2 * abs + b) ~/ (2 * b));
}


/// Noktalı ondalık girdiyi ("12.5", "1.25") Türkçe biçime çevirir: virgül yoksa ve
/// tek bir nokta varsa, noktadan sonra 1-2 hane ondalık sayılır ("1.250" binliktir).
String _normalizeDecimal(String s) {
  if (s.contains(',')) return s;
  final first = s.indexOf('.');
  if (first == -1 || first != s.lastIndexOf('.')) return s;
  final after = s.length - first - 1;
  return (after == 1 || after == 2) ? s.replaceFirst('.', ',') : s;
}

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// 123456 -> "1.234,56". Sembolsüz; işaret başta ("-1.234,56").
String formatMinor(int minor) {
  final neg = minor < 0;
  final abs = minor.abs();
  final whole = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}${_group(whole.toString())},$frac';
}

/// 123456 -> "1.234,56 ₺".
String formatMinorTry(int minor) => '${formatMinor(minor)} ₺';

/// Türkçe girdiyi kuruşa çevirir: nokta binlik, virgül ondalık.
/// "1.250,5" -> 125050, "1250" -> 125000, "0,07" -> 7.
/// Geçersizse `null`. Kuruştan fazla hane (3+ ondalık) geçersizdir.
int? parseMinor(String input) {
  final s = _normalizeDecimal(
      input.trim().replaceAll(' ', '').replaceAll('₺', ''),
  );
  if (s.isEmpty) return null;
  var neg = false;
  var body = s;
  if (body.startsWith('-')) {
    neg = true;
    body = body.substring(1);
  }
  final parts = body.split(',');
  if (parts.length > 2) return null;
  final wholeRaw = parts[0];
  final fracRaw = parts.length == 2 ? parts[1] : '';
  if (fracRaw.length > 2) return null;
  // Binlik noktaları: ilk grup 1-3 hane, sonrakiler tam 3 hane.
  final groups = wholeRaw.split('.');
  if (groups.length > 1) {
    if (groups.first.isEmpty || groups.first.length > 3) return null;
    if (groups.skip(1).any((g) => g.length != 3)) return null;
  }
  final wholeDigits = groups.join();
  if (wholeDigits.isEmpty && fracRaw.isEmpty) return null;
  if (!RegExp(r'^\d*$').hasMatch(wholeDigits) ||
      !RegExp(r'^\d*$').hasMatch(fracRaw)) {
    return null;
  }
  final whole = wholeDigits.isEmpty ? 0 : int.parse(wholeDigits);
  final frac = fracRaw.isEmpty ? 0 : int.parse(fracRaw.padRight(2, '0'));
  final v = whole * 100 + frac;
  return neg ? -v : v;
}

/// 2500 -> "2,5"; 3000 -> "3"; 1 -> "0,001". Sondaki sıfırlar atılır.
String formatMilli(int milli) {
  final neg = milli < 0;
  final abs = milli.abs();
  final whole = abs ~/ 1000;
  var frac = (abs % 1000).toString().padLeft(3, '0');
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final w = _group(whole.toString());
  return '${neg ? '-' : ''}$w${frac.isEmpty ? '' : ',$frac'}';
}

/// "2,5" -> 2500, "1.000" -> 1000000. En çok 3 ondalık. Geçersizse `null`.
int? parseMilli(String input) {
  final s = _normalizeDecimal(input.trim().replaceAll(' ', ''));
  if (s.isEmpty) return null;
  var neg = false;
  var body = s;
  if (body.startsWith('-')) {
    neg = true;
    body = body.substring(1);
  }
  final parts = body.split(',');
  if (parts.length > 2) return null;
  final fracRaw = parts.length == 2 ? parts[1] : '';
  if (fracRaw.length > 3) return null;
  final groups = parts[0].split('.');
  if (groups.length > 1) {
    if (groups.first.isEmpty || groups.first.length > 3) return null;
    if (groups.skip(1).any((g) => g.length != 3)) return null;
  }
  final wholeDigits = groups.join();
  if (wholeDigits.isEmpty && fracRaw.isEmpty) return null;
  if (!RegExp(r'^\d*$').hasMatch(wholeDigits) ||
      !RegExp(r'^\d*$').hasMatch(fracRaw)) {
    return null;
  }
  final whole = wholeDigits.isEmpty ? 0 : int.parse(wholeDigits);
  final frac = fracRaw.isEmpty ? 0 : int.parse(fracRaw.padRight(3, '0'));
  final v = whole * 1000 + frac;
  return neg ? -v : v;
}

/// 2000 -> "%20"; 1250 -> "%12,5"; 100 -> "%1".
String formatBp(int bp) {
  final whole = bp ~/ 100;
  final frac = (bp.abs() % 100).toString().padLeft(2, '0').replaceFirst(
        RegExp(r'0+$'),
        '',
      );
  return '%$whole${frac.isEmpty ? '' : ',$frac'}';
}

/// 1250 -> "12,5"; 2000 -> "20". Yüzde girişi için (`%` işareti yok).
String formatBpPlain(int bp) => formatBp(bp).substring(1);

/// "12,5" -> 1250; "20" -> 2000. 0..10000 dışı veya geçersizse `null`.
/// (Yüzde × 100 = baz puan; `parseMinor` ile aynı ondalık kuralları.)
int? parseBp(String input) {
  final v = parseMinor(input);
  return (v == null || v < 0 || v > 10000) ? null : v;
}
