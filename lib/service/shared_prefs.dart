import 'dart:convert';
import 'package:manga_read/model/manga_search_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  SharedPreferences? _sharedPrefs;

  Future<void> init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  List<MangaSearchModel> get mangaPref {
    final List<String>? storedList = _sharedPrefs?.getStringList('mangaPref');
    if (storedList == null) return [];
    return storedList
        .map(
          (item) => MangaSearchModel.fromJson(json.decode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  set mangaPref(List<MangaSearchModel> value) {
    final List<String> stringList = value
        .map((item) => json.encode(item))
        .toList();
    _sharedPrefs?.setStringList('mangaPref', stringList);
  }
}
