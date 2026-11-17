import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/text/text_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/models/invoice.dart';
import '../../data/models/party.dart';
import '../../data/models/product.dart';
import '../../data/models/warehouse.dart';
import '../../data/repositories/party_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../data/write_helpers.dart';

/// Cari secici: arama + liste. Secilen [Party] doner.
Future<Party?> pickParty(BuildContext context) {
  return showModalBottomSheet<Party>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PartyPicker(),
  );
}

class _PartyPicker extends ConsumerStatefulWidget {
  const _PartyPicker();

  @override
  ConsumerState<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends ConsumerState<_PartyPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final parties = ref.watch(partiesProvider);
    final height = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.screenPadding),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          SizedBox(height: t.spacing('sm')),
          Expanded(
            child: AsyncBody<List<Party>>(
              value: parties,
              builder: (all) {
                final list = all
                    .where((p) => p.active && matchesQuery(_q, [p.name, p.taxNo, p.phone]))
                    .toList();
                if (list.isEmpty) return const EmptyView();
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final kinds = [
                      if (p.isCustomer) s('party.customer'),
                      if (p.isSupplier) s('party.supplier'),
                    ].join(' · ');
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(kinds),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Kalem ekle/duzenle. [initial] null ise yeni kalem. Hesaplanan tutarlar
/// servis tarafinda yeniden uretilir; burada yalniz girdiler toplanir.
Future<InvoiceLine?> editInvoiceLine(
  BuildContext context, {
  InvoiceLine? initial,
  required String invoiceType,
}) {
  return showModalBottomSheet<InvoiceLine>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LineEditor(initial: initial, invoiceType: invoiceType),
  );
}

class _LineEditor extends ConsumerStatefulWidget {
  const _LineEditor({required this.initial, required this.invoiceType});

  final InvoiceLine? initial;
  final String invoiceType;

  @override
  ConsumerState<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends ConsumerState<_LineEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _desc;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  String? _productId;
  bool _trackStock = false;
  String _unit = 'adet';
  int _vatBp = 2000;
  String? _warehouseId;

  bool get _isPurchaseSide =>
      widget.invoiceType == 'purchase' || widget.invoiceType == 'purchase_return';

  @override
  void initState() {
    super.initState();
    final l = widget.initial;
    _desc = TextEditingController(text: l?.description ?? '');
    _qty = TextEditingController(text: l == null ? '1' : formatMilli(l.qtyMilli));
    _price = TextEditingController(
      text: (l == null || l.unitPriceMinor == 0) ? '' : formatMinor(l.unitPriceMinor),
    );
    _discount = TextEditingController(
      text: (l == null || l.discountBp == 0) ? '' : formatBpPlain(l.discountBp),
    );
    _productId = l?.productId;
    _unit = l?.unit ?? 'adet';
    _vatBp = l?.vatBp ??
        (ref.read(constantsProvider).vatRatesBp.contains(2000) ? 2000 : 0);
    _warehouseId = l?.warehouseId;
    if (_productId != null) {
      final prod = ref
          .read(productsProvider)
          .valueOrNull
          ?.where((p) => p.id == _productId)
          .firstOrNull;
      _trackStock = prod?.trackStock ?? (_warehouseId != null);
    }
  }

  @override
  void dispose() {
    for (final c in [_desc, _qty, _price, _discount]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyProduct(Product p, List<Warehouse> warehouses) {
    setState(() {
      _productId = p.id;
      _trackStock = p.trackStock;
      _desc.text = p.name;
      _unit = p.unit;
      _vatBp = p.vatBp;
      final price = _isPurchaseSide ? p.buyPriceMinor : p.sellPriceMinor;
      _price.text = price == 0 ? '' : formatMinor(price);
      if (p.trackStock) {
        _warehouseId ??= warehouses
            .where((w) => w.active && w.isDefault)
            .map((w) => w.id)
            .firstOrNull;
      }
    });
  }

  Future<void> _chooseProduct(List<Warehouse> warehouses) async {
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ProductPicker(),
    );
    if (p != null) _applyProduct(p, warehouses);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final line = InvoiceLine(
      lineId: widget.initial?.lineId ?? newId(),
      productId: _productId,
      description: _desc.text.trim(),
      qtyMilli: parseMilli(_qty.text) ?? 0,
      unit: _unit,
      unitPriceMinor: parseMinor(_price.text) ?? 0,
      discountBp: parseBp(_discount.text) ?? 0,
      vatBp: _vatBp,
      warehouseId: _trackStock ? _warehouseId : null,
    );
    Navigator.pop(context, line);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final constants = ref.watch(constantsProvider);
    final warehouses = (ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[])
        .where((w) => w.active || w.id == _warehouseId)
        .toList();
    final gap = SizedBox(height: t.spacing('lg'));
    final units = {...constants.units, _unit}.toList();
    final vats = {...constants.vatRatesBp, _vatBp}.toList()..sort();
    final selectedProductName = _productId == null
        ? s('invoice.selectProduct')
        : _desc.text;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null
                    ? s('invoiceForm.addLine')
                    : s('invoice.editLine'),
                style: TextStyle(
                  fontSize: t.fontSize('title'),
                  fontWeight: t.fontWeight('semibold'),
                ),
              ),
              gap,
              OutlinedButton(
                onPressed: () => _chooseProduct(warehouses),
                child: Text(
                  selectedProductName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              gap,
              TextFormField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s('invoiceForm.description')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s('validation.required')
                    : null,
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      keyboardType: moneyKeyboard,
                      inputFormatters: moneyInputFormatters,
                      decoration: InputDecoration(labelText: s('invoiceForm.quantity')),
                      validator: (v) {
                        final m = parseMilli(v ?? '');
                        return (m == null || m <= 0)
                            ? s('validation.invalidQty')
                            : null;
                      },
                    ),
                  ),
                  SizedBox(width: t.spacing('md')),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: InputDecoration(labelText: s('invoiceForm.unit')),
                      items: [
                        for (final u in units)
                          DropdownMenuItem(value: u, child: Text(s('unit.$u'))),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ),
                ],
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _price,
                      keyboardType: moneyKeyboard,
                      inputFormatters: moneyInputFormatters,
                      decoration: InputDecoration(
                        labelText: s('invoiceForm.unitPrice'),
                        suffixText: '₺',
                      ),
                      validator: (v) {
                        final m = parseMinor(v ?? '');
                        return (m == null || m < 0)
                            ? s('validation.invalidAmount')
                            : null;
                      },
                    ),
                  ),
                  SizedBox(width: t.spacing('md')),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _discount,
                      keyboardType: moneyKeyboard,
                      inputFormatters: moneyInputFormatters,
                      decoration: InputDecoration(labelText: s('invoice.discountPct')),
                      validator: (v) {
                        final x = (v ?? '').trim();
                        if (x.isEmpty) return null;
                        return parseBp(x) == null
                            ? s('validation.invalidAmount')
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              gap,
              DropdownButtonFormField<int>(
                value: _vatBp,
                decoration: InputDecoration(labelText: s('invoiceForm.vat')),
                items: [
                  for (final v in vats)
                    DropdownMenuItem(value: v, child: Text(formatBp(v))),
                ],
                onChanged: (v) => setState(() => _vatBp = v ?? _vatBp),
              ),
              if (_trackStock) ...[
                gap,
                DropdownButtonFormField<String>(
                  value: warehouses.any((w) => w.id == _warehouseId)
                      ? _warehouseId
                      : null,
                  decoration: InputDecoration(
                    labelText: s('invoiceForm.warehouse'),
                    helperText: s('invoice.stockWarehouseHint'),
                  ),
                  items: [
                    for (final w in warehouses)
                      DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) => setState(() => _warehouseId = v),
                  validator: (v) =>
                      v == null ? s('validation.required') : null,
                ),
              ],
              gap,
              FilledButton(onPressed: _submit, child: Text(s('common.save'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker();

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final products = ref.watch(productsProvider);
    final height = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.screenPadding),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          SizedBox(height: t.spacing('sm')),
          Expanded(
            child: AsyncBody<List<Product>>(
              value: products,
              builder: (all) {
                final list = all
                    .where((p) =>
                        p.active && matchesQuery(_q, [p.name, p.code, p.barcode]))
                    .toList();
                if (list.isEmpty) return const EmptyView();
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.code),
                      trailing: p.trackStock
                          ? Text(formatMilli(p.totalQtyMilli))
                          : null,
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
