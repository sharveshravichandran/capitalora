import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'calendar_tab.dart';
import 'data.dart';
import 'income_tab.dart';
import 'masters_tab.dart';
import 'ui.dart';

/// Signed-in shell: app bar, progress strip, bottom navigation and the tabs.
class HomePage extends StatefulWidget {
  final User user;
  final bool isAdmin;
  final VoidCallback onOpenAdmin;
  const HomePage({
    super.key,
    required this.user,
    required this.onOpenAdmin,
    this.isAdmin = false,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WealthStore store = WealthStore(widget.user.uid);
  int tab = 0;

  static const _titles = [
    'My Wealth',
    'Expense calendar',
    'Salary & credits',
    'Expense masters',
  ];

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[tab]), actions: [
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'logins') {
              widget.onOpenAdmin();
            } else if (v == 'logout') {
              FirebaseAuth.instance.signOut();
            }
          },
          itemBuilder: (_) => [
            if (widget.isAdmin)
              const PopupMenuItem(
                value: 'logins',
                child: ListTile(
                    leading: Icon(Icons.people), title: Text('Login details')),
              ),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                  leading: Icon(Icons.logout), title: Text('Sign out')),
            ),
          ],
        ),
      ]),
      body: Column(children: [
        ListenableBuilder(
          listenable: store,
          builder: (_, __) =>
              LoadingStrip(loading: store.loading, error: store.error),
        ),
        Expanded(
          child: IndexedStack(index: tab, children: [
            HomeTab(store: store, user: widget.user),
            CalendarTab(store: store),
            IncomeTab(store: store),
            MastersTab(store: store),
          ]),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Income'),
          NavigationDestination(icon: Icon(Icons.category), label: 'Masters'),
        ],
      ),
    );
  }
}

/// Dashboard: banner, yearly totals, monthly bar chart, master-wise pie chart.
class HomeTab extends StatelessWidget {
  final WealthStore store;
  final User user;
  const HomeTab({super.key, required this.store, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final small = Theme.of(context).textTheme.labelSmall;
        final hasMonthly = store.incomeTotal > 0 || store.expenseTotal > 0;
        final hasMasters = store.expenseTotal > 0;

        return ListView(padding: const EdgeInsets.all(16), children: [
          AppImage(
            'assets/images/home_banner.jpg',
            height: 160,
            overlay: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back',
                    style: TextStyle(color: Colors.white70)),
                Text(user.email ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          YearBar(store),
          Row(children: [
            Expanded(
                child: StatTile('Salary', store.salaryTotal, Colors.green,
                    Icons.payments)),
            Expanded(
                child: StatTile('Credits', store.creditTotal, Colors.blue,
                    Icons.account_balance_wallet)),
          ]),
          Row(children: [
            Expanded(
                child: StatTile('Expenses', store.expenseTotal, Colors.red,
                    Icons.shopping_cart)),
            Expanded(
                child: StatTile(
                    'Balance',
                    store.balance,
                    store.balance >= 0 ? Colors.teal : Colors.deepOrange,
                    Icons.savings)),
          ]),
          const SizedBox(height: 8),

          // ---- monthly income vs expenses
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Income vs expenses by month',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(children: const [
                  _Dot(Colors.green),
                  SizedBox(width: 4),
                  Text('Income'),
                  SizedBox(width: 16),
                  _Dot(Colors.redAccent),
                  SizedBox(width: 4),
                  Text('Expenses'),
                ]),
                const SizedBox(height: 16),
                if (!hasMonthly)
                  const SizedBox(
                      height: 120,
                      child: Center(child: Text('No data for this year yet')))
                else
                  SizedBox(
                    height: 220,
                    child: BarChart(BarChartData(
                      barGroups: [
                        for (var m = 1; m <= 12; m++)
                          BarChartGroupData(x: m, barRods: [
                            BarChartRodData(
                                toY: store.monthIncome(m),
                                color: Colors.green,
                                width: 6),
                            BarChartRodData(
                                toY: store.monthExpense[m],
                                color: Colors.redAccent,
                                width: 6),
                          ]),
                      ],
                      gridData:
                          FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (v, meta) =>
                                Text(compactMoney.format(v), style: small),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 1 || i > 12) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(monthNames[i - 1], style: small),
                              );
                            },
                          ),
                        ),
                      ),
                    )),
                  ),
              ]),
            ),
          ),

          // ---- expense master-wise pie
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expenses by master',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (!hasMasters)
                  const SizedBox(
                      height: 120,
                      child: Center(child: Text('No expenses for this year yet')))
                else ...[
                  SizedBox(
                    height: 200,
                    child: PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        for (final t in store.masterTotals)
                          PieChartSectionData(
                            value: t.total,
                            color: t.color,
                            radius: 54,
                            title:
                                '${(t.total / store.expenseTotal * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                      ],
                    )),
                  ),
                  const SizedBox(height: 8),
                  for (final t in store.masterTotals)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: _Dot(t.color),
                      title: Text(t.name),
                      trailing: Text(money.format(t.total),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
