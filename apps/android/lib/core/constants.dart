import 'dart:convert';

import 'package:flutter/services.dart';

/// `shared/constants.json` (sozlesme v1) okuyucusu.
class SonarConstants {
  SonarConstants._(this._raw);

  final Map<String, dynamic> _raw;

  static Future<SonarConstants> load() async {
    final text = await rootBundle.loadString('assets/shared/constants.json');
    return SonarConstants._(jsonDecode(text) as Map<String, dynamic>);
  }

  List<String> _list(String key) => (_raw[key] as List).cast<String>();

  List<String> get invoiceTypes => _list('invoiceTypes');
  List<String> get paymentMethods => _list('paymentMethods');
  List<String> get units => _list('units');
  List<String> get disciplines => _list('disciplines');
  List<String> get expenseCategories => _list('defaultExpenseCategories');
  List<String> get permissions => _list('permissions');

  List<int> get vatRatesBp =>
      (_raw['vatRatesBp'] as List).map((e) => (e as num).toInt()).toList();
}
