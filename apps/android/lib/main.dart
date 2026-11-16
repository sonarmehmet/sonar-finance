import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/l10n/strings.dart';
import 'core/providers.dart';
import 'core/theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = await SonarTokens.load();
  final strings = await Strings.load();
  await bootstrapFirebase();

  runApp(
    ProviderScope(
      overrides: [
        tokensProvider.overrideWithValue(tokens),
        stringsProvider.overrideWithValue(strings),
      ],
      child: const SonarApp(),
    ),
  );
}
