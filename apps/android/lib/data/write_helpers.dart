import 'dart:async';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Istemci tarafi ID (UUID v4, kucuk harf) — docs/02.
String newId() => _uuid.v4().toLowerCase();

/// Ana veri yazimi (cari/urun/depo). Firestore `set/update` gelecegi sunucu
/// onayini bekler; cevrimdisiyken tamamlanmaz ama yazma yerel kuyruga alinmistir.
///
/// Doner: `true` = sunucu onayladi, `false` = sure doldu, kuyrukta bekliyor.
/// Kural reddi gibi gercek hatalar istisna olarak yukari firlatilir.
///
/// NOT: Finansal islemler (04) bunu KULLANMAZ; onlar `runTransaction` ile
/// cevrimdisiyken reddedilir (CONTRACTS kural 5).
Future<bool> writeOrQueue(
  Future<void> write, {
  Duration wait = const Duration(seconds: 6),
}) async {
  try {
    await write.timeout(wait);
    return true;
  } on TimeoutException {
    return false;
  }
}
