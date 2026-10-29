import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Change the symbol here if you don't want rupees.
final NumberFormat money =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final NumberFormat compactMoney = NumberFormat.compact(locale: 'en_IN');

const monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

const masterPalette = <int>[
  0xFF009688, 0xFFE91E63, 0xFF3F51B5, 0xFFFF9800, 0xFF9C27B0,
  0xFF4CAF50, 0xFFF44336, 0xFF00BCD4, 0xFF795548, 0xFF607D8B,
];

const defaultMasterNames = [
  'Rent', 'Groceries', 'Transport', 'Utilities', 'EMI / Loans',
  'Health', 'Eating out', 'Shopping', 'Entertainment', 'Other',
];

double _d(dynamic v) => v is num ? v.toDouble() : 0.0;
// Documents still being written have no server timestamp yet: sort them last.
int _t(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : 9000000000000000;

class Master {
  final String id, name;
  final int color;
  const Master(this.id, this.name, this.color);
  Color get c => Color(color);
  factory Master.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Master(d.id, (m['name'] ?? '') as String,
        (m['color'] as num?)?.toInt() ?? masterPalette[0]);
  }
}

class Expense {
  final String id, dateKey, masterId, masterName, note;
  final double amount;
  final int created;
  const Expense(this.id, this.dateKey, this.masterId, this.masterName,
      this.note, this.amount, this.created);
  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Expense(
        d.id,
        (m['dateKey'] ?? '') as String,
        (m['masterId'] ?? '') as String,
        (m['masterName'] ?? '') as String,
        (m['note'] ?? '') as String,
        _d(m['amount']),
        _t(m['createdAt']));
  }
}

class Income {
  final String id, dateKey, type, note; // type: 'salary' or 'credit'
  final double amount;
  const Income(this.id, this.dateKey, this.type, this.note, this.amount);
  factory Income.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Income(d.id, (m['dateKey'] ?? '') as String,
        (m['type'] ?? 'credit') as String, (m['note'] ?? '') as String,
        _d(m['amount']));
  }
}

class MasterTotal {
  final String id, name;
  final Color color;
  final double total;
  const MasterTotal(this.id, this.name, this.color, this.total);
}

/// Live data for one signed-in user and one selected year.
/// Everything lives under users/{uid}/masters | expenses | incomes.
class WealthStore extends ChangeNotifier {
  WealthStore(this.uid) {
    _u = FirebaseFirestore.instance.collection('users').doc(uid);
    _listenMasters();
    _listenYear();
  }

  final String uid;
  late final DocumentReference<Map<String, dynamic>> _u;

  int year = DateTime.now().year;
  List<Master> masters = const [];
  List<Expense> expenses = const [];
  List<Income> incomes = const [];
  String? error;

  bool _m = false, _e = false, _i = false;
  StreamSubscription<dynamic>? _subM, _subE, _subI;

  // Aggregates, rebuilt on every change.
  Map<String, double> expenseByDay = {};
  List<double> monthExpense = List<double>.filled(13, 0);
  List<double> monthSalary = List<double>.filled(13, 0);
  List<double> monthCredit = List<double>.filled(13, 0);
  Map<String, double> _masterSums = {};
  List<MasterTotal> masterTotals = [];
  double expenseTotal = 0, salaryTotal = 0, creditTotal = 0;

  bool get loading => !(_m && _e && _i);
  double get incomeTotal => salaryTotal + creditTotal;
  double get balance => incomeTotal - expenseTotal;
  double monthIncome(int m) => monthSalary[m] + monthCredit[m];
  double masterTotal(String id) => _masterSums[id] ?? 0;

  List<Expense> expensesOn(String key) {
    final list = expenses.where((e) => e.dateKey == key).toList()
      ..sort((a, b) => a.created.compareTo(b.created));
    return list;
  }

  Color colorOf(String masterId) {
    for (final m in masters) {
      if (m.id == masterId) return m.c;
    }
    return Colors.grey;
  }

  void _onError(Object e) {
    error = e.toString();
    notifyListeners();
  }

  void _listenMasters() {
    _subM = _u.collection('masters').orderBy('name').snapshots().listen((s) {
      masters = s.docs.map(Master.fromDoc).toList();
      _m = true;
      error = null;
      _recompute();
    }, onError: _onError);
  }

  void _listenYear() {
    _subE?.cancel();
    _subI?.cancel();
    final lo = '$year-01-01', hi = '$year-12-31';
    _subE = _u
        .collection('expenses')
        .where('dateKey', isGreaterThanOrEqualTo: lo)
        .where('dateKey', isLessThanOrEqualTo: hi)
        .snapshots()
        .listen((s) {
      expenses = s.docs.map(Expense.fromDoc).toList();
      _e = true;
      error = null;
      _recompute();
    }, onError: _onError);
    _subI = _u
        .collection('incomes')
        .where('dateKey', isGreaterThanOrEqualTo: lo)
        .where('dateKey', isLessThanOrEqualTo: hi)
        .snapshots()
        .listen((s) {
      incomes = s.docs.map(Income.fromDoc).toList();
      _i = true;
      error = null;
      _recompute();
    }, onError: _onError);
  }

  void setYear(int y) {
    if (y == year) return;
    year = y;
    _e = false;
    _i = false;
    expenses = const [];
    incomes = const [];
    _listenYear();
    _recompute();
  }

  int _month(String key) {
    final v = int.tryParse(key.length >= 7 ? key.substring(5, 7) : '') ?? 1;
    return v < 1 ? 1 : (v > 12 ? 12 : v);
  }

  void _recompute() {
    final byDay = <String, double>{};
    final mExp = List<double>.filled(13, 0);
    final mSal = List<double>.filled(13, 0);
    final mCr = List<double>.filled(13, 0);
    final sums = <String, double>{};
    final names = <String, String>{};
    var exp = 0.0, sal = 0.0, cr = 0.0;

    for (final e in expenses) {
      byDay[e.dateKey] = (byDay[e.dateKey] ?? 0) + e.amount;
      mExp[_month(e.dateKey)] += e.amount;
      exp += e.amount;
      sums[e.masterId] = (sums[e.masterId] ?? 0) + e.amount;
      names[e.masterId] = e.masterName;
    }
    for (final i in incomes) {
      final mo = _month(i.dateKey);
      if (i.type == 'salary') {
        mSal[mo] += i.amount;
        sal += i.amount;
      } else {
        mCr[mo] += i.amount;
        cr += i.amount;
      }
    }

    final colors = {for (final m in masters) m.id: m.c};
    expenseByDay = byDay;
    monthExpense = mExp;
    monthSalary = mSal;
    monthCredit = mCr;
    expenseTotal = exp;
    salaryTotal = sal;
    creditTotal = cr;
    _masterSums = sums;
    masterTotals = sums.entries
        .map((x) => MasterTotal(
            x.key, names[x.key] ?? '?', colors[x.key] ?? Colors.grey, x.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    notifyListeners();
  }

  // ---- writes ----

  Future<void> addExpense({
    required DateTime date,
    required Master master,
    required double amount,
    required String note,
  }) {
    if (date.year != year) setYear(date.year);
    return _u.collection('expenses').add({
      'dateKey': dateKey(date),
      'masterId': master.id,
      'masterName': master.name,
      'amount': amount,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String id) =>
      _u.collection('expenses').doc(id).delete();

  Future<void> addIncome({
    required String type,
    required DateTime date,
    required double amount,
    required String note,
  }) {
    if (date.year != year) setYear(date.year);
    return _u.collection('incomes').add({
      'dateKey': dateKey(date),
      'type': type,
      'amount': amount,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteIncome(String id) =>
      _u.collection('incomes').doc(id).delete();

  Future<void> addMaster(String name, int color) =>
      _u.collection('masters').add({
        'name': name,
        'color': color,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteMaster(String id) =>
      _u.collection('masters').doc(id).delete();

  Future<void> addDefaultMasters() async {
    final b = FirebaseFirestore.instance.batch();
    for (var i = 0; i < defaultMasterNames.length; i++) {
      b.set(_u.collection('masters').doc(), {
        'name': defaultMasterNames[i],
        'color': masterPalette[i % masterPalette.length],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await b.commit();
  }

  @override
  void dispose() {
    _subM?.cancel();
    _subE?.cancel();
    _subI?.cancel();
    super.dispose();
  }
}
