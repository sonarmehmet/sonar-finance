/// İş tarihleri `"YYYY-MM-DD"` metindir (docs/02): saat dilimi sorunu yok,
/// metin olarak sıralanabilir. Sistem zamanları (`createdAt`) Timestamp'tir.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// DateTime -> "2026-11-16" (yerel gün).
String toIsoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String todayIso() => toIsoDate(DateTime.now());

/// "2026-11-16" -> DateTime(2026, 11, 16). Geçersizse `null`.
DateTime? parseIsoDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  // 31 Şubat gibi taşmaları reddet.
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// "2026-11-16" -> "16.11.2026".
String formatDisplayDate(String iso) {
  final dt = parseIsoDate(iso);
  if (dt == null) return iso;
  return '${_two(dt.day)}.${_two(dt.month)}.${dt.year}';
}

/// "2026-11-16" -> "2026-11" (`stats/summary.months` anahtarı).
String monthKey(String iso) => iso.substring(0, 7);

/// "2026-11-16" -> 2026 (fatura numarası yılı).
int yearOf(String iso) => int.parse(iso.substring(0, 4));

/// Vade geçmiş mi? Aynı gün gecikmiş sayılmaz. ISO metinler sıralanabilir.
bool isOverdue(String dueDate, {String? today}) =>
    dueDate.compareTo(today ?? todayIso()) < 0;
