import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';

/// `shared/design-tokens.json` (sozlesme v1) okuyucusu.
/// Kodda sabit renk/olcu yazilmaz; hepsi buradan gelir.
class SonarTokens {
  SonarTokens._(this._raw);

  final Map<String, dynamic> _raw;

  static Future<SonarTokens> load() async {
    final text = await rootBundle.loadString('assets/shared/design-tokens.json');
    return SonarTokens._(jsonDecode(text) as Map<String, dynamic>);
  }

  String get version => _raw['version'] as String;

  Map<String, dynamic> _section(String name) =>
      (_raw[name] as Map).cast<String, dynamic>();

  static Color parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Color color(String name) => parseHex(_section('color')[name] as String);

  /// Durum anahtarlari: paid, partial, pending, overdue, draft, cancelled.
  Color statusColor(String key) =>
      parseHex((_section('status')[key] as Map)['color'] as String);

  String statusLabel(String key) =>
      (_section('status')[key] as Map)['label'] as String;

  double radius(String name) => (_section('radius')[name] as num).toDouble();

  double spacing(String name) => (_section('spacing')[name] as num).toDouble();

  double fontSize(String name) =>
      ((_section('typography')['size'] as Map)[name] as num).toDouble();

  FontWeight fontWeight(String name) {
    final w = ((_section('typography')['weight'] as Map)[name] as num).toInt();
    return FontWeight.values.firstWhere(
      (e) => e.value == w,
      orElse: () => FontWeight.w400,
    );
  }

  double get bottomNavHeight =>
      ((_section('layout')['mobile'] as Map)['bottomNavHeight'] as num)
          .toDouble();

  double get minTouchTarget =>
      ((_section('layout')['mobile'] as Map)['minTouchTarget'] as num)
          .toDouble();

  double get screenPadding =>
      ((_section('layout')['mobile'] as Map)['screenPadding'] as num)
          .toDouble();
}
