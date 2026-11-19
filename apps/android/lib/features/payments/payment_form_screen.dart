import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/date_field.dart';
import '../../data/islem_servisleri/payment_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/account.dart';
import '../../data/models/invoice.dart';
import '../../data/models/party.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/party_repository.dart';
import '../../data/write_helpers.dart';
import '../invoices/line_editor_sheet.dart' show pickParty;

/// Tahsilat (`direction=in`) / Odeme (`out`) formu; acik faturalara otomatik veya elle dagitim.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, this.direction = 'in', this.partyId, this.invoiceId});
  final String direction;
  final String? partyId;
  final String? invoiceId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  String? _partyId;
  String _partyName = '';
  String? _accountId;
  String _method = 'cash';
  String _date = todayIso();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _alloc = {};
  final _txId = newId();
  bool _busy = false;

  bool get _isIn => widget.direction != 'out';

  @override
  void initState() {
    super.initState();
    _partyId = widget.partyId;
    if (_partyId != null) {
      Future.microtask(() async {
        final p = await ref.read(partyProvider(_partyId!).future);
        if (mounted && p != null) setState(() => _partyName = p.name);
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    for (final c in _alloc.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _amountMinor => parseMinor(_amount.text) ?? 0;
  int _allocOf(String id) => parseMinor(_alloc[id]?.text ?? '') ?? 0;
  int get _allocated => _alloc.keys.fold(0, (p, id) => p + _allocOf(id));

  List<Invoice> _open(List<Invoice> all) {
    final l = all
        .where((i) =>
            i.isIssued && i.remainingMinor > 0 && isReceivableType(i.type) == _isIn)
        .toList()
      ..sort((a, b) => a.issueDate.compareTo(b.issueDate));
    return l;
  }

  void _autoDistribute(List<Invoice> open) {
    var left = _amountMinor;
    setState(() {
      for (final i in open) {
        final take = left < i.remainingMinor ? left : i.remainingMinor;
        left -= take;
        final c = _alloc.putIfAbsent(i.id, () => TextEditingController());
        c.text = take > 0 ? formatMinor(take) : '';
      }
    });
  }

  void _clear() => setState(() {
        for (final c in _alloc.values) {
          c.text = '';
        }
      });

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final allocs = [
      for (final id in _alloc.keys)
        if (_allocOf(id) > 0) PaymentAllocation(invoiceId: id, amountMinor: _allocOf(id)),
    ];
    setState(() => _busy = true);
    try {
      final res = await ref.read(paymentServiceProvider).recordPayment(
            txId: _txId,
            direction: widget.direction,
            partyId: _partyId ?? '',
            accountId: _accountId ?? '',
            amountMinor: _amountMinor,
            date: _date,
            method: _method,
            allocations: allocs,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      showSuccess(context, ref, s('payment.saved'));
      if (res.accountNegative) showWarning(context, ref, s('account.negativeWarn'));
      context.pop();
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
    final accounts = (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        .where((a) => a.active)
        .toList();
    final invoices = _partyId == null
        ? const <Invoice>[]
        : _open(ref.watch(partyInvoicesProvider(_partyId!)).valueOrNull ?? const []);
    final unalloc = _amountMinor - _allocated;

    return Scaffold(
      appBar: AppBar(title: Text(s(_isIn ? 'payment.newIn' : 'payment.newOut'))),
      body: ListView(padding: EdgeInsets.all(t.screenPadding), children: [
        Card(
          child: ListTile(
            title: Text(_partyId == null ? s('errors.partyRequired') : _partyName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final Party? p = await pickParty(context);
              if (p == null) return;
              setState(() {
                _partyId = p.id;
                _partyName = p.name;
                for (final c in _alloc.values) {
                  c.dispose();
                }
                _alloc.clear();
              });
            },
          ),
        ),
        SizedBox(height: t.spacing('md')),
        DropdownButtonFormField<String>(
          value: _accountId,
          items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
          decoration: InputDecoration(labelText: s('payment.account')),
          onChanged: (v) => setState(() => _accountId = v),
        ),
        SizedBox(height: t.spacing('md')),
        DropdownButtonFormField<String>(
          value: _method,
          items: [
            for (final m in const ['cash', 'bank_transfer', 'cheque', 'card'])
              DropdownMenuItem(value: m, child: Text(s('paymentMethod.$m'))),
          ],
          decoration: InputDecoration(labelText: s('payment.method')),
          onChanged: (v) => setState(() => _method = v ?? 'cash'),
        ),
        SizedBox(height: t.spacing('md')),
        TextField(
          controller: _amount,
          keyboardType: moneyKeyboard,
          inputFormatters: moneyInputFormatters,
          decoration: InputDecoration(labelText: s('payment.amount')),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: t.spacing('md')),
        DateField(label: s('payment.date'), value: _date, onChanged: (v) => setState(() => _date = v)),
        SizedBox(height: t.spacing('md')),
        TextField(controller: _note, decoration: InputDecoration(labelText: s('payment.note'))),
        SizedBox(height: t.spacing('lg')),
        Row(children: [
          Expanded(child: Text(s('payment.openInvoices'), style: TextStyle(fontWeight: t.fontWeight('semibold')))),
          TextButton(onPressed: invoices.isEmpty ? null : () => _autoDistribute(invoices), child: Text(s('payment.autoDistribute'))),
          TextButton(onPressed: _clear, child: Text(s('payment.clearAlloc'))),
        ]),
        if (_partyId != null && invoices.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.spacing('sm')),
            child: Text(s('payment.noOpenInvoices'), style: TextStyle(color: t.color('textSecondary'))),
          ),
        for (final i in invoices)
          Card(
            child: Padding(
              padding: EdgeInsets.all(t.spacing('md')),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.number ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    MoneyText(i.remainingMinor, style: TextStyle(color: t.color('textSecondary'))),
                  ]),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _alloc.putIfAbsent(i.id, () => TextEditingController()),
                    keyboardType: moneyKeyboard,
                    inputFormatters: moneyInputFormatters,
                    textAlign: TextAlign.end,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            ),
          ),
        SizedBox(height: t.spacing('md')),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s('payment.allocated')),
          MoneyText(_allocated),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s('payment.unallocated')),
          MoneyText(unalloc, style: TextStyle(color: unalloc < 0 ? t.color('negative') : null)),
        ]),
        SizedBox(height: t.spacing('lg')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(t.minTouchTarget)),
          child: Text(s('payment.save')),
        ),
      ]),
    );
  }
}
