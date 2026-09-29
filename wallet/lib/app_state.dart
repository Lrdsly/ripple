import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/models.dart';
import 'data/sources/demo_source.dart';
import 'data/sources/markdown_source.dart';
import 'data/sources/payment_source.dart';
import 'domain/analytics.dart';

class AppState extends ChangeNotifier {
  List<Payment> payments = [];
  List<FixedExpense> fixed = [];
  String? folder;
  int weekOffset = 0;
  bool loading = true;
  String? error;
  late SharedPreferences _p;

  Analytics get analytics => Analytics(payments);
  PaymentSource get _source =>
      folder == null ? DemoSource() : MarkdownSource(folder!);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    folder = _p.getString('folder');
    fixed = (_p.getStringList('fixed') ?? [])
        .map((s) => FixedExpense.fromJson(jsonDecode(s)))
        .toList();
    await reload();
  }

  Future<void> reload() async {
    loading = true;
    notifyListeners();
    try {
      payments = await _source.load();
      error = null;
    } catch (e) {
      payments = [];
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setFolder(String? path) async {
    folder = path;
    path == null ? await _p.remove('folder') : await _p.setString('folder', path);
    await reload();
  }

  void shiftWeek(int d) {
    weekOffset += d;
    notifyListeners();
  }

  Future<void> _saveFixed() async {
    await _p.setStringList('fixed', fixed.map((f) => jsonEncode(f.toJson())).toList());
    notifyListeners();
  }

  Future<void> addFixed(FixedExpense f) async {
    fixed = [...fixed, f];
    await _saveFixed();
  }

  Future<void> removeFixed(String id) async {
    fixed = fixed.where((f) => f.id != id).toList();
    await _saveFixed();
  }
}
