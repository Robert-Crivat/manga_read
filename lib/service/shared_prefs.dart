import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  SharedPreferences? _sharedPrefs;

  Future<void> init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  List<Map<String, dynamic>> get mangaPref {
    final List<String>? storedList = _sharedPrefs?.getStringList('mangaPref');
    if (storedList == null) return [];
    return storedList
        .map((item) => Map<String, dynamic>.from(json.decode(item)))
        .toList();
  }

  set mangaPref(List<Map<String, dynamic>> value) {
    final List<String> stringList =
        value.map((item) => json.encode(item)).toList();
    _sharedPrefs?.setStringList('mangaPref', stringList);
  }
}
