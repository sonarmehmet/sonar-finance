import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Henuz yapilmamis sekmeler icin ortak iskelet. Ilgili gorev bitince
/// ekranin kendi dosyasinda bu sinif yerine gercek icerik yazilir.
class PlaceholderPage extends ConsumerWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          s('common.comingSoon'),
          style: TextStyle(
            fontSize: t.fontSize('bodyLg'),
            color: t.color('textSecondary'),
          ),
        ),
      ),
    );
  }
}
