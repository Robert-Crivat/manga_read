import 'dart:convert';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  SharedPreferences? _sharedPrefs;

  Future<void> init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  String get url {
    return _sharedPrefs?.getString('url') ?? "";
  }

  set url(String value) {
    _sharedPrefs?.setString('url', value);
  }

  // Metodo asincrono per salvare l'URL
  Future<bool> setUrl(String value) async {
    return await _sharedPrefs?.setString('url', value) ?? false;
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

  // METODI PER LE PREFERENZE DI LETTURA

  /// Ottiene il modo di visualizzazione preferito (true = ListView, false = PageView)
  bool getReadingMode() {
    return _sharedPrefs?.getBool('isListView') ?? false;
  }

  /// Salva il modo di visualizzazione preferito
  Future<void> setReadingMode(bool isListView) async {
    await _sharedPrefs?.setBool('isListView', isListView);
  }

  /// Ottiene la preferenza di visibilità del bottom panel
  bool getBottomPanelVisibility() {
    return _sharedPrefs?.getBool('showBottomPanel') ?? true;
  }

  /// Salva la preferenza di visibilità del bottom panel
  Future<void> setBottomPanelVisibility(bool showBottomPanel) async {
    await _sharedPrefs?.setBool('showBottomPanel', showBottomPanel);
  }

  // METODI DI UTILITÀ

  /// Verifica se SharedPreferences è inizializzato
  bool get isInitialized => _sharedPrefs != null;

  /// Rimuove tutte le preferenze (per debug/reset)
  Future<void> clearAll() async {
    await _sharedPrefs?.clear();
  }

  // GESTIONE PROFILI SERVER
  
  /// Ottiene tutti i profili server salvati
  Map<String, String> getServerProfiles() {
    final profilesJson = _sharedPrefs?.getString('server_profiles') ?? '{}';
    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        json.decode(profilesJson) as Map
      );
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      // Se c'è un errore, ritorna profili di default
      return {
        'Locale': 'http://192.168.1.100:8000',
        'Remoto': 'http://80.97.160.102:8000',
      };
    }
  }
  
  /// Salva tutti i profili server
  Future<bool> setServerProfiles(Map<String, String> profiles) async {
    final profilesJson = json.encode(profiles);
    return await _sharedPrefs?.setString('server_profiles', profilesJson) ?? false;
  }
  
  /// Ottiene il profilo attualmente attivo
  String getActiveServerProfile() {
    return _sharedPrefs?.getString('active_server_profile') ?? 'Remoto';
  }
  
  /// Imposta il profilo attivo
  Future<bool> setActiveServerProfile(String profileName) async {
    return await _sharedPrefs?.setString('active_server_profile', profileName) ?? false;
  }
  
  /// Ottiene l'URL del server corrente (basato sul profilo attivo)
  String getServerUrl() {
    final profiles = getServerProfiles();
    final activeProfile = getActiveServerProfile();
    
    // Prima prova a ottenere l'URL dal profilo attivo
    if (profiles.containsKey(activeProfile)) {
      return profiles[activeProfile]!;
    }
    
    // Se il profilo attivo non esiste, prova a usare il primo disponibile
    if (profiles.isNotEmpty) {
      return profiles.values.first;
    }
    
    // Se non ci sono profili, restituisce URL di default
    return 'http://80.97.160.102:8000';
  }

  /// Salva l'URL del server (mantenuto per compatibilità)
  Future<bool> setServerUrl(String url) async {
    return await _sharedPrefs?.setString('server_url', url) ?? false;
  }
  
  /// Aggiunge un nuovo profilo server
  Future<bool> addServerProfile(String name, String url) async {
    final profiles = getServerProfiles();
    profiles[name] = url;
    return await setServerProfiles(profiles);
  }
  
  /// Rimuove un profilo server
  Future<bool> removeServerProfile(String name) async {
    final profiles = getServerProfiles();
    if (profiles.length <= 1) return false; // Non eliminare l'ultimo profilo
    
    profiles.remove(name);
    
    // Se il profilo attivo è stato eliminato, seleziona il primo disponibile
    if (getActiveServerProfile() == name) {
      if (profiles.isNotEmpty) {
        await setActiveServerProfile(profiles.keys.first);
      } else {
        // Se non ci sono più profili, crea un profilo predefinito
        profiles['Remoto'] = 'http://80.97.160.102:8000';
        await setActiveServerProfile('Remoto');
      }
    }
    
    return await setServerProfiles(profiles);
  }
  
  /// Modifica un profilo server esistente
  Future<bool> updateServerProfile(String oldName, String newName, String newUrl) async {
    final profiles = getServerProfiles();
    
    // Rimuovi il vecchio profilo
    final oldUrl = profiles.remove(oldName);
    if (oldUrl == null) return false; // Profilo non trovato
    
    // Aggiungi il nuovo profilo
    profiles[newName] = newUrl;
    
    // Se il profilo modificato era quello attivo, aggiorna il riferimento
    if (getActiveServerProfile() == oldName) {
      await setActiveServerProfile(newName);
    }
    
    return await setServerProfiles(profiles);
  }
}