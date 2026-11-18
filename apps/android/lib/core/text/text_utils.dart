/// Turkce uyumlu arama normallestirmesi: buyuk/kucuk harf ve aksan farkini yok sayar.
/// "İSTANBUL", "istanbul", "Istanbul" ve "ıstanbul" ayni sonucu verir.
String foldTr(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    final c = String.fromCharCode(r);
    switch (c) {
      case 'İ':
      case 'I':
      case 'ı':
        b.write('i');
      case 'Ş':
      case 'ş':
        b.write('s');
      case 'Ğ':
      case 'ğ':
        b.write('g');
      case 'Ü':
      case 'ü':
        b.write('u');
      case 'Ö':
      case 'ö':
        b.write('o');
      case 'Ç':
      case 'ç':
        b.write('c');
      default:
        b.write(c.toLowerCase());
    }
  }
  return b.toString();
}

/// [haystacks] içinden herhangi biri [query]'yi (normallestirilmis) iceriyor mu?
bool matchesQuery(String query, Iterable<String> haystacks) {
  final q = foldTr(query.trim());
  if (q.isEmpty) return true;
  return haystacks.any((h) => foldTr(h).contains(q));
}
