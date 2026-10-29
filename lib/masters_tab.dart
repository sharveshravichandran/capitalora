import 'package:flutter/material.dart';

import 'data.dart';
import 'forms.dart';
import 'ui.dart';

/// Expense masters (categories) with their total for the selected year.
class MastersTab extends StatelessWidget {
  final WealthStore store;
  const MastersTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          YearBar(store),
          Row(children: [
            Expanded(
                child: StatTile('${store.year} expenses', store.expenseTotal,
                    Colors.red, Icons.summarize)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showMasterDialog(context, store),
                icon: const Icon(Icons.add),
                label: const Text('Add master'),
              ),
            ),
            if (store.masters.isEmpty && !store.loading) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: store.addDefaultMasters,
                  child: const Text('Add common masters'),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          if (store.masters.isEmpty && !store.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No masters yet. Add your own or the common set.')),
            ),
          for (final m in store.masters)
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: m.c, radius: 14),
                title: Text(m.name),
                subtitle: const Text('Year total'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money.format(store.masterTotal(m.id)),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirmDelete(context, 'master "${m.name}"')) {
                        store.deleteMaster(m.id);
                      }
                    },
                  ),
                ]),
              ),
            ),
          if (store.masters.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Deleting a master keeps its past expenses; they keep the old name.',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ]);
      },
    );
  }
}
