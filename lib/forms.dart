import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data.dart';

// ---------------------------------------------------------------- expense

Future<void> showExpenseSheet(
        BuildContext context, WealthStore store, DateTime date) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ExpenseForm(store: store, date: date),
      ),
    );

class _ExpenseForm extends StatefulWidget {
  final WealthStore store;
  final DateTime date;
  const _ExpenseForm({required this.store, required this.date});
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Master? _master;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (_master == null) {
      setState(() => _error = 'Pick an expense master');
      return;
    }
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.addExpense(
          date: widget.date,
          master: _master!,
          amount: amt,
          note: _note.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masters = widget.store.masters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Add expense · ${DateFormat('EEE, dd MMM yyyy').format(widget.date)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (masters.isEmpty)
              const Text(
                  'No expense masters yet. Add some in the Masters tab first.')
            else
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final m in masters)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: m.c, radius: 6),
                    label: Text(m.name),
                    selected: _master?.id == m.id,
                    onSelected: (_) => setState(() => _master = m),
                  ),
              ]),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _busy || masters.isEmpty ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save expense')),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- income

/// [type] is 'salary' or 'credit'.
Future<void> showIncomeSheet(
        BuildContext context, WealthStore store, String type) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _IncomeForm(store: store, type: type),
      ),
    );

class _IncomeForm extends StatefulWidget {
  final WealthStore store;
  final String type;
  const _IncomeForm({required this.store, required this.type});
  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.addIncome(
          type: widget.type,
          date: _date,
          amount: amt,
          note: _note.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salary = widget.type == 'salary';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(salary ? 'Add salary' : 'Add credit',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('dd MMM yyyy').format(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pick,
            ),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                  labelText: salary
                      ? 'Note (e.g. employer, month)'
                      : 'Note (e.g. source)',
                  border: const OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- master

Future<void> showMasterDialog(BuildContext context, WealthStore store) =>
    showDialog<void>(
        context: context, builder: (_) => _MasterDialog(store: store));

class _MasterDialog extends StatefulWidget {
  final WealthStore store;
  const _MasterDialog({required this.store});
  @override
  State<_MasterDialog> createState() => _MasterDialogState();
}

class _MasterDialogState extends State<_MasterDialog> {
  final _name = TextEditingController();
  int _color = masterPalette[0];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.addMaster(name, _color);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New expense master'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name (e.g. Rent)'),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in masterPalette)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(c),
                  child: _color == c
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Add')),
      ],
    );
  }
}
