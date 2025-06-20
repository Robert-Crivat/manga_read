import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  SharedPreferences? _sharedPrefs;

  Future<void> init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  List<String> get mangaPref {
    return _sharedPrefs?.getStringList('mangaPref') ?? [];
  }

  set mangaPref(List<String> value) {
    _sharedPrefs?.setStringList('mangaPref', value);
  }

  List<String> get mangaPrefurlImg {
    return _sharedPrefs?.getStringList('mangaPrefurlImg') ?? [];
  }

  set mangaPrefurlImg(List<String> value) {
    _sharedPrefs?.setStringList('mangaPrefurlImg', value);
  }

  List<String> get mangaPrefurl {
    return _sharedPrefs?.getStringList('mangaPrefurl') ?? [];
  }

  set mangaPrefurl(List<String> value) {
    _sharedPrefs?.setStringList('mangaPrefurl', value);
  }

  // Metodo per ottenere la preferenza del tema scuro
  Future<bool> getDarkMode() async {
    return _sharedPrefs?.getBool('darkMode') ??
        true; // Predefinito a true per tema scuro
  }

  // Metodo per impostare la preferenza del tema scuro
  Future<void> setDarkMode(bool isDarkMode) async {
    await _sharedPrefs?.setBool('darkMode', isDarkMode);
  }
}
