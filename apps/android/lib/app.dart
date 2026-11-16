import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class SonarApp extends ConsumerWidget {
  const SonarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(tokensProvider);
    final strings = ref.watch(stringsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: strings('app.name'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(tokens),
      themeMode: ThemeMode.dark,
      darkTheme: buildTheme(tokens),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
