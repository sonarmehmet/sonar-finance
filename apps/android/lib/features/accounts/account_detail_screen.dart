import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/account.dart';
import '../../data/models/account_movement.dart';
import '../../data/repositories/account_repository.dart';
import 'accounts_screen.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite = ref.watch(userProfileProvider).valueOrNull?.can('finance.write') ?? false;
    final acc = ref.watch(accountProvider(accountId));
    final moves = ref.watch(accountMovementsProvider(accountId));
    return Scaffold(
      appBar: AppBar(
        title: Text(acc.valueOrNull?.name ?? ''),
        actions: [
          if (canWrite && acc.valueOrNull != null) ...[
            IconButton(
              tooltip: s('move.transfer'),
              icon: const Icon(LucideIcons.arrowLeftRight),
              onPressed: () => showTransferSheet(context, fromId: accountId),
            ),
            IconButton(
              tooltip: s('account.edit'),
              icon: const Icon(LucideIcons.pencil),
              onPressed: () => showAccountSheet(context, existing: acc.valueOrNull),
            ),
          ],
        ],
      ),
      body: AsyncBody<Account?>(
        value: acc,
        builder: (a) {
          if (a == null) return EmptyView(message: s('common.empty'));
          return ListView(
            padding: EdgeInsets.all(t.screenPadding),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(t.spacing('lg')),
                  child: Column(children: [
                    Text(s('accountType.${a.type}'),
                        style: TextStyle(color: t.color('textSecondary'))),
                    SizedBox(height: t.spacing('xs')),
                    MoneyText(a.balanceMinor,
                        signed: true,
                        style: TextStyle(fontSize: t.fontSize('headline'), fontWeight: FontWeight.w700)),
                    if (a.iban.isNotEmpty) ...[
                      SizedBox(height: t.spacing('xs')),
                      Text(a.iban, style: TextStyle(fontSize: t.fontSize('caption'))),
                    ],
                  ]),
                ),
              ),
              SizedBox(height: t.spacing('md')),
              ...moves.when(
                data: (list) => list.isEmpty
                    ? [EmptyView(message: s('account.noMovements'))]
                    : [for (final m in list) _MoveTile(m: m)],
                loading: () => [const Center(child: CircularProgressIndicator())],
                error: (e, _) => [Text('$e')],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoveTile extends ConsumerWidget {
  const _MoveTile({required this.m});
  final AccountMovement m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final label = m.refType == 'payment' || m.refType == 'reversal' || m.refType == 'opening'
        ? s('move.${m.refType}')
        : s('move.${m.kind}');
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(m.date),
        trailing: MoneyText(m.deltaMinor, signed: true),
        onTap: m.refType == 'payment' && m.refId.isNotEmpty
            ? () => context.push('/payments/${m.refId}')
            : null,
      ),
    );
  }
}
