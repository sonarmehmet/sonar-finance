import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/text/text_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/models/party.dart';
import '../../data/repositories/party_repository.dart';

/// Cari Hesaplar listesi: arama, tur filtresi, toplam alacak/borc ozeti.
class PartiesListScreen extends ConsumerStatefulWidget {
  const PartiesListScreen({super.key});

  @override
  ConsumerState<PartiesListScreen> createState() => _PartiesListScreenState();
}

class _PartiesListScreenState extends ConsumerState<PartiesListScreen> {
  String _query = '';
  String _filter = 'all'; // all | customer | supplier

  List<Party> _apply(List<Party> all) => all.where((p) {
        if (_filter == 'customer' && !p.isCustomer) return false;
        if (_filter == 'supplier' && !p.isSupplier) return false;
        return matchesQuery(_query, [p.name, p.phone, p.taxNo]);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('party.write') ?? false;
    final parties = ref.watch(partiesProvider);
    final pad = t.screenPadding;

    return Scaffold(
      appBar: AppBar(title: Text(s('menu.parties'))),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => context.push('/parties/new'),
              tooltip: s('party.newParty'),
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
                for (final f in const ['all', 'customer', 'supplier'])
                  Padding(
                    padding: EdgeInsets.only(right: t.spacing('sm')),
                    child: ChoiceChip(
                      label: Text(
                        f == 'all' ? s('common.all') : s('party.$f'),
                      ),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<List<Party>>(
              value: parties,
              onRetry: () => ref.invalidate(partiesProvider),
              builder: (all) {
                final list = _apply(all);
                if (list.isEmpty) return const EmptyView();
                var receivable = 0, debt = 0;
                for (final p in list) {
                  if (p.balanceMinor > 0) receivable += p.balanceMinor;
                  if (p.balanceMinor < 0) debt += -p.balanceMinor;
                }
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(pad),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: s('dashboard.totalReceivable'),
                              minor: receivable,
                              color: t.color('positive'),
                            ),
                          ),
                          SizedBox(width: t.spacing('md')),
                          Expanded(
                            child: _SummaryCard(
                              label: s('dashboard.totalPayable'),
                              minor: debt,
                              color: t.color('negative'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: t.spacing('sm')),
                        itemBuilder: (_, i) => _PartyTile(party: list[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.label,
    required this.minor,
    required this.color,
  });

  final String label;
  final int minor;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(t.spacing('md')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: t.fontSize('caption'),
                color: t.color('textSecondary'),
              ),
            ),
            SizedBox(height: t.spacing('xs')),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(
                minor,
                style: TextStyle(
                  fontSize: t.fontSize('bodyLg'),
                  fontWeight: t.fontWeight('semibold'),
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyTile extends ConsumerWidget {
  const _PartyTile({required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final b = party.balanceMinor;
    final balanceLabel = b > 0
        ? s('party.balanceReceivable')
        : b < 0
            ? s('party.balanceDebt')
            : s('party.balanceZero');
    final kinds = [
      if (party.isCustomer) s('party.customer'),
      if (party.isSupplier) s('party.supplier'),
    ].join(' · ');

    return Opacity(
      opacity: party.active ? 1 : 0.55,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius('card')),
          onTap: () => context.push('/parties/${party.id}'),
          child: Padding(
            padding: EdgeInsets.all(t.spacing('md')),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.fontSize('bodyLg'),
                          fontWeight: t.fontWeight('semibold'),
                        ),
                      ),
                      SizedBox(height: t.spacing('xs')),
                      Text(
                        party.active ? kinds : '$kinds · ${s('common.passive')}',
                        style: TextStyle(
                          fontSize: t.fontSize('caption'),
                          color: t.color('textSecondary'),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      b.abs(),
                      style: TextStyle(
                        fontWeight: t.fontWeight('semibold'),
                        color: b == 0
                            ? t.color('textSecondary')
                            : b > 0
                                ? t.color('positive')
                                : t.color('negative'),
                      ),
                    ),
                    SizedBox(height: t.spacing('xs')),
                    Text(
                      balanceLabel,
                      style: TextStyle(
                        fontSize: t.fontSize('caption'),
                        color: t.color('textSecondary'),
                      ),
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
