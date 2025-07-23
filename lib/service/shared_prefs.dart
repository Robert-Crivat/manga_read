import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  SharedPreferences? _sharedPrefs;

  Future<void> init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

   String get url {
    return _sharedPrefs!.getString('url') ?? "";
  }

  set url(String value) {
    _sharedPrefs!.setString('url', value);
  }

  // GETTER - Restituiscono copie delle liste salvate
  List<String> get mangaPref {
    return _sharedPrefs?.getStringList('mangaPref') ?? [];
  }

  List<String> get mangaPrefurlImg {
    return _sharedPrefs?.getStringList('mangaPrefurlImg') ?? [];
  }

  List<String> get mangaPrefurl {
    return _sharedPrefs?.getStringList('mangaPrefurl') ?? [];
  }

  // METODI ASYNC PER GESTIRE I PREFERITI CORRETTAMENTE

  /// Aggiunge un manga ai preferiti
  Future<bool> addMangaToFavorites({
    required String title,
    required String url,
    required String imgUrl,
  }) async {
    try {
      // Ottieni le liste attuali
      List<String> titles = mangaPref;
      List<String> urls = mangaPrefurl;
      List<String> images = mangaPrefurlImg;

      // Controlla se già esiste (evita duplicati)
      if (urls.contains(url)) {
        return false; // Già presente
      }

      // Aggiungi i nuovi elementi
      titles.add(title);
      urls.add(url);
      images.add(imgUrl);

      // Salva nelle SharedPreferences
      await _sharedPrefs?.setStringList('mangaPref', titles);
      await _sharedPrefs?.setStringList('mangaPrefurl', urls);
      await _sharedPrefs?.setStringList('mangaPrefurlImg', images);

      return true; // Successo
    } catch (e) {
      print('Errore nell\'aggiungere ai preferiti: $e');
      return false;
    }
  }

  /// Rimuove un manga dai preferiti
  Future<bool> removeMangaFromFavorites({required String url}) async {
    try {
      // Ottieni le liste attuali
      List<String> titles = mangaPref;
      List<String> urls = mangaPrefurl;
      List<String> images = mangaPrefurlImg;

      // Trova l'indice dell'elemento da rimuovere
      int index = urls.indexOf(url);
      if (index == -1) {
        return false; // Non trovato
      }

      // Rimuovi gli elementi alle stesse posizioni
      titles.removeAt(index);
      urls.removeAt(index);
      images.removeAt(index);

      // Salva nelle SharedPreferences
      await _sharedPrefs?.setStringList('mangaPref', titles);
      await _sharedPrefs?.setStringList('mangaPrefurl', urls);
      await _sharedPrefs?.setStringList('mangaPrefurlImg', images);

      return true; // Successo
    } catch (e) {
      print('Errore nel rimuovere dai preferiti: $e');
      return false;
    }
  }

  /// Controlla se un manga è nei preferiti
  bool isMangaInFavorites(String url) {
    return mangaPrefurl.contains(url);
  }

  /// Ottieni tutti i manga preferiti come oggetti strutturati
  List<MangaSearchModel> getAllFavorites() {
    List<String> titles = mangaPref;
    List<String> urls = mangaPrefurl;
    List<String> images = mangaPrefurlImg;

    List<MangaSearchModel> favorites = [];

    // Assicurati che tutte le liste abbiano la stessa lunghezza
    int minLength = [
      titles.length,
      urls.length,
      images.length,
    ].reduce((a, b) => a < b ? a : b);

    for (int i = 0; i < minLength; i++) {
      favorites.add(
        MangaSearchModel(
          title: titles[i],
          url: urls[i],
          img: images[i],
          story: "",
          status: "",
          type: "",
          genres: "",
          author: "",
          artist: "",
        ),
      );
    }

    return favorites;
  }

  /// Pulisce tutti i preferiti
  Future<bool> clearAllFavorites() async {
    try {
      await _sharedPrefs?.setStringList('mangaPref', []);
      await _sharedPrefs?.setStringList('mangaPrefurl', []);
      await _sharedPrefs?.setStringList('mangaPrefurlImg', []);
      return true;
    } catch (e) {
      print('Errore nel pulire i preferiti: $e');
      return false;
    }
  }

  /// Conta il numero di preferiti
  int getFavoritesCount() {
    return mangaPrefurl.length;
  }

  // METODI PER IL TEMA (già corretti)
  Future<bool> getDarkMode() async {
    return _sharedPrefs?.getBool('darkMode') ?? true;
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    await _sharedPrefs?.setBool('darkMode', isDarkMode);
  }

  // METODI DI UTILITÀ

  /// Verifica se SharedPreferences è inizializzato
  bool get isInitialized => _sharedPrefs != null;

  /// Rimuove tutte le preferenze (per debug/reset)
  Future<void> clearAll() async {
    await _sharedPrefs?.clear();
  }
}