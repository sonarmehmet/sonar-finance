import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/islem_servisleri/payment_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/write_helpers.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});
  final String paymentId;
  @override
  ConsumerState<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  bool _busy = false;
  String? _cancelTxId;

  Future<void> _cancel() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final ok = await confirmDialog(context, ref, message: s('messages.confirmCancelPayment'));
    if (!ok || !mounted) return;
    _cancelTxId ??= newId();
    setState(() => _busy = true);
    try {
      final res = await ref.read(paymentServiceProvider).cancelPayment(widget.paymentId, _cancelTxId!);
      _cancelTxId = null;
      if (!mounted) return;
      showSuccess(context, ref, s('payment.cancelled'));
      if (res.accountNegative) showWarning(context, ref, s('account.negativeWarn'));
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite = ref.watch(userProfileProvider).valueOrNull?.can('finance.write') ?? false;
    final pay = ref.watch(paymentProvider(widget.paymentId));
    return Scaffold(
      appBar: AppBar(title: Text(s('payment.list'))),
      body: AsyncBody<Payment?>(
        value: pay,
        builder: (p) {
          if (p == null) return EmptyView(message: s('common.empty'));
          final isIn = p.direction == 'in';
          final account = ref.watch(accountProvider(p.accountId)).valueOrNull;
          final cancelled = p.status == 'cancelled';
          return ListView(padding: EdgeInsets.all(t.screenPadding), children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(t.spacing('lg')),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s(isIn ? 'payment.in' : 'payment.out'))),
                    if (cancelled)
                      StatusChip(label: s('payment.status.cancelled'), color: t.color('textSecondary')),
                  ]),
                  SizedBox(height: t.spacing('xs')),
                  MoneyText(p.amountMinor,
                      style: TextStyle(fontSize: t.fontSize('headline'), fontWeight: FontWeight.w700)),
                  SizedBox(height: t.spacing('md')),
                  Text(p.partyName),
                  Text('${p.date} · ${s('paymentMethod.${p.method}')}'),
                  if (account != null) Text(account.name),
                  if (p.note.isNotEmpty) Text(p.note),
                ]),
              ),
            ),
            if (p.allocations.isNotEmpty) ...[
              SizedBox(height: t.spacing('md')),
              Text(s('payment.invoices'), style: TextStyle(fontWeight: t.fontWeight('semibold'))),
              for (final a in p.allocations)
                Card(
                  child: ListTile(
                    title: Text(ref.watch(invoiceProvider(a.invoiceId)).valueOrNull?.number ?? '…'),
                    trailing: MoneyText(a.amountMinor),
                    onTap: () => context.push('/invoices/${a.invoiceId}'),
                  ),
                ),
            ],
            if (p.unallocatedMinor > 0)
              ListTile(
                title: Text(s('payment.unallocated')),
                trailing: MoneyText(p.unallocatedMinor),
              ),
            if (canWrite && !cancelled) ...[
              SizedBox(height: t.spacing('lg')),
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(t.minTouchTarget),
                  foregroundColor: t.color('negative'),
                ),
                child: Text(s('payment.cancel')),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
