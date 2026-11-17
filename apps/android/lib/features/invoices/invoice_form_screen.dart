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
import '../../data/invoice_calculator.dart';
import '../../data/islem_servisleri/invoice_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/write_helpers.dart';
import 'line_editor_sheet.dart';

/// Yeni fatura (`invoiceId == null`, [type] zorunlu) veya taslak duzenleme.
class InvoiceFormScreen extends ConsumerWidget {
  const InvoiceFormScreen({super.key, this.invoiceId, this.type});

  final String? invoiceId;
  final String? type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final id = invoiceId;
    if (id == null) {
      final tp = invoiceTypes.contains(type) ? type! : 'sales';
      return _InvoiceForm(title: s('invoice.newInvoice'), type: tp, initial: null);
    }
    final inv = ref.watch(invoiceProvider(id));
    return inv.when(
      data: (i) {
        if (i == null || !i.isDraft) {
          // Yalniz taslak duzenlenir; kesilmis fatura degistirilemez.
          return Scaffold(appBar: AppBar(), body: const EmptyView());
        }
        return _InvoiceForm(
          title: s('invoice.editDraft'),
          type: i.type,
          initial: i,
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
    );
  }
}

class _InvoiceForm extends ConsumerStatefulWidget {
  const _InvoiceForm({
    required this.title,
    required this.type,
    required this.initial,
  });

  final String title;
  final String type;
  final Invoice? initial;

  @override
  ConsumerState<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends ConsumerState<_InvoiceForm> {
  late String _type;
  String _partyId = '';
  String _partyName = '';
  late String _issueDate;
  late String _dueDate;
  bool _priceIncludesVat = false;
  late final TextEditingController _note;
  late List<InvoiceLine> _lines;
  String? _draftId;
  int _rev = 0;
  String? _projectId;
  String? _costCategory;
  bool _busy = false;

  /// Form acilinca uretilir; ayni formdan tekrar gonderimde AYNI kalir (docs/04 §1).
  final String _txId = newId();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _type = widget.type;
    _note = TextEditingController(text: i?.note ?? '');
    if (i != null) {
      _partyId = i.partyId;
      _partyName = i.partyName;
      _issueDate = i.issueDate;
      _dueDate = i.dueDate;
      _priceIncludesVat = i.priceIncludesVat;
      _lines = [...i.lines];
      _draftId = i.id;
      _rev = i.rev;
      _projectId = i.projectId;
      _costCategory = i.costCategory;
    } else {
      _issueDate = todayIso();
      _dueDate = addDaysIso(_issueDate, 30);
      _lines = [];
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  InvoiceDraft _buildDraft() => InvoiceDraft(
        id: _draftId,
        type: _type,
        partyId: _partyId,
        partyName: _partyName,
        issueDate: _issueDate,
        dueDate: _dueDate,
        priceIncludesVat: _priceIncludesVat,
        note: _note.text.trim(),
        projectId: _projectId,
        costCategory: _costCategory,
        lines: _lines,
        rev: _rev,
      );

  Future<void> _pickParty() async {
    final p = await pickParty(context);
    if (p != null) {
      setState(() {
        _partyId = p.id;
        _partyName = p.name;
      });
    }
  }

  Future<void> _addOrEditLine({int? index}) async {
    final line = await editInvoiceLine(
      context,
      initial: index == null ? null : _lines[index],
      invoiceType: _type,
    );
    if (line == null) return;
    setState(() {
      if (index == null) {
        _lines = [..._lines, line];
      } else {
        _lines = [..._lines]..[index] = line;
      }
    });
  }

  Future<void> _saveDraft() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final service = ref.read(invoiceServiceProvider);
    setState(() => _busy = true);
    try {
      final res = await service.saveDraft(_buildDraft());
      if (!mounted) return;
      if (res.synced) {
        showSuccess(context, ref, s('invoice.draftSaved'));
      } else {
        showWarning(context, ref, s('messages.queued'));
      }
      context.pop();
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue({bool force = false}) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    // Erken dogrulama: hata mesaji onay penceresinden once gorunsun.
    try {
      computeInvoice(_buildDraft(), requireLines: true);
    } catch (e) {
      showError(context, ref, describeTxError(e, s));
      return;
    }
    if (!force) {
      final ok = await confirmDialog(context, ref, message: s('invoice.confirmIssue'));
      if (!ok || !mounted) return;
    }
    final service = ref.read(invoiceServiceProvider);
    setState(() => _busy = true);
    try {
      final res = await service.issueInvoice(_buildDraft(), _txId, force: force);
      if (!mounted) return;
      showSuccess(
        context,
        ref,
        s('messages.invoiceIssued', {'number': res.number}),
      );
      context.pushReplacement('/invoices/${res.invoiceId}');
    } on TxException catch (e) {
      if (!mounted) return;
      if (e.code == 'draftChanged') {
        await _handleDraftChanged();
      } else {
        showError(context, ref, e.message(s));
      }
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// docs/05: "Sunucudaki surumu ac / Benimkini koru (uzerine yaz)".
  Future<void> _handleDraftChanged() async {
    final s = ref.read(stringsProvider);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('invoice.draftChangedTitle')),
        content: Text(s('errors.draftChanged')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'server'),
            child: Text(s('invoice.openServer')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'mine'),
            child: Text(s('invoice.keepMine')),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'server') {
      // Formu sunucudaki guncel taslakla yeniden ac.
      context.pushReplacement('/invoices/$_draftId/edit');
    } else {
      await _issue(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('invoice.write') ?? false;
    final gap = SizedBox(height: t.spacing('lg'));

    final totals = calculateInvoice(
      _lines.map((l) => l.toInput()).where((l) => l.qtyMilli > 0),
      priceIncludesVat: _priceIncludesVat,
    );

    Widget totalRow(String label, int minor, {bool strong = false}) => Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing('xs')),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: strong ? null : t.color('textSecondary'),
                    fontWeight: t.fontWeight(strong ? 'semibold' : 'regular'),
                  ),
                ),
              ),
              MoneyText(
                minor,
                style: TextStyle(
                  fontSize: strong ? t.fontSize('bodyLg') : null,
                  fontWeight: t.fontWeight(strong ? 'bold' : 'regular'),
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} · ${s('invoiceType.$_type')}'),
      ),
      body: ListView(
        padding: EdgeInsets.all(t.screenPadding),
        children: [
          if (!canWrite)
            Padding(
              padding: EdgeInsets.only(bottom: t.spacing('lg')),
              child: Text(
                s('common.noPermission'),
                style: TextStyle(color: t.color('warning')),
              ),
            ),
          Text(
            s('invoiceForm.info'),
            style: TextStyle(
              fontSize: t.fontSize('bodyLg'),
              fontWeight: t.fontWeight('semibold'),
            ),
          ),
          gap,
          InkWell(
            onTap: canWrite ? _pickParty : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: s('invoice.party'),
                suffixIcon: const Icon(LucideIcons.chevronDown, size: 18),
              ),
              child: Text(
                _partyName.isEmpty ? s('invoice.selectParty') : _partyName,
                style: TextStyle(
                  color: _partyName.isEmpty ? t.color('textSecondary') : null,
                ),
              ),
            ),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: s('invoiceForm.invoiceDate'),
                  value: _issueDate,
                  enabled: canWrite,
                  onChanged: (v) => setState(() {
                    // Vade, fatura tarihinden once kalirsa birlikte ilerlet.
                    _issueDate = v;
                    if (_dueDate.compareTo(v) < 0) _dueDate = v;
                  }),
                ),
              ),
              SizedBox(width: t.spacing('md')),
              Expanded(
                child: DateField(
                  label: s('invoiceForm.dueDate'),
                  value: _dueDate,
                  enabled: canWrite,
                  onChanged: (v) => setState(() => _dueDate = v),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('invoiceForm.priceIncludesVat')),
            value: _priceIncludesVat,
            onChanged:
                canWrite ? (v) => setState(() => _priceIncludesVat = v) : null,
          ),
          SizedBox(height: t.spacing('md')),
          Row(
            children: [
              Expanded(
                child: Text(
                  s('invoiceForm.lines'),
                  style: TextStyle(
                    fontSize: t.fontSize('bodyLg'),
                    fontWeight: t.fontWeight('semibold'),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: canWrite ? () => _addOrEditLine() : null,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(s('invoiceForm.addLine')),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.spacing('xl')),
              child: Center(
                child: Text(
                  s('invoice.noLines'),
                  style: TextStyle(color: t.color('textSecondary')),
                ),
              ),
            )
          else
            for (var i = 0; i < _lines.length; i++)
              _LineTile(
                line: _lines[i],
                includesVat: _priceIncludesVat,
                onTap: canWrite ? () => _addOrEditLine(index: i) : null,
                onRemove: canWrite
                    ? () => setState(() => _lines = [..._lines]..removeAt(i))
                    : null,
              ),
          SizedBox(height: t.spacing('lg')),
          Card(
            child: Padding(
              padding: EdgeInsets.all(t.spacing('lg')),
              child: Column(
                children: [
                  totalRow(s('invoiceForm.subtotal'), totals.subtotalMinor),
                  totalRow(s('invoiceForm.discountTotal'), totals.discountMinor),
                  totalRow(s('invoiceForm.vatTotal'), totals.vatMinor),
                  const Divider(),
                  totalRow(s('invoiceForm.grandTotal'), totals.totalMinor,
                      strong: true),
                ],
              ),
            ),
          ),
          gap,
          TextFormField(
            controller: _note,
            enabled: canWrite,
            maxLines: 3,
            decoration: InputDecoration(labelText: s('invoice.note')),
          ),
          SizedBox(height: t.spacing('xl')),
          OutlinedButton(
            onPressed: (_busy || !canWrite) ? null : _saveDraft,
            child: Text(s('invoiceForm.saveDraft')),
          ),
          SizedBox(height: t.spacing('md')),
          FilledButton(
            onPressed: (_busy || !canWrite) ? null : () => _issue(),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s('invoiceForm.issue')),
          ),
          SizedBox(height: t.spacing('xxl')),
        ],
      ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({
    required this.line,
    required this.includesVat,
    required this.onTap,
    required this.onRemove,
  });

  final InvoiceLine line;
  final bool includesVat;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final l = line;
    final amounts = calculateLine(l.toInput(), priceIncludesVat: includesVat);

    return Padding(
      padding: EdgeInsets.only(bottom: t.spacing('sm')),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius('card')),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(t.spacing('md')),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: t.fontWeight('semibold')),
                      ),
                      SizedBox(height: t.spacing('xs')),
                      Text(
                        '${formatMilli(l.qtyMilli)} ${s('unit.${l.unit}')} × ${formatMinorTry(l.unitPriceMinor)}'
                        '${l.discountBp > 0 ? ' · -${formatBp(l.discountBp)}' : ''}'
                        ' · KDV ${formatBp(l.vatBp)}',
                        style: TextStyle(
                          fontSize: t.fontSize('caption'),
                          color: t.color('textSecondary'),
                        ),
                      ),
                    ],
                  ),
                ),
                MoneyText(
                  amounts.totalMinor,
                  style: TextStyle(fontWeight: t.fontWeight('semibold')),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: s('invoice.removeLine'),
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: t.color('negative'),
                    ),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
