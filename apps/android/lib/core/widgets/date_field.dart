import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../date/date_utils.dart';

/// `YYYY-MM-DD` metin degeri tutan tarih alani (docs/02: is tarihleri metindir).
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final initial = parseIsoDate(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) onChanged(toIsoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(LucideIcons.calendar, size: 18),
          enabled: enabled,
        ),
        child: Text(formatDisplayDate(value)),
      ),
    );
  }
}

/// ISO tarihe gun ekler (vade varsayilani icin).
String addDaysIso(String iso, int days) {
  final d = parseIsoDate(iso) ?? DateTime.now();
  return toIsoDate(DateTime(d.year, d.month, d.day + days));
}
