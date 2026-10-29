import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'data.dart';
import 'forms.dart';
import 'ui.dart';

class CalendarTab extends StatefulWidget {
  final WealthStore store;
  const CalendarTab({super.key, required this.store});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  WealthStore get store => widget.store;

  double _monthTotal(DateTime d) =>
      store.year == d.year ? store.monthExpense[d.month] : 0.0;

  Widget _cell(DateTime day, {bool selected = false, bool today = false}) {
    final cs = Theme.of(context).colorScheme;
    final total = store.expenseByDay[dateKey(day)] ?? 0;
    final onSel = selected ? cs.onPrimary : null;
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: selected
            ? cs.primary
            : today
                ? cs.primaryContainer
                : total > 0
                    ? cs.errorContainer.withAlpha(90)
                    : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: TextStyle(fontWeight: FontWeight.bold, color: onSel)),
          if (total > 0)
            Text(compactMoney.format(total),
                style: TextStyle(
                    fontSize: 10, color: selected ? cs.onPrimary : cs.error)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final key = dateKey(_selected);
        final items = store.expensesOn(key);
        final dayTotal = store.expenseByDay[key] ?? 0;

        return Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              children: [
                Row(children: [
                  Expanded(
                      child: StatTile(
                          '${DateFormat('MMMM').format(_focused)} total',
                          _monthTotal(_focused),
                          Colors.orange,
                          Icons.calendar_month)),
                  Expanded(
                      child: StatTile('${store.year} total',
                          store.expenseTotal, Colors.red, Icons.summarize)),
                ]),
                TableCalendar(
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focused,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  rowHeight: 58,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  onDaySelected: (sel, foc) => setState(() {
                    _selected = sel;
                    _focused = foc;
                  }),
                  onPageChanged: (f) {
                    setState(() => _focused = f);
                    if (f.year != store.year) store.setYear(f.year);
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    // Month total right in the calendar header.
                    titleTextFormatter: (date, locale) =>
                        '${DateFormat('MMMM yyyy').format(date)} · ${compactMoney.format(_monthTotal(date))}',
                  ),
                  calendarStyle: const CalendarStyle(outsideDaysVisible: false),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (c, day, f) => _cell(day),
                    todayBuilder: (c, day, f) => _cell(day, today: true),
                    selectedBuilder: (c, day, f) => _cell(day, selected: true),
                  ),
                ),
                const Divider(),
                Row(children: [
                  Expanded(
                    child: Text(DateFormat('EEE, dd MMM yyyy').format(_selected),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  FilledButton.icon(
                    onPressed: () => showExpenseSheet(context, store, _selected),
                    icon: const Icon(Icons.add),
                    label: const Text('Add expense'),
                  ),
                ]),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No expenses on this day')),
                  ),
                for (final e in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: store.colorOf(e.masterId),
                      child: const Icon(Icons.receipt_long,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(e.masterName),
                    subtitle: e.note.isEmpty ? null : Text(e.note),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(money.format(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDelete(context, 'this expense')) {
                            store.deleteExpense(e.id);
                          }
                        },
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          // Day total, pinned at the bottom of the list.
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Day total',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(money.format(dayTotal),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
