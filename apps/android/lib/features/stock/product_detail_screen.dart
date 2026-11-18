import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/product.dart';
import '../../data/models/stock_level.dart';
import '../../data/models/stock_movement.dart';
import '../../data/models/warehouse.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import 'stock_action_sheet.dart';

/// Urun detayi: ozet bilgiler + depo bazinda stok.
/// Stok hareketleri ve giris/cikis/sayim/transfer eylemleri A5'te eklenecek.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('stock.write') ?? false;
    final product = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: Text(product.valueOrNull?.name ?? ''),
        actions: [
          if (canWrite && product.valueOrNull != null)
            IconButton(
              tooltip: s('common.edit'),
              icon: const Icon(LucideIcons.pencil),
              onPressed: () => context.push('/products/$productId/edit'),
            ),
        ],
      ),
      body: AsyncBody<Product?>(
        value: product,
        onRetry: () => ref.invalidate(productProvider(productId)),
        builder: (p) {
          if (p == null) return const EmptyView();
          return ListView(
            padding: EdgeInsets.all(t.screenPadding),
            children: [
              _InfoCard(product: p),
              SizedBox(height: t.spacing('xl')),
              if (p.trackStock) _Levels(product: p),
              if (p.trackStock && canWrite) ...[
                SizedBox(height: t.spacing('xl')),
                _Actions(product: p),
              ],
              if (p.trackStock) ...[
                SizedBox(height: t.spacing('xl')),
                _Movements(product: p),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final p = product;
    final unit = s('unit.${p.unit}');

    Widget kv(String k, Widget v) => Padding(
          padding: EdgeInsets.symmetric(vertical: t.spacing('xs')),
          child: Row(
            children: [
              Expanded(
                child: Text(k, style: TextStyle(color: t.color('textSecondary'))),
              ),
              v,
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(t.spacing('lg')),
        child: Column(
          children: [
            kv(s('stock.code'), Text(p.code)),
            if (p.category.isNotEmpty) kv(s('stock.category'), Text(p.category)),
            if (p.barcode.isNotEmpty) kv(s('fields.barcode'), Text(p.barcode)),
            kv(s('fields.vat'), Text(formatBp(p.vatBp))),
            kv(s('fields.buyPrice'), MoneyText(p.buyPriceMinor)),
            kv(s('fields.sellPrice'), MoneyText(p.sellPriceMinor)),
            if (p.trackStock) ...[
              const Divider(),
              kv(
                s('stock.quantity'),
                Text(
                  '${formatMilli(p.totalQtyMilli)} $unit',
                  style: TextStyle(
                    fontWeight: t.fontWeight('semibold'),
                    color: p.isCritical ? t.color('warning') : null,
                  ),
                ),
              ),
              kv(s('stock.unitCost'), MoneyText(p.avgCostMinor)),
              kv(s('stock.value'), MoneyText(p.stockValueMinor)),
              if (p.minStockMilli > 0)
                kv(
                  s('stock.minLevel'),
                  Text('${formatMilli(p.minStockMilli)} $unit'),
                ),
            ],
            if (!p.active)
              Padding(
                padding: EdgeInsets.only(top: t.spacing('md')),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: s('common.passive'),
                    color: t.color('neutral'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Levels extends ConsumerWidget {
  const _Levels({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final levels = ref.watch(productLevelsProvider(product.id));
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[];
    final names = {for (final w in warehouses) w.id: w.name};
    final unit = s('unit.${product.unit}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s('stock.byWarehouse'),
          style: TextStyle(
            fontSize: t.fontSize('bodyLg'),
            fontWeight: t.fontWeight('semibold'),
          ),
        ),
        SizedBox(height: t.spacing('md')),
        levels.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (List<StockLevel> list) {
            final shown = list.where((l) => l.qtyMilli != 0).toList();
            if (shown.isEmpty) {
              return Text(
                s('stock.noLevels'),
                style: TextStyle(color: t.color('textSecondary')),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(),
                    ListTile(
                      title: Text(names[shown[i].warehouseId] ?? shown[i].warehouseId),
                      trailing: Text(
                        '${formatMilli(shown[i].qtyMilli)} $unit',
                        style: TextStyle(fontWeight: t.fontWeight('semibold')),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);

    Widget btn(IconData icon, String label, StockAction action) => OutlinedButton.icon(
          onPressed: () => showStockActionSheet(
            context,
            product: product,
            action: action,
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, overflow: TextOverflow.ellipsis),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s('stock.actions'),
          style: TextStyle(
            fontSize: t.fontSize('bodyLg'),
            fontWeight: t.fontWeight('semibold'),
          ),
        ),
        SizedBox(height: t.spacing('md')),
        btn(LucideIcons.packagePlus, s('stock.stockIn'), StockAction.stockIn),
        SizedBox(height: t.spacing('sm')),
        btn(LucideIcons.packageMinus, s('stock.stockOut'), StockAction.stockOut),
        SizedBox(height: t.spacing('sm')),
        btn(LucideIcons.clipboardCheck, s('stock.adjust'), StockAction.count),
        SizedBox(height: t.spacing('sm')),
        btn(LucideIcons.arrowLeftRight, s('stock.transfer'), StockAction.transfer),
      ],
    );
  }
}

class _Movements extends ConsumerWidget {
  const _Movements({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final moves = ref.watch(productMovementsProvider(product.id));
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[];
    final names = {for (final w in warehouses) w.id: w.name};
    final unit = s('unit.${product.unit}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s('stock.movements'),
          style: TextStyle(
            fontSize: t.fontSize('bodyLg'),
            fontWeight: t.fontWeight('semibold'),
          ),
        ),
        SizedBox(height: t.spacing('md')),
        moves.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (List<StockMovement> list) {
            if (list.isEmpty) {
              return Text(
                s('stock.noMovements'),
                style: TextStyle(color: t.color('textSecondary')),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: EdgeInsets.all(t.spacing('md')),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s('stock.type.${list[i].type}')),
                                SizedBox(height: t.spacing('xs')),
                                Text(
                                  [
                                    formatDisplayDate(list[i].date),
                                    names[list[i].warehouseId] ?? '',
                                    if (list[i].note.isNotEmpty) list[i].note,
                                  ].where((e) => e.isNotEmpty).join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: t.fontSize('caption'),
                                    color: t.color('textSecondary'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${list[i].deltaMilli > 0 ? '+' : ''}${formatMilli(list[i].deltaMilli)} $unit',
                            style: TextStyle(
                              fontWeight: t.fontWeight('semibold'),
                              color: list[i].deltaMilli >= 0
                                  ? t.color('positive')
                                  : t.color('negative'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
