import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';

/// Giris yapilmis ama `users/{uid}` belgesi yok ya da pasif.
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final message = (profile != null && !profile.active)
        ? s('auth.errors.inactive')
        : s('auth.errors.noProfile');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(LucideIcons.shieldAlert, size: 48, color: t.color('warning')),
              SizedBox(height: t.spacing('xl')),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: t.fontSize('bodyLg')),
              ),
              SizedBox(height: t.spacing('xxl')),
              OutlinedButton(
                onPressed: () => ref.read(firebaseAuthProvider).signOut(),
                child: Text(s('auth.signOut')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
