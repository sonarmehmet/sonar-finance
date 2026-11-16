import 'dart:convert';

import 'package:flutter/services.dart';

/// `shared/l10n/tr.json` okuyucusu. Nokta ile yol verilir: `t('menu.overview')`.
/// Parametreler `{ad}` biciminde: `t('messages.invoiceIssued', {'number': 'SF-2026-000001'})`.
///
/// tr.json'da henuz olmayan anahtarlar icin [pendingKeys] gecici kaplama (overlay)
/// kullanilir; bunlar PROGRESS.md "Talepler" tablosunda Ajan 1'den istenmistir.
/// tr.json'a eklendiginde onun degeri onceliklidir.
class Strings {
  Strings._(this._root);

  final Map<String, dynamic> _root;

  static Future<Strings> load() async {
    final text = await rootBundle.loadString('assets/shared/l10n/tr.json');
    return Strings._(jsonDecode(text) as Map<String, dynamic>);
  }

  /// Gecici anahtarlar (tr.json'a eklenene kadar).
  static const Map<String, String> pendingKeys = {
    'auth.title': 'Giriş Yap',
    'auth.subtitle': 'Hesabınızla devam edin',
    'auth.email': 'E-posta',
    'auth.password': 'Şifre',
    'auth.signIn': 'Giriş Yap',
    'auth.signOut': 'Çıkış Yap',
    'auth.required': 'Bu alan zorunlu',
    'auth.errors.invalidCredential': 'E-posta veya şifre hatalı',
    'auth.errors.network': 'Bağlantı kurulamadı. İnternetinizi kontrol edin.',
    'auth.errors.tooManyRequests':
        'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.',
    'auth.errors.generic': 'Giriş yapılamadı',
    'auth.errors.noProfile':
        'Kullanıcı kaydınız bulunamadı. Yöneticinize başvurun.',
    'auth.errors.inactive': 'Hesabınız pasif durumda. Yöneticinize başvurun.',
    'common.comingSoon': 'Yakında',
    'profile.role.admin': 'Yönetici',
    'profile.role.employee': 'Çalışan',
  };

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
    var out = node is String ? node : (pendingKeys[path] ?? path);
    if (args != null) {
      args.forEach((k, v) => out = out.replaceAll('{$k}', v));
    }
    return out;
  }
}
