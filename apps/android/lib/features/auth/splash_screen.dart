import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s('app.name'),
              style: TextStyle(
                fontSize: t.fontSize('title'),
                fontWeight: t.fontWeight('bold'),
                color: t.color('accent'),
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: t.spacing('xl')),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: t.color('accent'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
