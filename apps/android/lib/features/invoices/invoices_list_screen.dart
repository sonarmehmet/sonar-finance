import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/providers.dart';
import '../../core/text/text_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import 'invoice_widgets.dart';

const _pageSize = 25;

/// Fatura listesi: sekmeler (Tumu/Satis/Alis/Iade/Taslak), arama, sayfalama.
/// "Islemler" sekmesinin govdesidir.
class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key, required this.title});

  final String title;

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  InvoiceTab _tab = InvoiceTab.all;
  int _limit = _pageSize;
  String _query = '';

  void _setTab(InvoiceTab tab) => setState(() {
        _tab = tab;
        _limit = _pageSize;
      });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('invoice.write') ?? false;
    final query = (tab: _tab, limit: _limit);
    final invoices = ref.watch(invoicesProvider(query));
    final pad = t.screenPadding;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => showNewInvoiceTypeSheet(context, ref),
              tooltip: s('invoice.newInvoice'),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, t.spacing('sm')),
            child: SearchBox(onChanged: (v) => setState(() => _query = v)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              children: [
                for (final tab in InvoiceTab.values)
                  Padding(
                    padding: EdgeInsets.only(right: t.spacing('sm')),
                    child: ChoiceChip(
                      label: Text(s('invoiceTabs.${tab.name}')),
                      selected: _tab == tab,
                      onSelected: (_) => _setTab(tab),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<List<Invoice>>(
              value: invoices,
              onRetry: () => ref.invalidate(invoicesProvider(query)),
              builder: (all) {
                final list = all
                    .where(
                      (i) => matchesQuery(_query, [
                        i.number ?? '',
                        i.partyName,
                        s('invoiceType.${i.type}'),
                      ]),
                    )
                    .toList();
                final canLoadMore = all.length >= _limit;
                if (list.isEmpty && !canLoadMore) return const EmptyView();
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(pad, t.spacing('sm'), pad, 96),
                  itemCount: list.length + (canLoadMore ? 1 : 0),
                  separatorBuilder: (_, __) => SizedBox(height: t.spacing('sm')),
                  itemBuilder: (_, i) {
                    if (i == list.length) {
                      return TextButton(
                        onPressed: () =>
                            setState(() => _limit += _pageSize),
                        child: Text(s('invoice.loadMore')),
                      );
                    }
                    return _InvoiceTile(invoice: list[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends ConsumerWidget {
  const _InvoiceTile({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final i = invoice;
    final title = i.number ?? s('status.draft');
    final dim = i.isCancelled;

    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius('card')),
          onTap: () => context.push('/invoices/${i.id}'),
          child: Padding(
            padding: EdgeInsets.all(t.spacing('md')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: t.fontSize('bodyLg'),
                          fontWeight: t.fontWeight('semibold'),
                        ),
                      ),
                    ),
                    InvoiceStatusChip(invoice: i),
                  ],
                ),
                SizedBox(height: t.spacing('xs')),
                Text(
                  i.partyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: t.spacing('sm')),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s('invoiceType.${i.type}')} · ${formatDisplayDate(i.issueDate)}',
                        style: TextStyle(
                          fontSize: t.fontSize('caption'),
                          color: t.color('textSecondary'),
                        ),
                      ),
                    ),
                    MoneyText(
                      i.totalMinor,
                      style: TextStyle(fontWeight: t.fontWeight('semibold')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
