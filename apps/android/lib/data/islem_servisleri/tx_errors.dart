import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/l10n/strings.dart';

/// Islem servislerinin firlattigi is hatasi. [code] metin anahtarini belirler:
/// `alreadyProcessed`, `insufficientStock`, `cannotCancelPaid` -> `messages.*`;
/// digerleri -> `errors.*`. [args] `{ad}` yer tutucularini doldurur.
class TxException implements Exception {
  const TxException(this.code, [this.args = const {}]);

  final String code;
  final Map<String, String> args;

  String message(Strings s) {
    const inMessages = {
      'alreadyProcessed',
      'insufficientStock',
      'cannotCancelPaid',
    };
    final key = inMessages.contains(code) ? 'messages.$code' : 'errors.$code';
    return s(key, args);
  }

  @override
  String toString() => 'TxException($code, $args)';
}

/// Her tur hatayi kullaniciya gosterilecek metne cevirir (docs/04 §9: neden belirtilir).
String describeTxError(Object error, Strings s) {
  if (error is TxException) return error.message(s);
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return s('errors.offline');
      case 'permission-denied':
        return s('errors.permission');
      case 'aborted':
        return s('errors.conflict');
      default:
        return '${s('errors.generic')} (${error.code})';
    }
  }
  return s('errors.generic');
}
