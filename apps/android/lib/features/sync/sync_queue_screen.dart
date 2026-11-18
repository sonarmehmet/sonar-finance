import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_status.dart';
import '../../core/widgets/common.dart';
import '../../data/firestore_paths.dart';

/// Senkron kuyrugu (docs/05): bekleyen belgeler, hatalar, yeniden dene, yerel kopya.
/// Not: Firestore SDK kuyruktaki tek bir yazmayi iptal etmeyi desteklemez;
/// bu yuzden "Vazgec" yoktur — hicbir bekleyen veri sessizce silinmez.
class SyncQueueScreen extends ConsumerWidget {
  const SyncQueueScreen({super.key});

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final db = ref.read(companyPathsProvider).db;
    try {
      await db.disableNetwork();
      await db.enableNetwork();
      await db.waitForPendingWrites().timeout(const Duration(seconds: 10));
      if (context.mounted) showSuccess(context, ref, s('sync.done'));
    } catch (_) {
      if (context.mounted) showWarning(context, ref, s('sync.stillPending'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final state = ref.watch(connectionStateProvider);
    final pending = ref.watch(pendingProvider).valueOrNull ?? const PendingState();
    return Scaffold(
      appBar: AppBar(title: Text(s('sync.title'))),
      body: ListView(padding: EdgeInsets.all(t.screenPadding), children: [
        Card(
          child: ListTile(
            title: Text(s(switch (state) {
              SyncConnection.online => 'connection.online',
              SyncConnection.offline => 'connection.offline',
              SyncConnection.syncing => 'connection.syncing',
              SyncConnection.error => 'connection.syncError',
            })),
            trailing: FilledButton(
              onPressed: () => _retry(context, ref),
              child: Text(s('sync.retry')),
            ),
          ),
        ),
        for (final e in pending.errors.entries)
          Card(
            child: ListTile(
              leading: Icon(Icons.error_outline, color: t.color('negative')),
              title: Text(s('sync.collection.${e.key}')),
              subtitle: Text(e.value),
            ),
          ),
        if (pending.docs.isEmpty && pending.errors.isEmpty)
          EmptyView(message: s('sync.empty')),
        for (final d in pending.docs)
          Card(
            child: ListTile(
              title: Text('${s('sync.collection.${d.collection}')} · ${d.title}'),
              subtitle: Text(d.savedAt?.toLocal().toString().substring(0, 16) ?? s('connection.syncing')),
              trailing: IconButton(
                tooltip: s('sync.exportLocal'),
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: jsonEncode(d.data, toEncodable: _enc)));
                  if (context.mounted) showSuccess(context, ref, s('report.copied'));
                },
              ),
            ),
          ),
      ]),
    );
  }
}

Object? _enc(Object? o) => o is Timestamp ? o.toDate().toIso8601String() : o.toString();
