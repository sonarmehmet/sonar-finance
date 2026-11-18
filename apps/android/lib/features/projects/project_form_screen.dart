import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/date_field.dart';
import '../../data/models/party.dart';
import '../../data/models/project.dart';
import '../../data/repositories/party_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../invoices/line_editor_sheet.dart' show pickParty;

/// Proje olustur / duzenle: sozlesme + disiplin butceleri (KDV haric).
class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});
  final String? projectId;
  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _contract = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, TextEditingController> _budget = {};
  String _partyId = '';
  String _partyName = '';
  String _start = '';
  String _end = '';
  String _status = 'active';
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _location, _contract, _notes, ..._budget.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _b(String d) => _budget.putIfAbsent(d, () => TextEditingController());

  Future<void> _load(Project p) async {
    _loaded = true;
    _name.text = p.name;
    _location.text = p.location;
    _contract.text = p.contractMinor == 0 ? '' : formatMinor(p.contractMinor);
    _notes.text = p.notes;
    _partyId = p.partyId;
    _start = p.startDate;
    _end = p.endDate;
    _status = p.status;
    for (final e in p.budgets.entries) {
      _b(e.key).text = e.value == 0 ? '' : formatMinor(e.value);
    }
    if (p.partyId.isNotEmpty) {
      final party = await ref.read(partyProvider(p.partyId).future);
      if (mounted && party != null) setState(() => _partyName = party.name);
    }
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    if (_name.text.trim().isEmpty) {
      showError(context, ref, s('validation.required'));
      return;
    }
    final budgets = <String, int>{
      for (final e in _budget.entries)
        if ((parseMinor(e.value.text) ?? 0) > 0) e.key: parseMinor(e.value.text)!,
    };
    setState(() => _busy = true);
    try {
      await ref.read(projectRepositoryProvider).save(Project(
            id: widget.projectId ?? '',
            name: _name.text.trim(),
            partyId: _partyId,
            location: _location.text.trim(),
            startDate: _start,
            endDate: _end,
            contractMinor: parseMinor(_contract.text) ?? 0,
            status: _status,
            budgets: budgets,
            notes: _notes.text.trim(),
          ));
      if (!mounted) return;
      showSuccess(context, ref, s('project.saved'));
      context.pop();
    } catch (e) {
      if (mounted) showError(context, ref, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final c = ref.watch(constantsProvider);
    if (widget.projectId != null && !_loaded) {
      final p = ref.watch(projectProvider(widget.projectId!)).valueOrNull;
      if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      _load(p);
    }
    final gap = SizedBox(height: t.spacing('md'));
    return Scaffold(
      appBar: AppBar(title: Text(s(widget.projectId == null ? 'project.new' : 'project.edit'))),
      body: ListView(padding: EdgeInsets.all(t.screenPadding), children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: s('project.name'))),
        gap,
        Card(
          child: ListTile(
            title: Text(_partyName.isEmpty ? s('project.customer') : _partyName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final Party? p = await pickParty(context);
              if (p != null) setState(() {
                _partyId = p.id;
                _partyName = p.name;
              });
            },
          ),
        ),
        gap,
        TextField(controller: _location, decoration: InputDecoration(labelText: s('project.location'))),
        gap,
        DateField(label: s('project.startDate'), value: _start, onChanged: (v) => setState(() => _start = v)),
        gap,
        DateField(label: s('project.endDate'), value: _end, onChanged: (v) => setState(() => _end = v)),
        gap,
        TextField(
          controller: _contract,
          keyboardType: moneyKeyboard,
          inputFormatters: moneyInputFormatters,
          decoration: InputDecoration(labelText: s('project.contract')),
        ),
        gap,
        DropdownButtonFormField<String>(
          value: _status,
          items: [
            for (final k in const ['active', 'done', 'paused'])
              DropdownMenuItem(value: k, child: Text(s('project.status.$k'))),
          ],
          decoration: InputDecoration(labelText: s('project.status')),
          onChanged: (v) => setState(() => _status = v ?? 'active'),
        ),
        gap,
        Text(s('project.budgets'), style: TextStyle(fontWeight: t.fontWeight('semibold'))),
        for (final d in c.disciplines) ...[
          gap,
          TextField(
            controller: _b(d),
            keyboardType: moneyKeyboard,
            inputFormatters: moneyInputFormatters,
            decoration: InputDecoration(labelText: s('disciplines.$d')),
          ),
        ],
        gap,
        TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: s('project.notes'))),
        SizedBox(height: t.spacing('lg')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(t.minTouchTarget)),
          child: Text(s('common.save')),
        ),
      ]),
    );
  }
}
