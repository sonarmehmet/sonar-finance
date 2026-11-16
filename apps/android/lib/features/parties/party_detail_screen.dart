import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/models/party.dart';
import '../../data/repositories/party_repository.dart';

/// Cari detay: ozet kart + sekmeler (Genel Bakis, Hesap Hareketleri).
/// Faturalar/Tahsilatlar/Odemeler sekmeleri A4 / F3 ile eklenecek.
class PartyDetailScreen extends ConsumerWidget {
  const PartyDetailScreen({super.key, required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('party.write') ?? false;
    final party = ref.watch(partyProvider(partyId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(party.valueOrNull?.name ?? ''),
          actions: [
            if (canWrite && party.valueOrNull != null)
              IconButton(
                tooltip: s('common.edit'),
                icon: const Icon(LucideIcons.pencil),
                onPressed: () => context.push('/parties/$partyId/edit'),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: s('party.tabs.overview')),
              Tab(text: s('party.tabs.movements')),
            ],
          ),
        ),
        body: AsyncBody<Party?>(
          value: party,
          onRetry: () => ref.invalidate(partyProvider(partyId)),
          builder: (p) {
            if (p == null) return const EmptyView();
            return TabBarView(
              children: [
                _Overview(party: p),
                _Movements(partyId: p.id),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final b = party.balanceMinor;
    final color = b == 0
        ? t.color('textSecondary')
        : b > 0
            ? t.color('positive')
            : t.color('negative');
    final label = b > 0
        ? s('party.balanceReceivable')
        : b < 0
            ? s('party.balanceDebt')
            : s('party.balanceZero');

    Widget row(IconData icon, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(bottom: t.spacing('md')),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: t.color('textSecondary')),
                SizedBox(width: t.spacing('md')),
                Expanded(child: Text(text)),
              ],
            ),
          );

    final tax = [party.taxOffice, party.taxNo].where((e) => e.isNotEmpty).join(' · ');

    return ListView(
      padding: EdgeInsets.all(t.screenPadding),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(t.spacing('lg')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s('party.net'),
                  style: TextStyle(
                    fontSize: t.fontSize('caption'),
                    color: t.color('textSecondary'),
                  ),
                ),
                SizedBox(height: t.spacing('xs')),
                MoneyText(
                  b.abs(),
                  style: TextStyle(
                    fontSize: t.fontSize('headline'),
                    fontWeight: t.fontWeight('bold'),
                    color: color,
                  ),
                ),
                SizedBox(height: t.spacing('xs')),
                Text(label, style: TextStyle(color: color)),
              ],
            ),
          ),
        ),
        SizedBox(height: t.spacing('xl')),
        Text(
          s('party.contact'),
          style: TextStyle(
            fontSize: t.fontSize('bodyLg'),
            fontWeight: t.fontWeight('semibold'),
          ),
        ),
        SizedBox(height: t.spacing('md')),
        row(LucideIcons.phone, party.phone),
        row(LucideIcons.mail, party.email),
        row(LucideIcons.fileText, tax),
        row(LucideIcons.mapPin, party.address),
        row(LucideIcons.stickyNote, party.notes),
        if (!party.active)
          Padding(
            padding: EdgeInsets.only(top: t.spacing('md')),
            child: StatusChip(
              label: s('common.passive'),
              color: t.color('neutral'),
            ),
          ),
      ],
    );
  }
}

class _Movements extends ConsumerWidget {
  const _Movements({required this.partyId});

  final String partyId;

  String _refLabel(String refType, WidgetRef ref) {
    final s = ref.read(stringsProvider);
    final key = 'ledger.$refType';
    final v = s(key);
    return v == key ? refType : v;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final entries = ref.watch(partyLedgerProvider(partyId));

    return AsyncBody<List<LedgerEntry>>(
      value: entries,
      onRetry: () => ref.invalidate(partyLedgerProvider(partyId)),
      builder: (list) {
        if (list.isEmpty) return EmptyView(message: s('party.noMovements'));
        return ListView.separated(
          padding: EdgeInsets.all(t.screenPadding),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) {
            final e = list[i];
            final d = e.deltaMinor;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: t.spacing('xs')),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description.isEmpty
                              ? _refLabel(e.refType, ref)
                              : e.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: t.spacing('xs')),
                        Text(
                          '${formatDisplayDate(e.date)} · ${_refLabel(e.refType, ref)}',
                          style: TextStyle(
                            fontSize: t.fontSize('caption'),
                            color: t.color('textSecondary'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pozitif: cari bize borclandi (alacak artti); negatif: borc/tahsilat.
                  MoneyText(
                    d,
                    signed: true,
                    style: TextStyle(fontWeight: t.fontWeight('semibold')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
