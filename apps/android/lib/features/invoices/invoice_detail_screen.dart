import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/islem_servisleri/invoice_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/write_helpers.dart';
import 'invoice_widgets.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _busy = false;

  /// Her islem icin tek txId: hata sonrasi yeniden denemede ayni kalir (cift kayit olmaz).
  String? _issueTxId;
  String? _cancelTxId;

  Future<void> _issueDraft(Invoice inv, {bool force = false}) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    if (!force) {
      final ok = await confirmDialog(context, ref, message: s('invoice.confirmIssue'));
      if (!ok || !mounted) return;
    }
    final service = ref.read(invoiceServiceProvider);
    _issueTxId ??= newId();
    setState(() => _busy = true);
    try {
      final res = await service.issueInvoice(inv.toDraft(), _issueTxId!, force: force);
      _issueTxId = null;
      if (mounted) {
        showSuccess(context, ref, s('messages.invoiceIssued', {'number': res.number}));
      }
    } on TxException catch (e) {
      // draftChanged dahil: ekrandaki taslak canli dinlenir, sunucu surumu zaten
      // gorunur; tekrar "Faturayi Kes" guncel rev ile denenir.
      if (mounted) showError(context, ref, e.message(s));
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Invoice inv) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final ok = await confirmDialog(context, ref, message: s('messages.confirmCancelInvoice'));
    if (!ok || !mounted) return;
    final service = ref.read(invoiceServiceProvider);
    _cancelTxId ??= newId();
    setState(() => _busy = true);
    try {
      await service.cancelInvoice(inv.id, _cancelTxId!);
      _cancelTxId = null;
      if (mounted) showSuccess(context, ref, s('messages.invoiceCancelled'));
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDraft(Invoice inv) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final ok = await confirmDialog(context, ref, message: s('invoice.confirmDeleteDraft'));
    if (!ok || !mounted) return;
    final service = ref.read(invoiceServiceProvider);
    setState(() => _busy = true);
    try {
      await service.deleteDraft(inv.id);
      if (!mounted) return;
      showSuccess(context, ref, s('invoice.draftDeleted'));
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
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('invoice.write') ?? false;
    final invoice = ref.watch(invoiceProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.valueOrNull?.number ?? s('status.draft')),
      ),
      body: AsyncBody<Invoice?>(
        value: invoice,
        onRetry: () => ref.invalidate(invoiceProvider(widget.invoiceId)),
        builder: (inv) {
          if (inv == null) return const EmptyView();
          final pad = t.screenPadding;

          Widget kv(String k, String v) => Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing('xs')),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(k, style: TextStyle(color: t.color('textSecondary'))),
                    ),
                    Text(v),
                  ],
                ),
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

          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s('invoiceType.${inv.type}'),
                      style: TextStyle(
                        fontSize: t.fontSize('title'),
                        fontWeight: t.fontWeight('semibold'),
                      ),
                    ),
                  ),
                  InvoiceStatusChip(invoice: inv),
                ],
              ),
              SizedBox(height: t.spacing('lg')),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(t.spacing('lg')),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => context.push('/parties/${inv.partyId}'),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: t.spacing('xs')),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s('invoice.party'),
                                  style: TextStyle(color: t.color('textSecondary')),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  inv.partyName,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(color: t.color('accent')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      kv(s('invoiceForm.invoiceDate'), formatDisplayDate(inv.issueDate)),
                      kv(s('invoiceForm.dueDate'), formatDisplayDate(inv.dueDate)),
                      if (inv.priceIncludesVat)
                        kv(s('invoiceForm.priceIncludesVat'), s('common.yes')),
                    ],
                  ),
                ),
              ),
              SizedBox(height: t.spacing('xl')),
              Text(
                s('invoiceForm.lines'),
                style: TextStyle(
                  fontSize: t.fontSize('bodyLg'),
                  fontWeight: t.fontWeight('semibold'),
                ),
              ),
              SizedBox(height: t.spacing('md')),
              if (inv.lines.isEmpty)
                Text(
                  s('invoice.noLines'),
                  style: TextStyle(color: t.color('textSecondary')),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < inv.lines.length; i++) ...[
                        if (i > 0) const Divider(),
                        Padding(
                          padding: EdgeInsets.all(t.spacing('md')),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv.lines[i].description,
                                      style: TextStyle(
                                        fontWeight: t.fontWeight('semibold'),
                                      ),
                                    ),
                                    SizedBox(height: t.spacing('xs')),
                                    Text(
                                      '${formatMilli(inv.lines[i].qtyMilli)} ${s('unit.${inv.lines[i].unit}')}'
                                      ' × ${formatMinorTry(inv.lines[i].unitPriceMinor)}'
                                      ' · KDV ${formatBp(inv.lines[i].vatBp)}',
                                      style: TextStyle(
                                        fontSize: t.fontSize('caption'),
                                        color: t.color('textSecondary'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MoneyText(
                                inv.lines[i].totalMinor,
                                style: TextStyle(fontWeight: t.fontWeight('semibold')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              SizedBox(height: t.spacing('xl')),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(t.spacing('lg')),
                  child: Column(
                    children: [
                      totalRow(s('invoiceForm.subtotal'), inv.subtotalMinor),
                      totalRow(s('invoiceForm.discountTotal'), inv.discountMinor),
                      totalRow(s('invoiceForm.vatTotal'), inv.vatMinor),
                      const Divider(),
                      totalRow(s('invoiceForm.grandTotal'), inv.totalMinor, strong: true),
                      if (inv.isIssued) ...[
                        const Divider(),
                        totalRow(s('invoice.paid'), inv.paidMinor),
                        totalRow(s('invoice.remaining'), inv.remainingMinor),
                      ],
                    ],
                  ),
                ),
              ),
              if (inv.note.isNotEmpty) ...[
                SizedBox(height: t.spacing('lg')),
                kv(s('invoice.note'), ''),
                Text(inv.note),
              ],
              if (canWrite) ...[
                SizedBox(height: t.spacing('xl')),
                if (inv.isDraft) ...[
                  FilledButton(
                    onPressed: _busy ? null : () => _issueDraft(inv),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s('invoice.issueDraft')),
                  ),
                  SizedBox(height: t.spacing('md')),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.push('/invoices/${inv.id}/edit'),
                    icon: const Icon(LucideIcons.pencil, size: 18),
                    label: Text(s('common.edit')),
                  ),
                  SizedBox(height: t.spacing('md')),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _deleteDraft(inv),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.color('negative'),
                    ),
                    icon: const Icon(LucideIcons.trash2, size: 18),
                    label: Text(s('common.delete')),
                  ),
                ] else if (inv.isIssued && inv.paidMinor == 0)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _cancel(inv),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.color('negative'),
                    ),
                    icon: const Icon(LucideIcons.ban, size: 18),
                    label: Text(s('invoice.cancelInvoice')),
                  ),
              ],
              SizedBox(height: t.spacing('xxl')),
            ],
          );
        },
      ),
    );
  }
}
