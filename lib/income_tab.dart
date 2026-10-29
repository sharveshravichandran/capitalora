import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'forms.dart';
import 'ui.dart';

/// Two tabs: Salary and Credits.
class IncomeTab extends StatelessWidget {
  final WealthStore store;
  const IncomeTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Salary'), Tab(text: 'Credits')]),
        Expanded(
          child: TabBarView(children: [
            _IncomeList(store: store, type: 'salary'),
            _IncomeList(store: store, type: 'credit'),
          ]),
        ),
      ]),
    );
  }
}

class _IncomeList extends StatelessWidget {
  final WealthStore store;
  final String type;
  const _IncomeList({required this.store, required this.type});

  @override
  Widget build(BuildContext context) {
    final salary = type == 'salary';
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.incomes.where((i) => i.type == type).toList()
          ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
        final total = items.fold<double>(0, (s, i) => s + i.amount);

        return ListView(padding: const EdgeInsets.all(16), children: [
          YearBar(store),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${store.year} ${salary ? 'salary' : 'credits'}'),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(money.format(total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                            ),
                          ]),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => showIncomeSheet(context, store, type),
                      icon: const Icon(Icons.add),
                      label: Text(salary ? 'Add salary' : 'Add credit'),
                    ),
                  ]),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Nothing added for ${store.year}')),
            ),
          for (final i in items)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(salary ? Icons.payments : Icons.account_balance_wallet),
                ),
                title: Text(money.format(i.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${DateFormat('dd MMM yyyy').format(DateTime.parse(i.dateKey))}${i.note.isEmpty ? '' : ' · ${i.note}'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDelete(
                        context, salary ? 'this salary entry' : 'this credit')) {
                      store.deleteIncome(i.id);
                    }
                  },
                ),
              ),
            ),
        ]);
      },
    );
  }
}
