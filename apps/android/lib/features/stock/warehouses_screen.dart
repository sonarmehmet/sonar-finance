import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/warehouse.dart';
import '../../data/repositories/warehouse_repository.dart';

/// Depolar: liste + ekle/duzenle (alt sayfa).
class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref, {
    Warehouse? warehouse,
    required List<Warehouse> all,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WarehouseSheet(initial: warehouse, all: all),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('stock.write') ?? false;
    final warehouses = ref.watch(warehousesProvider);
    final all = warehouses.valueOrNull ?? const <Warehouse>[];

    return Scaffold(
      appBar: AppBar(title: Text(s('stock.warehouses'))),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => _openSheet(context, ref, all: all),
              tooltip: s('stock.newWarehouse'),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: AsyncBody<List<Warehouse>>(
        value: warehouses,
        onRetry: () => ref.invalidate(warehousesProvider),
        builder: (list) {
          if (list.isEmpty) return const EmptyView();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              t.screenPadding,
              t.screenPadding,
              t.screenPadding,
              96,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(height: t.spacing('sm')),
            itemBuilder: (_, i) {
              final w = list[i];
              return Opacity(
                opacity: w.active ? 1 : 0.55,
                child: Card(
                  child: ListTile(
                    leading: Icon(LucideIcons.warehouse, color: t.color('accent')),
                    title: Text(w.name),
                    subtitle: w.location.isEmpty ? null : Text(w.location),
                    trailing: w.isDefault
                        ? StatusChip(
                            label: s('fields.isDefault'),
                            color: t.color('accent'),
                          )
                        : (w.active
                            ? null
                            : StatusChip(
                                label: s('common.passive'),
                                color: t.color('neutral'),
                              )),
                    onTap: canWrite
                        ? () => _openSheet(context, ref, warehouse: w, all: list)
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WarehouseSheet extends ConsumerStatefulWidget {
  const _WarehouseSheet({required this.initial, required this.all});

  final Warehouse? initial;
  final List<Warehouse> all;

  @override
  ConsumerState<_WarehouseSheet> createState() => _WarehouseSheetState();
}

class _WarehouseSheetState extends ConsumerState<_WarehouseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late bool _isDefault;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    _name = TextEditingController(text: w?.name ?? '');
    _location = TextEditingController(text: w?.location ?? '');
    _isDefault = w?.isDefault ?? false;
    _active = w?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final s = ref.read(stringsProvider);
    final repo = ref.read(warehouseRepositoryProvider);
    final initial = widget.initial;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final draft = Warehouse(
        id: initial?.id ?? '',
        companyId: initial?.companyId ?? '',
        name: _name.text.trim(),
        location: _location.text.trim(),
        isDefault: _isDefault,
        // Varsayilan depo pasif yapilamaz.
        active: _isDefault ? true : _active,
      );
      final synced = initial == null
          ? (await repo.create(draft, widget.all)).synced
          : await repo.update(draft, widget.all);
      if (!mounted) return;
      // Bildirim, alt sayfa hala bagliyken gosterilir (ScaffoldMessenger ustte kalir).
      if (synced) {
        showSuccess(context, ref, s('messages.saved'));
      } else {
        showWarning(context, ref, s('messages.queued'));
      }
      navigator.pop();
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
    final gap = SizedBox(height: t.spacing('lg'));
    final wasDefault = widget.initial?.isDefault ?? false;

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
                widget.initial == null
                    ? s('stock.newWarehouse')
                    : s('stock.editWarehouse'),
                style: TextStyle(
                  fontSize: t.fontSize('title'),
                  fontWeight: t.fontWeight('semibold'),
                ),
              ),
              gap,
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: s('stock.warehouse')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s('validation.required')
                    : null,
              ),
              gap,
              TextFormField(
                controller: _location,
                decoration: InputDecoration(labelText: s('fields.location')),
              ),
              SizedBox(height: t.spacing('sm')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s('fields.isDefault')),
                // Mevcut varsayilan, baska bir depo secilmeden kapatilamaz.
                value: _isDefault,
                onChanged: wasDefault ? null : (v) => setState(() => _isDefault = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s('fields.active')),
                value: _isDefault ? true : _active,
                onChanged: _isDefault ? null : (v) => setState(() => _active = v),
              ),
              gap,
              FilledButton(
                onPressed: _busy ? null : _save,
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
