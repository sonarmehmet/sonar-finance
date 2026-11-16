import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'l10n/strings.dart';
import 'theme/tokens.dart';

/// main() icinde yuklenip override edilir.
final tokensProvider = Provider<SonarTokens>(
  (ref) => throw UnimplementedError('tokensProvider override edilmedi'),
);

final stringsProvider = Provider<Strings>(
  (ref) => throw UnimplementedError('stringsProvider override edilmedi'),
);

final constantsProvider = Provider<SonarConstants>(
  (ref) => throw UnimplementedError('constantsProvider override edilmedi'),
);
