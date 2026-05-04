import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:widget_zoom/widget_zoom.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

class LetturaScreenManga extends StatefulWidget {
  // Parametri per modalità online
  final MangaSearchModel? manga;
  final ChapterModel? capitolo;
  final List<ChapterModel>? allChapters;
  
  // Parametri per modalità offline
  final String? offlineMangaName;
  final String? offlineChapterName;
  
  // Modalità di funzionamento
  final bool isOfflineMode;

  const LetturaScreenManga({
      Key? key,
      // Online parameters
      this.manga,
      this.capitolo,
      this.allChapters,
      // Offline parameters
      this.offlineMangaName,
      this.offlineChapterName,
      // Mode
      this.isOfflineMode = false,
      }) : super(key: key);

  @override
  State<LetturaScreenManga> createState() => _LetturaScreenMangaState();
}

class _LetturaScreenMangaState extends State<LetturaScreenManga>
    with SingleTickerProviderStateMixin {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  List<String> capitoliList = [];
  List<Map<String, dynamic>> imagesBase64 = []; // Dati base64 delle immagini
  Map<int, ImageProvider> imageCache = {}; // Cache delle immagini precaricate
  List<ChapterModel> allChapters = [];
  
  // Variabili per modalità offline
  List<File> offlineImages = [];
  List<String> availableOfflineChapters = [];
  List<String> offlineChapters = []; // Lista dei capitoli offline disponibili
  String? currentOfflineChapter;
  bool isConnected = true;
  
  bool isLoading = false;
  bool isLoadingChapters = false;
  int currentPage = 0;
  bool showControls = true;
  bool isListView = false; // Switch tra PageView e ListView
  bool showBottomPanel = true; // Controllo visibilità bottom panel
  bool allImagesLoaded = false; // Tracking precaricamento immagini
  int loadedImagesCount = 0; // Contatore immagini caricate
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );
    _controlsAnimationController.forward();
    _loadPreferences();
    _checkConnectivity();
    _initializeContent();
    
    // Non serve più setup di precaricamento scroll - tutte le immagini sono già precaricate
    
    // Timeout di sicurezza per evitare caricamento infinito
    Timer(const Duration(seconds: 10), () {
      if (mounted && isLoading) {
        print('DEBUG: Timeout inizializzazione - forzo stop loading');
        setState(() {
          isLoading = false;
        });
      }
    });
  }
  
  Future<void> _checkConnectivity() async {
    try {
      print('DEBUG: Tentativo controllo connettività...');
      final connectivityResult = await Connectivity().checkConnectivity();
      print('DEBUG: Controllo connettività completato: $connectivityResult');
      
      setState(() {
        isConnected = connectivityResult.isNotEmpty && connectivityResult.first != ConnectivityResult.none;
      });
      
      print('DEBUG: Stato connessione impostato: $isConnected');
      
      // Listener per cambiamenti di connettività
      Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        print('DEBUG: Cambio connettività rilevato: $results');
        setState(() {
          isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
        });
      });
    } catch (e) {
      print('DEBUG: Plugin connectivity_plus non disponibile: $e');
      // Fallback: assume connessione disponibile
      setState(() {
        isConnected = true;
      });
      print('DEBUG: Fallback attivato - connessione assunta come disponibile: $isConnected');
    }
  }
  
  void _initializeContent() {
    print('DEBUG: Inizializzazione contenuto...');
    print('DEBUG: widget.isOfflineMode: ${widget.isOfflineMode}');
    print('DEBUG: widget.offlineMangaName: ${widget.offlineMangaName}');
    print('DEBUG: widget.offlineChapterName: ${widget.offlineChapterName}');
    print('DEBUG: widget.manga: ${widget.manga}');
    print('DEBUG: widget.capitolo: ${widget.capitolo}');
    print('DEBUG: isConnected: $isConnected');
    
    // Se specificatamente in modalità offline o parametri offline forniti, usa modalità offline
    if (widget.isOfflineMode || (widget.offlineMangaName != null && widget.offlineChapterName != null)) {
      print('DEBUG: Caricamento modalità OFFLINE (parametri espliciti)');
      currentOfflineChapter = widget.offlineChapterName;
      _loadOfflineContent();
    } else if (!isConnected && widget.offlineMangaName != null && widget.offlineChapterName != null) {
      // Fallback a offline se disconnesso ma dati offline disponibili
      print('DEBUG: Caricamento modalità OFFLINE (fallback per disconnessione)');
      currentOfflineChapter = widget.offlineChapterName;
      _loadOfflineContent();
    } else if (widget.manga != null && widget.capitolo != null) {
      // Modalità online
      print('DEBUG: Caricamento modalità ONLINE');
      allChapters = widget.allChapters ?? [];
      getChaptersImg();
    } else {
      // Nessun dato valido
      print('DEBUG: Nessun dato valido per inizializzazione');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Carica le preferenze salvate
  void _loadPreferences() {
    // Verifica che SharedPrefs sia inizializzato
    if (sharedPrefs.isInitialized) {
      final savedListView = sharedPrefs.getReadingMode();
      final savedBottomPanel = sharedPrefs.getBottomPanelVisibility();

      print(
          'DEBUG: Caricamento preferenze - isListView: $savedListView, showBottomPanel: $savedBottomPanel');

      setState(() {
        isListView = savedListView;
        showBottomPanel = savedBottomPanel;
      });
    } else {
      print('DEBUG: SharedPrefs non ancora inizializzato');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _controlsAnimationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      showControls = !showControls;
      if (showControls) {
        _controlsAnimationController.forward();
      } else {
        _controlsAnimationController.reverse();
      }
    });
  }

  getChaptersImg() async {
    if (!mounted) return;
    
    // Pulisci la cache del capitolo precedente
    imageCache.clear();
    
    setState(() {
      isLoading = true;
      allImagesLoaded = false;
      loadedImagesCount = 0;
    });
    try {
      // Chiamata al nuovo endpoint con base64
      if (widget.capitolo?.url != null) {
        var results = await mangaWorldApi.getChapterPagesWithBase64(widget.capitolo!.url);
        if (!mounted) return;

        print('DEBUG: Risposta API ricevuta');
        print('DEBUG: results.status: ${results.status}');
        print('DEBUG: results.parametri type: ${results.parametri.runtimeType}');
        print('DEBUG: results.data type: ${results.data.runtimeType}');

        // Prima estrai i dati
        if (results.parametri != null) {
          capitoliList = results.parametri.cast<String>();
        }
        
        // Gestisci i dati base64 se disponibili
        bool hasBase64 = false;
        try {
          if (results.data != null && results.data is Map) {
            print('DEBUG: results.data keys: ${results.data.keys}');
            if (results.data['images_base64'] != null) {
              print('DEBUG: images_base64 found, type: ${results.data['images_base64'].runtimeType}');
              var base64List = results.data['images_base64'];
              if (base64List is List) {
                imagesBase64 = List<Map<String, dynamic>>.from(base64List);
                hasBase64 = true;
                print('DEBUG: Successfully extracted ${imagesBase64.length} base64 images');
              }
            }
          }
        } catch (e) {
          print('DEBUG: Error processing base64 data: $e');
          hasBase64 = false;
        }

        // Aggiorna lo stato
        setState(() {
          // I dati sono già stati estratti sopra
        });

        // Precarica TUTTE le immagini prima di permettere visualizzazione
        if (hasBase64) {
          await _preloadAllBase64Images();
          if (mounted) {
            setState(() {
              loadedImagesCount = imagesBase64.length;
              allImagesLoaded = true;
              isLoading = false;
            });
          }
        } else {
          // Fallback al precaricamento completo tradizionale
          await _preloadAllNetworkImages();
          if (mounted) {
            setState(() {
              loadedImagesCount = capitoliList.length;
              allImagesLoaded = true;
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error searching manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
        setState(() {
          isLoading = false;
          allImagesLoaded = false;
        });
      }
    }
  }

  Future<void> _loadOfflineContent() async {
    print('DEBUG: _loadOfflineContent chiamato');
    
    if (widget.offlineMangaName == null || currentOfflineChapter == null) {
      print('DEBUG: Parametri offline mancanti in _loadOfflineContent');
      setState(() {
        isLoading = false;
      });
      return;
    }
    
    setState(() {
      isLoading = true;
      allImagesLoaded = false;
      loadedImagesCount = 0;
    });

    try {
      await _loadOfflineImages();
      await _loadOfflineChaptersList();
    } catch (e) {
      print('DEBUG: Errore nel caricamento contenuto offline: $e');
      
      // Assicurati che loading sia disabilitato anche in caso di errore
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento offline: $e')),
        );
      }
    }
  }

  Future<void> _loadOfflineImages() async {
    print('DEBUG: _loadOfflineImages chiamato');
    print('DEBUG: offlineMangaName: ${widget.offlineMangaName}');
    print('DEBUG: currentOfflineChapter: $currentOfflineChapter');
    
    if (widget.offlineMangaName == null || currentOfflineChapter == null) {
      print('DEBUG: Parametri offline mancanti, uscita anticipata');
      return;
    }
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mangaDir = '${dir.path}/${widget.offlineMangaName}/$currentOfflineChapter';
      print('DEBUG: Cercando immagini in: $mangaDir');
      
      // Controlla se la directory esiste
      final directory = Directory(mangaDir);
      if (!directory.existsSync()) {
        print('DEBUG: Directory non esiste: $mangaDir');
        setState(() {
          isLoading = false;
          allImagesLoaded = true;
          loadedImagesCount = 0;
          offlineImages = [];
        });
        return;
      }
      
      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      
      print('DEBUG: Trovati ${files.length} file PNG');
      
      if (files.isEmpty) {
        print('DEBUG: Nessuna immagine PNG trovata');
        setState(() {
          isLoading = false;
          allImagesLoaded = true;
          loadedImagesCount = 0;
          offlineImages = [];
        });
        return;
      }
      
      for (var file in files) {
        print('DEBUG: File trovato: ${file.path}');
      }
      
      // Ordina i file per numero sequenziale
      files.sort((a, b) {
        final RegExp regExp = RegExp(r'image_(\d+)\.png$');
        final matchA = regExp.firstMatch(a.path.split('/').last);
        final matchB = regExp.firstMatch(b.path.split('/').last);
        
        if (matchA != null && matchB != null) {
          final numA = int.parse(matchA.group(1)!);
          final numB = int.parse(matchB.group(1)!);
          return numA.compareTo(numB);
        }
        return a.path.compareTo(b.path);
      });
      
      print('DEBUG: File ordinati: ${files.map((f) => f.path.split('/').last).toList()}');
      
      setState(() {
        offlineImages = files;
        // Mantieni isLoading = true finché tutte le immagini non sono precaricate
        allImagesLoaded = false;
        loadedImagesCount = 0;
      });
      
      print('DEBUG: Stato aggiornato - offlineImages: ${offlineImages.length}');
      print('DEBUG: Iniziando precaricamento COMPLETO di tutte le immagini...');
      
      // Precarica TUTTE le immagini prima di permettere la visualizzazione
      await _preloadAllOfflineImages();
      
      // Solo ora che TUTTE le immagini sono precaricate, permettiamo la visualizzazione
      if (mounted) {
        print('DEBUG: Precaricamento completato - ${imageCache.length} immagini in cache');
        setState(() {
          isLoading = false;
          allImagesLoaded = true;
          loadedImagesCount = offlineImages.length;
        });
      }
    } catch (e) {
      print('DEBUG: Errore nel caricamento immagini offline: $e');
      setState(() {
        isLoading = false;
        offlineImages = [];
        allImagesLoaded = true;
        loadedImagesCount = 0;
      });
      // Non fare throw, lascia che l'app continui a funzionare
    }
  }

  Future<void> _loadOfflineChaptersList() async {
    print('DEBUG: _loadOfflineChaptersList chiamato');
    
    if (widget.offlineMangaName == null) {
      print('DEBUG: offlineMangaName è null, uscita anticipata');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final mangaMainDir = '${dir.path}/${widget.offlineMangaName}';
      print('DEBUG: Cercando capitoli in: $mangaMainDir');
      
      // Controlla se la directory principale esiste
      final mainDirectory = Directory(mangaMainDir);
      if (!mainDirectory.existsSync()) {
        print('DEBUG: Directory principale non esiste: $mangaMainDir');
        setState(() {
          offlineChapters = [];
        });
        return;
      }
      
      final chapters = mainDirectory
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.split('/').last.startsWith('capitolo_'))
          .toList();
      
      print('DEBUG: Trovati ${chapters.length} capitoli offline');
      for (var chapter in chapters) {
        print('DEBUG: Capitolo trovato: ${chapter.path.split('/').last}');
      }
      
      // Ordina i capitoli per numero
      chapters.sort((a, b) {
        final RegExp regExp = RegExp(r'capitolo_(\d+)$');
        final matchA = regExp.firstMatch(a.path.split('/').last);
        final matchB = regExp.firstMatch(b.path.split('/').last);
        
        if (matchA != null && matchB != null) {
          final numA = int.parse(matchA.group(1)!);
          final numB = int.parse(matchB.group(1)!);
          return numA.compareTo(numB);
        }
        return a.path.compareTo(b.path);
      });
      
      setState(() {
        availableOfflineChapters = chapters.map((d) => d.path.split('/').last).toList();
      });
    } catch (e) {
      print('Errore nel caricamento lista capitoli offline: $e');
    }
  }

  Future<void> _preloadAllOfflineImages() async {
    if (offlineImages.isEmpty) return;
    
    print('DEBUG: Iniziando precaricamento PARALLELO di ${offlineImages.length} immagini offline');
    
    // Dividi in batch per non sovraccaricare la memoria
    const int batchSize = 10;
    
    for (int startIndex = 0; startIndex < offlineImages.length; startIndex += batchSize) {
      if (!mounted) return;
      
      final int endIndex = (startIndex + batchSize < offlineImages.length) 
          ? startIndex + batchSize 
          : offlineImages.length;
      
      print('DEBUG: Precaricando batch ${startIndex + 1}-$endIndex di ${offlineImages.length}');
      
      // Precarica batch in parallelo
      List<Future> batchFutures = [];
      
      for (int i = startIndex; i < endIndex; i++) {
        final future = _preloadSingleOfflineImage(i);
        batchFutures.add(future);
      }
      
      // Aspetta che tutto il batch sia completato
      await Future.wait(batchFutures);
      
      // Aggiorna progress
      if (mounted) {
        setState(() {
          loadedImagesCount = endIndex;
        });
      }
      
      print('DEBUG: Batch ${startIndex + 1}-$endIndex completato');
    }
    
    print('DEBUG: Precaricamento COMPLETO di ${offlineImages.length} immagini terminato!');
  }
  
  Future<void> _preloadSingleOfflineImage(int index) async {
    try {
      final imageProvider = FileImage(offlineImages[index]);
      await precacheImage(imageProvider, context);
      imageCache[index] = imageProvider;
    } catch (e) {
      print('Errore nel precaricamento immagine offline $index: $e');
      // Anche in caso di errore, aggiungi comunque alla cache per evitare ricaricamenti
      imageCache[index] = FileImage(offlineImages[index]);
    }
  }
  
  // Precaricamento predittivo basato su scroll rimosso - ora tutte le immagini sono già precaricate

  Future<void> _preloadAllBase64Images() async {
    if (imagesBase64.isEmpty) return;
    
    print('DEBUG: Precaricando TUTTE le ${imagesBase64.length} immagini base64...');
    
    // Precarica tutte le immagini base64 in batch
    const int batchSize = 5;
    
    for (int startIndex = 0; startIndex < imagesBase64.length; startIndex += batchSize) {
      if (!mounted) return;
      
      final int endIndex = (startIndex + batchSize < imagesBase64.length) 
          ? startIndex + batchSize 
          : imagesBase64.length;
      
      List<Future> batchFutures = [];
      
      for (int i = startIndex; i < endIndex; i++) {
        final future = _preloadSingleBase64Image(i);
        batchFutures.add(future);
      }
      
      await Future.wait(batchFutures);
      
      if (mounted) {
        setState(() {
          loadedImagesCount = endIndex;
        });
      }
    }
    
    print('DEBUG: Precaricamento base64 completato!');
  }
  
  Future<void> _preloadSingleBase64Image(int index) async {
    try {
      final imageData = imagesBase64[index];
      if (imageData['base64'] != null) {
        final bytes = base64Decode(imageData['base64']);
        final imageProvider = MemoryImage(bytes);
        await precacheImage(imageProvider, context);
        imageCache[index] = imageProvider;
      }
    } catch (e) {
      print('Errore nel precaricamento immagine base64 $index: $e');
    }
  }
  
  Future<void> _preloadAllNetworkImages() async {
    if (capitoliList.isEmpty) return;
    
    print('DEBUG: Precaricando TUTTE le ${capitoliList.length} immagini di rete...');
    
    const int batchSize = 3; // Batch più piccoli per network images
    
    for (int startIndex = 0; startIndex < capitoliList.length; startIndex += batchSize) {
      if (!mounted) return;
      
      final int endIndex = (startIndex + batchSize < capitoliList.length) 
          ? startIndex + batchSize 
          : capitoliList.length;
      
      List<Future> batchFutures = [];
      
      for (int i = startIndex; i < endIndex; i++) {
        final future = _preloadSingleNetworkImage(i);
        batchFutures.add(future);
      }
      
      await Future.wait(batchFutures);
      
      if (mounted) {
        setState(() {
          loadedImagesCount = endIndex;
        });
      }
    }
    
    print('DEBUG: Precaricamento network completato!');
  }
  
  Future<void> _preloadSingleNetworkImage(int index) async {
    try {
      final imageProvider = NetworkImage(capitoliList[index]);
      await precacheImage(imageProvider, context);
      imageCache[index] = imageProvider;
    } catch (e) {
      print('Errore nel precaricamento immagine network $index: $e');
      // In caso di errore, mantieni il provider per tentativi successivi
      imageCache[index] = NetworkImage(capitoliList[index]);
    }
  }

  // Funzione _preloadAllImages rimossa - sostituita con precaricamento specifico per tipo

  Widget _buildImageWidget(int index) {
    // Usa SOLO la cache precaricata - tutte le immagini dovrebbero essere già caricate
    if (imageCache.containsKey(index)) {
      return Image(
        image: imageCache[index]!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        gaplessPlayback: true,
      );
    }
    
    // Se l'immagine non è in cache e dovrebbe esserlo, mostra errore
    print('ERRORE: Immagine $index non trovata in cache - questo non dovrebbe succedere!');
    return _buildErrorWidget();
  }

  // Precaricamento adiacente rimosso - tutte le immagini sono già precaricate

  // Funzioni di scroll preloading rimosse - tutte le immagini sono già precaricate

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 60,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void navigateToChapter(dynamic chapter) {
    // Usa modalità offline se esplicitamente offline o se dati offline disponibili
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      // Navigazione per modalità offline
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              LetturaScreenManga(
            offlineMangaName: widget.offlineMangaName,
            offlineChapterName: chapter as String, // chapter è String per offline
            isOfflineMode: true,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      // Navigazione per modalità online
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              LetturaScreenManga(
            allChapters: allChapters,
            manga: widget.manga,
            capitolo: chapter as ChapterModel, // chapter è ChapterModel per online
            isOfflineMode: false,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  bool _canGoPrevious() {
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      if (currentOfflineChapter == null) return false;
      final currentIndex = availableOfflineChapters.indexOf(currentOfflineChapter!);
      return currentIndex > 0;
    } else {
      if (widget.capitolo == null) return false;
      final currentIndex = allChapters.indexWhere((ch) => ch.url == widget.capitolo!.url);
      return currentIndex > 0;
    }
  }

  bool _canGoNext() {
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      if (currentOfflineChapter == null) return false;
      final currentIndex = availableOfflineChapters.indexOf(currentOfflineChapter!);
      return currentIndex < availableOfflineChapters.length - 1;
    } else {
      if (widget.capitolo == null) return false;
      final currentIndex = allChapters.indexWhere((ch) => ch.url == widget.capitolo!.url);
      return currentIndex < allChapters.length - 1;
    }
  }

  void _goToPreviousChapter() {
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      if (currentOfflineChapter == null) return;
      final currentIndex = availableOfflineChapters.indexOf(currentOfflineChapter!);
      if (currentIndex > 0) {
        navigateToChapter(availableOfflineChapters[currentIndex - 1]);
      }
    } else {
      if (widget.capitolo == null) return;
      final currentIndex = allChapters.indexWhere((ch) => ch.url == widget.capitolo!.url);
      if (currentIndex > 0) {
        navigateToChapter(allChapters[currentIndex - 1]);
      }
    }
  }

  void _goToNextChapter() {
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      if (currentOfflineChapter == null) return;
      final currentIndex = availableOfflineChapters.indexOf(currentOfflineChapter!);
      if (currentIndex < availableOfflineChapters.length - 1) {
        navigateToChapter(availableOfflineChapters[currentIndex + 1]);
      }
    } else {
      if (widget.capitolo == null) return;
      final currentIndex = allChapters.indexWhere((ch) => ch.url == widget.capitolo!.url);
      if (currentIndex < allChapters.length - 1) {
        navigateToChapter(allChapters[currentIndex + 1]);
      }
    }
  }

  int _getCurrentImageCount() {
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      return offlineImages.length;
    } else {
      return imagesBase64.isNotEmpty ? imagesBase64.length : capitoliList.length;
    }
  }

  bool _shouldShowLoading() {
    if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
      // Modalità offline: mostra loading se non tutte le immagini sono precaricate
      return isLoading || !allImagesLoaded;
    } else {
      // Modalità online: usa la logica originale
      return !allImagesLoaded || capitoliList.isEmpty;
    }
  }

  void _showChaptersModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Titolo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Seleziona Capitolo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Lista capitoli
              Expanded(
                child: ListView.builder(
                  itemCount: allChapters.length,
                  itemBuilder: (context, index) {
                    final chapter = allChapters[index];
                    final isCurrentChapter = chapter.url == (widget.capitolo?.url ?? '');

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentChapter
                            ? Colors.deepPurple.withOpacity(0.3)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentChapter
                            ? Border.all(color: Colors.deepPurple, width: 2)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrentChapter
                                ? Colors.deepPurple
                                : Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Capitolo ${index + 1}',
                          style: TextStyle(
                            color: isCurrentChapter
                                ? Colors.deepPurple
                                : Colors.white,
                            fontWeight: isCurrentChapter
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          chapter.mangaTitle,
                          style: TextStyle(
                            color: isCurrentChapter
                                ? Colors.deepPurple.withOpacity(0.8)
                                : Colors.grey[400],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCurrentChapter
                            ? const Icon(Icons.play_arrow,
                                color: Colors.deepPurple)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (!isCurrentChapter) {
                            navigateToChapter(chapter);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: FadeTransition(
          opacity: _controlsAnimation,
          child: AppBar(
            backgroundColor: Colors.black.withOpacity(0.7),
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.manga?.title ?? widget.offlineMangaName ?? 'Manga Reader',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (_getCurrentImageCount() > 0 && !isListView)
                      Text(
                        'Pagina ${currentPage + 1} di ${_getCurrentImageCount()}',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    if (widget.isOfflineMode || !isConnected) ...[
                      if (_getCurrentImageCount() > 0 && !isListView)
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Text(
                        'OFFLINE',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            actions: [
              // Toggle bottom panel visibility
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    showBottomPanel
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      showBottomPanel = !showBottomPanel;
                    });
                    // Salva la preferenza
                    if (sharedPrefs.isInitialized) {
                      sharedPrefs.setBottomPanelVisibility(showBottomPanel);
                      print('DEBUG: Salvato showBottomPanel: $showBottomPanel');
                    }
                  },
                ),
              ),
              // Switch tra PageView e ListView
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_carousel,
                      color: !isListView ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    Switch(
                      value: isListView,
                      onChanged: (value) {
                        setState(() {
                          isListView = value;
                        });
                        // Salva la preferenza
                        if (sharedPrefs.isInitialized) {
                          sharedPrefs.setReadingMode(isListView);
                          print('DEBUG: Salvato isListView: $isListView');
                        }
                      },
                      activeColor: Colors.deepPurple,
                      inactiveThumbColor: Colors.white,
                    ),
                    Icon(
                      Icons.view_list,
                      color: isListView ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Main content area for reading
          Expanded(
            child: isLoading || _shouldShowLoading()
                ? Center(
                    child: TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.deepPurple,
                                  Colors.purpleAccent
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.menu_book,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isLoading
                                ? 'Precaricamento di tutte le immagini...'
                                : (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null)
                                    ? 'Tutte le immagini offline caricate!'
                                    : imagesBase64.isNotEmpty
                                        ? 'Tutte le immagini caricate!'
                                        : 'Precaricamento completo immagini...',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!_shouldShowLoading() && !(widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) && capitoliList.isNotEmpty && imagesBase64.isEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 200,
                              child: LinearProgressIndicator(
                                value: capitoliList.isNotEmpty
                                    ? loadedImagesCount / capitoliList.length
                                    : 0,
                                backgroundColor: Colors.grey[700],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.deepPurple),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$loadedImagesCount / ${capitoliList.length} immagini',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[300],
                              ),
                            ),
                          ],
                          if (imagesBase64.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${imagesBase64.length} immagini pronte (Base64)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[300],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${offlineImages.length} immagini offline',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[300],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!allImagesLoaded && offlineImages.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 200,
                                child: LinearProgressIndicator(
                                  value: offlineImages.isNotEmpty
                                      ? loadedImagesCount / offlineImages.length
                                      : 0,
                                  backgroundColor: Colors.grey[700],
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      Colors.orange),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$loadedImagesCount / ${offlineImages.length} immagini precaricate',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  )
                : isListView
                    // ListView mode - scorrimento continuo (senza zoom) - TUTTE le immagini precaricate
                    ? GestureDetector(
                        onTap: _toggleControls,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              // Genera TUTTE le immagini in una volta - nessun caricamento dinamico
                              for (int index = 0; index < _getCurrentImageCount(); index++)
                                Container(
                                  color: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    children: [
                                      // Immagine (senza zoom in modalità lista) - già precaricata
                                      _buildImageWidget(index),
                                      // Separatore
                                      if (index < _getCurrentImageCount() - 1) // Non mostrare separatore dopo l'ultima immagine
                                        Container(
                                          margin: const EdgeInsets.symmetric(vertical: 8),
                                          height: 2,
                                          color: Colors.grey[900],
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    // PageView mode - una pagina alla volta (con zoom)
                    : GestureDetector(
                        onTap: _toggleControls,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (int page) {
                            setState(() {
                              currentPage = page;
                            });
                          },
                          itemCount: _getCurrentImageCount(),
                          itemBuilder: (context, index) {
                            return Container(
                              color: Colors.black,
                              child: Center(
                                // Solo in modalità PageView abilitiamo lo zoom
                                child: WidgetZoom(
                                  zoomWidget: _buildImageWidget(index),
                                  heroAnimationTag: "image$index",
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          // Page progress indicator (solo in PageView mode)
          if (_getCurrentImageCount() > 0 && !isListView)
            FadeTransition(
              opacity: _controlsAnimation,
              child: Container(
                height: 4,
                child: LinearProgressIndicator(
                  value: _getCurrentImageCount() > 0
                      ? (currentPage + 1) / _getCurrentImageCount()
                      : 0,
                  backgroundColor: Colors.grey[800],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ),
          // Chapter navigation bar
          if (showBottomPanel)
            FadeTransition(
              opacity: _controlsAnimation,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Previous Chapter Button
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _canGoPrevious()
                              ? Colors.deepPurple
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _canGoPrevious()
                              ? [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 24),
                          onPressed:
                              _canGoPrevious() ? _goToPreviousChapter : null,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Chapter Info Display
                      Expanded(
                        child: GestureDetector(
                          onTap: _showChaptersModal,
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                  color: Colors.deepPurple.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.list,
                                  color: Colors.deepPurple,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Capitolo ${(widget.isOfflineMode || !isConnected) ? (availableOfflineChapters.indexOf(currentOfflineChapter ?? '') + 1) : (allChapters.indexWhere((ch) => ch.url == (widget.capitolo?.url ?? '')) + 1)} di ${(widget.isOfflineMode || !isConnected) ? availableOfflineChapters.length : allChapters.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Next Chapter Button
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _canGoNext()
                              ? Colors.deepPurple
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _canGoNext()
                              ? [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: Colors.white, size: 24),
                          onPressed: _canGoNext() ? _goToNextChapter : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
