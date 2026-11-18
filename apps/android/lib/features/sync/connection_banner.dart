import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_status.dart';

/// Her zaman gorunen baglanti seridi (docs/05). Cevrimiciyken yalniz ince cizgi.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final st = ref.watch(connectionStateProvider);
    final (key, color) = switch (st) {
      SyncConnection.online => ('connection.online', t.color('positive')),
      SyncConnection.offline => ('connection.offline', t.color('warning')),
      SyncConnection.syncing => ('connection.syncing', t.color('info')),
      SyncConnection.error => ('connection.syncError', t.color('negative')),
    };
    if (st == SyncConnection.online) {
      return Container(height: 2, color: color);
    }
    return Material(
      color: color,
      child: InkWell(
        onTap: () => context.push('/sync'),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Text(s(key),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
