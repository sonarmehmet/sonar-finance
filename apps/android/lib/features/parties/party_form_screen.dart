import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/party.dart';
import '../../data/repositories/party_repository.dart';

/// Yeni cari / cari duzenle. [partyId] null ise yeni kayit.
class PartyFormScreen extends ConsumerWidget {
  const PartyFormScreen({super.key, this.partyId});

  final String? partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final id = partyId;
    if (id == null) {
      return _PartyForm(title: s('party.newParty'), initial: null);
    }
    final party = ref.watch(partyProvider(id));
    return party.when(
      data: (p) => p == null
          ? Scaffold(appBar: AppBar(), body: const EmptyView())
          : _PartyForm(title: s('party.editParty'), initial: p),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
    );
  }
}

class _PartyForm extends ConsumerStatefulWidget {
  const _PartyForm({required this.title, required this.initial});

  final String title;
  final Party? initial;

  @override
  ConsumerState<_PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends ConsumerState<_PartyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _taxOffice;
  late final TextEditingController _taxNo;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late String _kind; // customer | supplier | both
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _taxOffice = TextEditingController(text: p?.taxOffice ?? '');
    _taxNo = TextEditingController(text: p?.taxNo ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _active = p?.active ?? true;
    if (p == null || (p.isCustomer && !p.isSupplier)) {
      _kind = 'customer';
    } else if (p.isSupplier && !p.isCustomer) {
      _kind = 'supplier';
    } else {
      _kind = 'both';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _taxOffice, _taxNo, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _kinds => switch (_kind) {
        'customer' => ['customer'],
        'supplier' => ['supplier'],
        _ => ['customer', 'supplier'],
      };

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final s = ref.read(stringsProvider);
    final repo = ref.read(partyRepositoryProvider);
    final initial = widget.initial;
    setState(() => _busy = true);
    try {
      final draft = Party(
        id: initial?.id ?? '',
        companyId: initial?.companyId ?? '',
        kinds: _kinds,
        name: _name.text.trim(),
        taxOffice: _taxOffice.text.trim(),
        taxNo: _taxNo.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
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
    final canWrite =
        ref.watch(userProfileProvider).valueOrNull?.can('party.write') ?? false;
    final gap = SizedBox(height: t.spacing('lg'));

    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? s('validation.required') : null;

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
              controller: _name,
              enabled: canWrite,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s('party.name')),
              validator: required,
            ),
            gap,
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s('party.kind'),
                style: TextStyle(color: t.color('textSecondary')),
              ),
            ),
            SizedBox(height: t.spacing('sm')),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'customer', label: Text(s('party.customer'))),
                  ButtonSegment(value: 'supplier', label: Text(s('party.supplier'))),
                  ButtonSegment(value: 'both', label: Text(s('fields.kindBoth'))),
                ],
                selected: {_kind},
                onSelectionChanged:
                    canWrite ? (v) => setState(() => _kind = v.first) : null,
              ),
            ),
            gap,
            TextFormField(
              controller: _phone,
              enabled: canWrite,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: s('party.phone')),
            ),
            gap,
            TextFormField(
              controller: _email,
              enabled: canWrite,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: s('fields.email')),
            ),
            gap,
            TextFormField(
              controller: _taxOffice,
              enabled: canWrite,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s('fields.taxOffice')),
            ),
            gap,
            TextFormField(
              controller: _taxNo,
              enabled: canWrite,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s('fields.taxNo')),
              validator: (v) {
                final x = (v ?? '').trim();
                if (x.isEmpty) return null;
                final ok = RegExp(r'^\d{10,11}$').hasMatch(x);
                return ok ? null : s('validation.invalidTaxNo');
              },
            ),
            gap,
            TextFormField(
              controller: _address,
              enabled: canWrite,
              maxLines: 2,
              decoration: InputDecoration(labelText: s('fields.address')),
            ),
            gap,
            TextFormField(
              controller: _notes,
              enabled: canWrite,
              maxLines: 3,
              decoration: InputDecoration(labelText: s('fields.notes')),
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
