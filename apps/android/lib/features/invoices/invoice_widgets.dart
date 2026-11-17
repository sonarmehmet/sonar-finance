import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/invoice.dart';

/// Fatura durum rozeti: renk `design-tokens.json` `status`, metin `tr.json` `status`.
class InvoiceStatusChip extends ConsumerWidget {
  const InvoiceStatusChip({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final key = invoice.displayStatus();
    return StatusChip(label: s('status.$key'), color: t.statusColor(key));
  }
}

/// Yeni fatura turu secimi (alt sayfa) -> `/invoices/new?type=...`.
Future<void> showNewInvoiceTypeSheet(BuildContext context, WidgetRef ref) {
  final s = ref.read(stringsProvider);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s('invoice.type'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
          ),
          for (final type in invoiceTypes)
            ListTile(
              title: Text(s('invoiceType.$type')),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/invoices/new?type=$type');
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
