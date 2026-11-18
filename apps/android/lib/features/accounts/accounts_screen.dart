import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/date_field.dart';
import '../../data/islem_servisleri/payment_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/account.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/write_helpers.dart';

/// Kasa / Banka listesi + yeni hesap ve transfer sayfalari.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite = ref.watch(userProfileProvider).valueOrNull?.can('finance.write') ?? false;
    final accounts = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s('account.title')), actions: [
        if (canWrite)
          IconButton(
            tooltip: s('move.transfer'),
            icon: const Icon(LucideIcons.arrowLeftRight),
            onPressed: () => showTransferSheet(context),
          ),
      ]),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => showAccountSheet(context),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: AsyncBody<List<Account>>(
        value: accounts,
        builder: (list) {
          if (list.isEmpty) return EmptyView(message: s('common.empty'));
          final total = list.where((a) => a.active).fold<int>(0, (p, a) => p + a.balanceMinor);
          return ListView(
            padding: EdgeInsets.all(t.screenPadding),
            children: [
              Card(
                child: ListTile(
                  title: Text(s('account.total')),
                  trailing: MoneyText(total,
                      signed: true,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: t.fontSize('title'))),
                ),
              ),
              for (final a in list)
                Card(
                  child: ListTile(
                    leading: Icon(a.isCash ? LucideIcons.wallet : LucideIcons.landmark),
                    title: Text(a.name),
                    subtitle: Text(s('accountType.${a.type}')),
                    trailing: MoneyText(a.balanceMinor, signed: true),
                    onTap: () => context.push('/accounts/${a.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Yeni / duzenle hesap sayfasi. Duzenlemede bakiye alani yoktur.
Future<void> showAccountSheet(BuildContext context, {Account? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AccountSheet(existing: existing),
    ),
  );
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.existing});
  final Account? existing;
  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late String _type = widget.existing?.type ?? 'cash';
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _bank = TextEditingController(text: widget.existing?.bankName ?? '');
  late final _iban = TextEditingController(text: widget.existing?.iban ?? '');
  final _opening = TextEditingController();
  final _txId = newId();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _iban.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final name = _name.text.trim();
    if (name.isEmpty) {
      showError(context, ref, s('errors.accountRequired'));
      return;
    }
    final service = ref.read(paymentServiceProvider);
    final old = widget.existing;
    final acc = Account(
      id: old?.id ?? '',
      companyId: old?.companyId ?? '',
      type: _type,
      name: name,
      bankName: _type == 'bank' ? _bank.text.trim() : '',
      iban: _type == 'bank' ? _iban.text.trim() : '',
      balanceMinor: old?.balanceMinor ?? 0,
      active: old?.active ?? true,
    );
    setState(() => _busy = true);
    try {
      if (old == null) {
        final opening = parseMinor(_opening.text) ?? 0;
        await service.createAccount(acc, openingMinor: opening, txId: _txId);
      } else {
        await service.updateAccount(acc);
      }
      if (!mounted) return;
      showSuccess(context, ref, s('payment.saved'));
      Navigator.pop(context);
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
    final isNew = widget.existing == null;
    return SingleChildScrollView(
      padding: EdgeInsets.all(t.screenPadding),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isNew)
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'cash', label: Text(s('accountType.cash'))),
              ButtonSegment(value: 'bank', label: Text(s('accountType.bank'))),
            ],
            selected: {_type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
        SizedBox(height: t.spacing('md')),
        TextField(controller: _name, decoration: InputDecoration(labelText: s('account.name'))),
        if (_type == 'bank') ...[
          SizedBox(height: t.spacing('md')),
          TextField(controller: _bank, decoration: InputDecoration(labelText: s('account.bankName'))),
          SizedBox(height: t.spacing('md')),
          TextField(controller: _iban, decoration: InputDecoration(labelText: s('account.iban'))),
        ],
        if (isNew) ...[
          SizedBox(height: t.spacing('md')),
          TextField(
            controller: _opening,
            keyboardType: moneyKeyboard,
            inputFormatters: moneyInputFormatters,
            decoration: InputDecoration(labelText: s('account.opening')),
          ),
        ],
        SizedBox(height: t.spacing('lg')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(t.minTouchTarget)),
          child: Text(s('common.save')),
        ),
      ]),
    );
  }
}

Future<void> showTransferSheet(BuildContext context, {String? fromId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TransferSheet(fromId: fromId),
    ),
  );
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({this.fromId});
  final String? fromId;
  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  String? _from;
  String? _to;
  String _date = todayIso();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _txId = newId();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _from = widget.fromId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final amount = parseMinor(_amount.text) ?? 0;
    if (_from == null || _to == null) {
      showError(context, ref, s('errors.accountRequired'));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref.read(paymentServiceProvider).transfer(
            txId: _txId,
            fromAccountId: _from!,
            toAccountId: _to!,
            amountMinor: amount,
            date: _date,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      showSuccess(context, ref, s('account.transferDone'));
      if (res.accountNegative) showWarning(context, ref, s('account.negativeWarn'));
      Navigator.pop(context);
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
    List<DropdownMenuItem<String>> items() => [
          for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
        ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(t.screenPadding),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          value: _from,
          items: items(),
          decoration: InputDecoration(labelText: s('account.from')),
          onChanged: (v) => setState(() => _from = v),
        ),
        SizedBox(height: t.spacing('md')),
        DropdownButtonFormField<String>(
          value: _to,
          items: items(),
          decoration: InputDecoration(labelText: s('account.to')),
          onChanged: (v) => setState(() => _to = v),
        ),
        SizedBox(height: t.spacing('md')),
        TextField(
          controller: _amount,
          keyboardType: moneyKeyboard,
          inputFormatters: moneyInputFormatters,
          decoration: InputDecoration(labelText: s('account.amount')),
        ),
        SizedBox(height: t.spacing('md')),
        DateField(label: s('payment.date'), value: _date, onChanged: (v) => setState(() => _date = v)),
        SizedBox(height: t.spacing('md')),
        TextField(controller: _note, decoration: InputDecoration(labelText: s('payment.note'))),
        SizedBox(height: t.spacing('lg')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(t.minTouchTarget)),
          child: Text(s('common.save')),
        ),
      ]),
    );
  }
}
