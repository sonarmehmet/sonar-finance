import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/islem_servisleri/stock_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/product.dart';
import '../../data/models/stock_level.dart';
import '../../data/models/warehouse.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../data/write_helpers.dart';

enum StockAction { stockIn, stockOut, count, transfer }

String _titleKey(StockAction a) => switch (a) {
      StockAction.stockIn => 'stock.stockIn',
      StockAction.stockOut => 'stock.stockOut',
      StockAction.count => 'stock.adjust',
      StockAction.transfer => 'stock.transfer',
    };

/// Stok islemi alt sayfasi. Basarili olursa `true` doner.
Future<bool?> showStockActionSheet(
  BuildContext context, {
  required Product product,
  required StockAction action,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StockActionSheet(product: product, action: action),
  );
}

class _StockActionSheet extends ConsumerStatefulWidget {
  const _StockActionSheet({required this.product, required this.action});

  final Product product;
  final StockAction action;

  @override
  ConsumerState<_StockActionSheet> createState() => _StockActionSheetState();
}

class _StockActionSheetState extends ConsumerState<_StockActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _reason = TextEditingController();
  String? _warehouseId;
  String? _toWarehouseId;
  bool _busy = false;

  /// Sayfa acilinca uretilir; hata sonrasi yeniden denemede AYNI kalir.
  final String _txId = newId();

  @override
  void initState() {
    super.initState();
    if (widget.action == StockAction.stockIn && widget.product.avgCostMinor > 0) {
      _cost.text = formatMinor(widget.product.avgCostMinor);
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final s = ref.read(stringsProvider);
    final svc = ref.read(stockServiceProvider);
    final p = widget.product;
    final qty = parseMilli(_qty.text) ?? 0;
    setState(() => _busy = true);
    try {
      switch (widget.action) {
        case StockAction.stockIn:
          await svc.stockIn(
            txId: _txId,
            productId: p.id,
            warehouseId: _warehouseId!,
            qtyMilli: qty,
            unitCostMinor: parseMinor(_cost.text) ?? 0,
            note: _reason.text,
          );
        case StockAction.stockOut:
          await svc.stockOut(
            txId: _txId,
            productId: p.id,
            warehouseId: _warehouseId!,
            qtyMilli: qty,
            reason: _reason.text,
          );
        case StockAction.count:
          await svc.stockCount(
            txId: _txId,
            productId: p.id,
            warehouseId: _warehouseId!,
            countedMilli: qty,
            reason: _reason.text,
          );
        case StockAction.transfer:
          await svc.transfer(
            txId: _txId,
            productId: p.id,
            fromWarehouseId: _warehouseId!,
            toWarehouseId: _toWarehouseId!,
            qtyMilli: qty,
            note: _reason.text,
          );
      }
      if (!mounted) return;
      showSuccess(context, ref, s('stock.done'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final a = widget.action;
    final p = widget.product;
    final unit = s('unit.${p.unit}');
    final warehouses = (ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[])
        .where((w) => w.active)
        .toList();
    final levels = ref.watch(productLevelsProvider(p.id)).valueOrNull ?? const <StockLevel>[];
    final levelQty = {for (final l in levels) l.warehouseId: l.qtyMilli};
    final gap = SizedBox(height: t.spacing('lg'));
    final reasonRequired = a == StockAction.stockOut || a == StockAction.count;

    // Varsayilan depo secimi (ilk acilista).
    _warehouseId ??= warehouses
        .where((w) => w.isDefault)
        .map((w) => w.id)
        .firstOrNull ??
        warehouses.map((w) => w.id).firstOrNull;

    DropdownButtonFormField<String> whDropdown({
      required String label,
      required String? value,
      required ValueChanged<String?> onChanged,
      String? exclude,
    }) {
      final items = warehouses.where((w) => w.id != exclude).toList();
      return DropdownButtonFormField<String>(
        value: items.any((w) => w.id == value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final w in items)
            DropdownMenuItem(
              value: w.id,
              child: Text(
                '${w.name} (${formatMilli(levelQty[w.id] ?? 0)} $unit)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
        validator: (v) => v == null ? s('validation.required') : null,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: t.screenPadding,
        right: t.screenPadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + t.screenPadding,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${s(_titleKey(a))} · ${p.name}',
                style: TextStyle(
                  fontSize: t.fontSize('title'),
                  fontWeight: t.fontWeight('semibold'),
                ),
              ),
              gap,
              whDropdown(
                label: a == StockAction.transfer
                    ? s('stock.fromWarehouse')
                    : s('stock.warehouse'),
                value: _warehouseId,
                onChanged: (v) => setState(() {
                  _warehouseId = v;
                  if (_toWarehouseId == v) _toWarehouseId = null;
                }),
              ),
              if (a == StockAction.transfer) ...[
                gap,
                whDropdown(
                  label: s('stock.toWarehouse'),
                  value: _toWarehouseId,
                  exclude: _warehouseId,
                  onChanged: (v) => setState(() => _toWarehouseId = v),
                ),
              ],
              gap,
              TextFormField(
                controller: _qty,
                keyboardType: moneyKeyboard,
                inputFormatters: moneyInputFormatters,
                decoration: InputDecoration(
                  labelText: a == StockAction.count
                      ? s('stock.countedQty')
                      : s('invoiceForm.quantity'),
                  suffixText: unit,
                  helperText: a == StockAction.count && _warehouseId != null
                      ? '${s('stock.currentQty')}: ${formatMilli(levelQty[_warehouseId] ?? 0)} $unit'
                      : null,
                ),
                validator: (v) {
                  final m = parseMilli(v ?? '');
                  if (m == null) return s('validation.invalidQty');
                  // Sayimda 0 gecerli (depo bos sayildi); digerlerinde > 0.
                  if (a == StockAction.count ? m < 0 : m <= 0) {
                    return s('validation.invalidQty');
                  }
                  return null;
                },
              ),
              if (a == StockAction.stockIn) ...[
                gap,
                TextFormField(
                  controller: _cost,
                  keyboardType: moneyKeyboard,
                  inputFormatters: moneyInputFormatters,
                  decoration: InputDecoration(
                    labelText: s('stock.unitCost'),
                    helperText: s('stock.unitCostHint'),
                    suffixText: '₺',
                  ),
                  validator: (v) {
                    final m = parseMinor(v ?? '');
                    return (m == null || m < 0) ? s('validation.invalidAmount') : null;
                  },
                ),
              ],
              gap,
              TextFormField(
                controller: _reason,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: reasonRequired ? s('stock.reason') : s('stock.note'),
                ),
                validator: (v) => (reasonRequired && (v == null || v.trim().isEmpty))
                    ? s('validation.required')
                    : null,
              ),
              gap,
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s('common.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
