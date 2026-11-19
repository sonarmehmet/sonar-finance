import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(s('mobileNav.profile'))),
      body: ListView(
        padding: EdgeInsets.all(t.screenPadding),
        children: [
          if (profile != null)
            Card(
              child: Padding(
                padding: EdgeInsets.all(t.spacing('lg')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName.isEmpty
                          ? profile.email
                          : profile.displayName,
                      style: TextStyle(
                        fontSize: t.fontSize('title'),
                        fontWeight: t.fontWeight('semibold'),
                      ),
                    ),
                    SizedBox(height: t.spacing('xs')),
                    Text(
                      profile.email,
                      style: TextStyle(color: t.color('textSecondary')),
                    ),
                    SizedBox(height: t.spacing('md')),
                    Text(
                      s('profile.role.${profile.role}'),
                      style: TextStyle(
                        color: t.color('accent'),
                        fontWeight: t.fontWeight('medium'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: t.spacing('md')),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.refreshCw),
              title: Text(s('sync.open')),
              onTap: () => context.push('/sync'),
            ),
          ),
          SizedBox(height: t.spacing('xl')),
          OutlinedButton.icon(
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: Text(s('auth.signOut')),
          ),
        ],
      ),
    );
  }
}
