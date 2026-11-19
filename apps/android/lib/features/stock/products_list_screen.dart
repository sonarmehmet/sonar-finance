import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/text/text_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

/// Stok Yonetimi ana listesi: arama, kritik filtre, ozet (toplam urun, kritik, deger).
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';
  bool _criticalOnly = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('stock.write') ?? false;
    final products = ref.watch(productsProvider);
    final pad = t.screenPadding;

    return Scaffold(
      appBar: AppBar(
        title: Text(s('menu.stock')),
        actions: [
          IconButton(
            tooltip: s('stock.warehouses'),
            icon: const Icon(LucideIcons.warehouse),
            onPressed: () => context.push('/warehouses'),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => context.push('/products/new'),
              tooltip: s('stock.newProduct'),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: AsyncBody<List<Product>>(
        value: products,
        onRetry: () => ref.invalidate(productsProvider),
        builder: (all) {
          final active = all.where((p) => p.active).toList();
          final critical = active.where((p) => p.isCritical).length;
          var value = 0;
          for (final p in active) {
            value += p.stockValueMinor;
          }
          final list = all.where((p) {
            if (_criticalOnly && !p.isCritical) return false;
            return matchesQuery(_query, [p.name, p.code, p.barcode, p.category]);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, t.spacing('sm')),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: s('stock.totalProducts'),
                        text: '${active.length}',
                      ),
                    ),
                    SizedBox(width: t.spacing('sm')),
                    Expanded(
                      child: _Stat(
                        label: s('stock.criticalStock'),
                        text: '$critical',
                        color: critical > 0 ? t.color('warning') : null,
                      ),
                    ),
                    SizedBox(width: t.spacing('sm')),
                    Expanded(
                      flex: 2,
                      child: _Stat(
                        label: s('stock.totalValue'),
                        text: formatMinorTry(value),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: SearchBox(onChanged: (v) => setState(() => _query = v)),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: t.spacing('sm')),
                      child: ChoiceChip(
                        label: Text(s('common.all')),
                        selected: !_criticalOnly,
                        onSelected: (_) => setState(() => _criticalOnly = false),
                      ),
                    ),
                    ChoiceChip(
                      label: Text(s('stock.criticalStock')),
                      selected: _criticalOnly,
                      onSelected: (_) => setState(() => _criticalOnly = true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyView()
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(pad, t.spacing('sm'), pad, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: t.spacing('sm')),
                        itemBuilder: (_, i) => _ProductTile(product: list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends ConsumerWidget {
  const _Stat({required this.label, required this.text, this.color});

  final String label;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(t.spacing('md')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.fontSize('caption'),
                color: t.color('textSecondary'),
              ),
            ),
            SizedBox(height: t.spacing('xs')),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: t.fontSize('bodyLg'),
                  fontWeight: t.fontWeight('semibold'),
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final p = product;
    final sub = [p.code, p.category].where((e) => e.isNotEmpty).join(' · ');

    return Opacity(
      opacity: p.active ? 1 : 0.55,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius('card')),
          onTap: () => context.push('/products/${p.id}'),
          child: Padding(
            padding: EdgeInsets.all(t.spacing('md')),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.fontSize('bodyLg'),
                          fontWeight: t.fontWeight('semibold'),
                        ),
                      ),
                      SizedBox(height: t.spacing('xs')),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: t.fontSize('caption'),
                          color: t.color('textSecondary'),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (p.trackStock)
                      Text(
                        '${formatMilli(p.totalQtyMilli)} ${s('unit.${p.unit}')}',
                        style: TextStyle(
                          fontWeight: t.fontWeight('semibold'),
                          color: p.isCritical ? t.color('warning') : null,
                        ),
                      )
                    else
                      Text(
                        s('stock.trackingOff'),
                        style: TextStyle(
                          fontSize: t.fontSize('caption'),
                          color: t.color('textSecondary'),
                        ),
                      ),
                    SizedBox(height: t.spacing('xs')),
                    if (p.isCritical)
                      StatusChip(
                        label: s('stock.criticalBadge'),
                        color: t.color('warning'),
                      )
                    else
                      MoneyText(
                        p.sellPriceMinor,
                        style: TextStyle(
                          fontSize: t.fontSize('caption'),
                          color: t.color('textSecondary'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
