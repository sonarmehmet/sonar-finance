import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../invoices/invoices_list_screen.dart';

/// "Islemler" sekmesi: fatura listesi. Tahsilat/odeme/gider A6/A7 ile eklenecek.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return InvoicesListScreen(title: s('mobileNav.transactions'));
  }
}
