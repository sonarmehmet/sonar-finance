import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentsListScreen extends ConsumerStatefulWidget {
  const PaymentsListScreen({super.key});
  @override
  ConsumerState<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends ConsumerState<PaymentsListScreen> {
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite = ref.watch(userProfileProvider).valueOrNull?.can('finance.write') ?? false;
    final list = ref.watch(paymentsProvider(_limit));
    return Scaffold(
      appBar: AppBar(title: Text(s('payment.list'))),
      floatingActionButton: canWrite
          ? PopupMenuButton<String>(
              onSelected: (d) => context.push('/payments/new?direction=$d'),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'in', child: Text(s('payment.newIn'))),
                PopupMenuItem(value: 'out', child: Text(s('payment.newOut'))),
              ],
              child: FloatingActionButton(
                onPressed: null,
                child: const Icon(LucideIcons.plus),
              ),
            )
          : null,
      body: AsyncBody<List<Payment>>(
        value: list,
        builder: (items) {
          if (items.isEmpty) return EmptyView(message: s('payment.noPayments'));
          return ListView(padding: EdgeInsets.all(t.screenPadding), children: [
            for (final p in items) PaymentTile(p: p),
            if (items.length >= _limit)
              TextButton(
                onPressed: () => setState(() => _limit += 50),
                child: Text(s('common.all')),
              ),
          ]);
        },
      ),
    );
  }
}

class PaymentTile extends ConsumerWidget {
  const PaymentTile({super.key, required this.p});
  final Payment p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final cancelled = p.status == 'cancelled';
    final isIn = p.direction == 'in';
    return Card(
      child: ListTile(
        leading: Icon(isIn ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
            color: t.color(isIn ? 'positive' : 'negative')),
        title: Text(p.partyName.isEmpty ? s(isIn ? 'payment.in' : 'payment.out') : p.partyName),
        subtitle: Text('${p.date} · ${s('paymentMethod.${p.method}')}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          MoneyText(p.amountMinor,
              style: TextStyle(decoration: cancelled ? TextDecoration.lineThrough : null)),
          if (cancelled)
            StatusChip(label: s('payment.status.cancelled'), color: t.color('textSecondary')),
        ]),
        onTap: () => context.push('/payments/${p.id}'),
      ),
    );
  }
}
