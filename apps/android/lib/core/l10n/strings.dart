import 'dart:convert';

import 'package:flutter/services.dart';

import 'pending_strings.dart';

/// `shared/l10n/tr.json` okuyucusu. Nokta ile yol verilir: `t('menu.overview')`.
/// Parametreler `{ad}` biciminde: `t('messages.invoiceIssued', {'number': 'SF-2026-000001'})`.
///
/// tr.json'da henuz olmayan anahtarlar icin [kPendingStrings] gecici kaplamasi
/// kullanilir; bunlar PROGRESS.md "Talepler" tablosunda Ajan 1'den istenmistir.
/// tr.json'a eklendiginde onun degeri onceliklidir.
class Strings {
  Strings._(this._root);

  final Map<String, dynamic> _root;

  static Future<Strings> load() async {
    final text = await rootBundle.loadString('assets/shared/l10n/tr.json');
    return Strings._(jsonDecode(text) as Map<String, dynamic>);
  }

  String call(String path, [Map<String, String>? args]) {
    Object? node = _root;
    for (final part in path.split('.')) {
      if (node is Map && node.containsKey(part)) {
        node = node[part];
      } else {
        node = null;
        break;
      }
    }
    var out = node is String ? node : (kPendingStrings[path] ?? path);
    if (args != null) {
      args.forEach((k, v) => out = out.replaceAll('{$k}', v));
    }
    return out;
  }
}
