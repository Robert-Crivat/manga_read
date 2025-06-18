import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static SharedPreferences? _sharedPrefs;

  init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }


  List<Map<String, dynamic>> get mangaPreferiti {
    final jsonString = _sharedPrefs!.getString('mangaPreferiti');
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    final List<dynamic> decoded = json.decode(jsonString);
    return decoded.cast<Map<String, dynamic>>();
  }

  set mangaPreferiti(List<Map<String, dynamic>> value) {
    final jsonString = json.encode(value);
    _sharedPrefs!.setString('mangaPreferiti', jsonString);
  }

}
