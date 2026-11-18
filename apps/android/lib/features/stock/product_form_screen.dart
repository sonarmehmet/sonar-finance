import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/text/text_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

/// Yeni urun / urun duzenle. [productId] null ise yeni kayit.
class ProductFormScreen extends ConsumerWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final id = productId;
    if (id == null) {
      return _ProductForm(title: s('stock.newProduct'), initial: null);
    }
    final product = ref.watch(productProvider(id));
    return product.when(
      data: (p) => p == null
          ? Scaffold(appBar: AppBar(), body: const EmptyView())
          : _ProductForm(title: s('stock.editProduct'), initial: p),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({required this.title, required this.initial});

  final String title;
  final Product? initial;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _barcode;
  late final TextEditingController _buy;
  late final TextEditingController _sell;
  late final TextEditingController _minStock;
  late String _unit;
  late int _vatBp;
  late bool _trackStock;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    final defaultVat =
        ref.read(constantsProvider).vatRatesBp.contains(2000) ? 2000 : 0;
    _code = TextEditingController(text: p?.code ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _buy = TextEditingController(
      text: (p == null || p.buyPriceMinor == 0) ? '' : formatMinor(p.buyPriceMinor),
    );
    _sell = TextEditingController(
      text: (p == null || p.sellPriceMinor == 0) ? '' : formatMinor(p.sellPriceMinor),
    );
    _minStock = TextEditingController(
      text: (p == null || p.minStockMilli == 0) ? '' : formatMilli(p.minStockMilli),
    );
    _unit = p?.unit ?? 'adet';
    _vatBp = p?.vatBp ?? defaultVat;
    _trackStock = p?.trackStock ?? true;
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _category, _barcode, _buy, _sell, _minStock]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _moneyValidator(String? v) {
    final x = (v ?? '').trim();
    if (x.isEmpty) return null;
    final m = parseMinor(x);
    return (m == null || m < 0) ? ref.read(stringsProvider)('validation.invalidAmount') : null;
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final s = ref.read(stringsProvider);
    final repo = ref.read(productRepositoryProvider);
    final initial = widget.initial;
    setState(() => _busy = true);
    try {
      final draft = Product(
        id: initial?.id ?? '',
        companyId: initial?.companyId ?? '',
        code: _code.text.trim(),
        name: _name.text.trim(),
        category: _category.text.trim(),
        unit: _unit,
        vatBp: _vatBp,
        trackStock: _trackStock,
        buyPriceMinor: parseMinor(_buy.text) ?? 0,
        sellPriceMinor: parseMinor(_sell.text) ?? 0,
        minStockMilli: parseMilli(_minStock.text) ?? 0,
        barcode: _barcode.text.trim(),
        active: _active,
      );
      final synced = initial == null
          ? (await repo.create(draft)).synced
          : await repo.update(draft);
      if (!mounted) return;
      if (synced) {
        showSuccess(context, ref, s('messages.saved'));
      } else {
        showWarning(context, ref, s('messages.queued'));
      }
      context.pop();
    } on FirebaseException catch (e) {
      if (mounted) showError(context, ref, '${s('messages.saveFailed')} (${e.code})');
    } catch (_) {
      if (mounted) showError(context, ref, s('messages.saveFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final constants = ref.watch(constantsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('stock.write') ?? false;
    final existing = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final gap = SizedBox(height: t.spacing('lg'));

    final units = {...constants.units, _unit}.toList();
    final vats = {...constants.vatRatesBp, _vatBp}.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(t.screenPadding),
          children: [
            if (!canWrite)
              Padding(
                padding: EdgeInsets.only(bottom: t.spacing('lg')),
                child: Text(
                  s('common.noPermission'),
                  style: TextStyle(color: t.color('warning')),
                ),
              ),
            TextFormField(
              controller: _code,
              enabled: canWrite,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: s('stock.code')),
              validator: (v) {
                final x = (v ?? '').trim();
                if (x.isEmpty) return s('validation.required');
                final dup = existing.any(
                  (e) => e.id != widget.initial?.id && foldTr(e.code) == foldTr(x),
                );
                return dup ? s('validation.duplicateCode') : null;
              },
            ),
            gap,
            TextFormField(
              controller: _name,
              enabled: canWrite,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s('stock.name')),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s('validation.required') : null,
            ),
            gap,
            TextFormField(
              controller: _category,
              enabled: canWrite,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s('stock.category')),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: InputDecoration(labelText: s('stock.unit')),
                    items: [
                      for (final u in units)
                        DropdownMenuItem(value: u, child: Text(s('unit.$u'))),
                    ],
                    onChanged: canWrite
                        ? (v) => setState(() => _unit = v ?? _unit)
                        : null,
                  ),
                ),
                SizedBox(width: t.spacing('md')),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _vatBp,
                    decoration: InputDecoration(labelText: s('fields.vat')),
                    items: [
                      for (final v in vats)
                        DropdownMenuItem(value: v, child: Text(formatBp(v))),
                    ],
                    onChanged: canWrite
                        ? (v) => setState(() => _vatBp = v ?? _vatBp)
                        : null,
                  ),
                ),
              ],
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buy,
                    enabled: canWrite,
                    keyboardType: moneyKeyboard,
                    inputFormatters: moneyInputFormatters,
                    decoration: InputDecoration(
                      labelText: s('fields.buyPrice'),
                      suffixText: '₺',
                    ),
                    validator: _moneyValidator,
                  ),
                ),
                SizedBox(width: t.spacing('md')),
                Expanded(
                  child: TextFormField(
                    controller: _sell,
                    enabled: canWrite,
                    keyboardType: moneyKeyboard,
                    inputFormatters: moneyInputFormatters,
                    decoration: InputDecoration(
                      labelText: s('fields.sellPrice'),
                      suffixText: '₺',
                    ),
                    validator: _moneyValidator,
                  ),
                ),
              ],
            ),
            gap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s('fields.trackStock')),
              value: _trackStock,
              onChanged:
                  canWrite ? (v) => setState(() => _trackStock = v) : null,
            ),
            if (_trackStock) ...[
              SizedBox(height: t.spacing('sm')),
              TextFormField(
                controller: _minStock,
                enabled: canWrite,
                keyboardType: moneyKeyboard,
                inputFormatters: moneyInputFormatters,
                decoration: InputDecoration(labelText: s('stock.minLevel')),
                validator: (v) {
                  final x = (v ?? '').trim();
                  if (x.isEmpty) return null;
                  final m = parseMilli(x);
                  return (m == null || m < 0) ? s('validation.invalidQty') : null;
                },
              ),
            ],
            gap,
            TextFormField(
              controller: _barcode,
              enabled: canWrite,
              decoration: InputDecoration(labelText: s('fields.barcode')),
            ),
            SizedBox(height: t.spacing('sm')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s('fields.active')),
              value: _active,
              onChanged: canWrite ? (v) => setState(() => _active = v) : null,
            ),
            SizedBox(height: t.spacing('lg')),
            FilledButton(
              onPressed: (_busy || !canWrite) ? null : _save,
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
    );
  }
}
