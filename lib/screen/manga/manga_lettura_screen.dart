import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:widget_zoom/widget_zoom.dart';

class LetturaScreenManga extends StatefulWidget {
  final MangaSearchModel manga;
  final ChapterModel capitolo;
  final List<ChapterModel> allChapters;

  const LetturaScreenManga(
      {Key? key,
      required this.manga,
      required this.capitolo,
      required this.allChapters})
      : super(key: key);

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
    getChaptersImg();
    allChapters = widget.allChapters;
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
      var results = await mangaWorldApi.getChapterPagesWithBase64(widget.capitolo.url);
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

      // Precarica le immagini dopo aver aggiornato lo stato
      if (hasBase64) {
        await _preloadBase64Images();
        if (mounted) {
          setState(() {
            loadedImagesCount = imagesBase64.length;
            allImagesLoaded = true;
            isLoading = false;
          });
        }
      } else {
        // Fallback al precaricamento tradizionale
        _preloadAllImages();
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

  Future<void> _preloadBase64Images() async {
    if (imagesBase64.isEmpty) return;
    
    for (int i = 0; i < imagesBase64.length; i++) {
      if (!mounted) return;
      try {
        final imageData = imagesBase64[i];
        if (imageData['base64'] != null) {
          final bytes = base64Decode(imageData['base64']);
          final imageProvider = MemoryImage(bytes);
          
          // Precarica l'immagine
          await precacheImage(imageProvider, context);
          imageCache[i] = imageProvider;
          
          if (mounted) {
            setState(() {
              loadedImagesCount = i + 1;
            });
          }
        }
      } catch (e) {
        print('Errore nel precaricamento immagine base64 $i: $e');
      }
    }
  }

  Future<void> _preloadAllImages() async {
    if (capitoliList.isEmpty && imagesBase64.isEmpty) return;
    
    final int totalImages = imagesBase64.isNotEmpty ? imagesBase64.length : capitoliList.length;
    
    for (int i = 0; i < totalImages; i++) {
      if (!mounted) return;
      try {
        ImageProvider imageProvider;
        
        // Usa base64 se disponibile, altrimenti network
        if (imagesBase64.isNotEmpty && i < imagesBase64.length) {
          final imageData = imagesBase64[i];
          if (imageData['base64'] != null) {
            final bytes = base64Decode(imageData['base64']);
            imageProvider = MemoryImage(bytes);
          } else {
            imageProvider = NetworkImage(capitoliList[i]);
          }
        } else {
          imageProvider = NetworkImage(capitoliList[i]);
        }
        
        // Precarica l'immagine e la mette in cache
        await precacheImage(imageProvider, context);
        imageCache[i] = imageProvider;
        
        if (mounted) {
          setState(() {
            loadedImagesCount = i + 1;
          });
        }
      } catch (e) {
        print('Errore nel precaricamento immagine $i: $e');
        // In caso di errore, usa comunque network image come fallback
        if (i < capitoliList.length) {
          try {
            final fallbackProvider = NetworkImage(capitoliList[i]);
            await precacheImage(fallbackProvider, context);
            imageCache[i] = fallbackProvider;
          } catch (fallbackError) {
            print('Errore anche nel fallback per immagine $i: $fallbackError');
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
        allImagesLoaded = true;
      });
    }
  }

  Widget _buildImageWidget(int index) {
    // Debug info
    print('DEBUG: _buildImageWidget chiamato con index: $index');
    print('DEBUG: imageCache.length: ${imageCache.length}');
    print('DEBUG: imagesBase64.length: ${imagesBase64.length}');
    print('DEBUG: capitoliList.length: ${capitoliList.length}');
    
    // Prima controlla la cache
    if (imageCache.containsKey(index)) {
      return Image(
        image: imageCache[index]!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        // Evita il rebuild inutile
        gaplessPlayback: true,
      );
    }
    
    // Fallback: usa base64 se disponibile, altrimenti network
    if (imagesBase64.isNotEmpty && index < imagesBase64.length) {
      final imageData = imagesBase64[index];
      print('DEBUG: imageData type: ${imageData.runtimeType}');
      print('DEBUG: imageData keys: ${imageData.keys}');
      
      if (imageData['base64'] != null) {
        try {
          final bytes = base64Decode(imageData['base64']);
          final imageProvider = MemoryImage(bytes);
          // Aggiungi alla cache per la prossima volta
          imageCache[index] = imageProvider;
          return Image(
            image: imageProvider,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
            gaplessPlayback: true,
          );
        } catch (e) {
          print('Errore decodifica base64 per immagine $index: $e');
        }
      }
    }
    
    // Ultimo fallback: network image
    if (index < capitoliList.length) {
      final imageProvider = NetworkImage(capitoliList[index]);
      // Aggiungi alla cache per la prossima volta
      imageCache[index] = imageProvider;
      return Image(
        image: imageProvider,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        gaplessPlayback: true,
      );
    }
    
    return _buildErrorWidget();
  }

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

  void navigateToChapter(ChapterModel chapter) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LetturaScreenManga(
          allChapters: allChapters,
          manga: widget.manga,
          capitolo: chapter,
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

  bool _canGoPrevious() {
    final currentIndex =
        allChapters.indexWhere((ch) => ch.url == widget.capitolo.url);
    return currentIndex > 0;
  }

  bool _canGoNext() {
    final currentIndex =
        allChapters.indexWhere((ch) => ch.url == widget.capitolo.url);
    return currentIndex < allChapters.length - 1;
  }

  void _goToPreviousChapter() {
    final currentIndex =
        allChapters.indexWhere((ch) => ch.url == widget.capitolo.url);
    if (currentIndex > 0) {
      navigateToChapter(allChapters[currentIndex - 1]);
    }
  }

  void _goToNextChapter() {
    final currentIndex =
        allChapters.indexWhere((ch) => ch.url == widget.capitolo.url);
    if (currentIndex < allChapters.length - 1) {
      navigateToChapter(allChapters[currentIndex + 1]);
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
                    final isCurrentChapter = chapter.url == widget.capitolo.url;

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
                  widget.manga.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((imagesBase64.isNotEmpty || capitoliList.isNotEmpty) && !isListView)
                  Text(
                    'Pagina ${currentPage + 1} di ${imagesBase64.isNotEmpty ? imagesBase64.length : capitoliList.length}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
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
            child: (!allImagesLoaded || capitoliList.isEmpty)
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
                            capitoliList.isEmpty
                                ? 'Caricamento capitolo...'
                                : imagesBase64.isNotEmpty
                                    ? 'Immagini caricate!'
                                    : 'Precaricamento immagini...',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (capitoliList.isNotEmpty && imagesBase64.isEmpty) ...[
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
                        ],
                      ),
                    ),
                  )
                : isListView
                    // ListView mode - scorrimento continuo
                    ? GestureDetector(
                        onTap: _toggleControls,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: imagesBase64.isNotEmpty ? imagesBase64.length : capitoliList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              color: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  // Immagine
                                  WidgetZoom(
                                    zoomWidget: _buildImageWidget(index),
                                    heroAnimationTag: "image$index",
                                  ),
                                  // Separatore
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    height: 2,
                                    color: Colors.grey[900],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    // PageView mode - una pagina alla volta
                    : GestureDetector(
                        onTap: _toggleControls,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (int page) {
                            setState(() {
                              currentPage = page;
                            });
                          },
                          itemCount: imagesBase64.isNotEmpty ? imagesBase64.length : capitoliList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              color: Colors.black,
                              child: Center(
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
          if ((imagesBase64.isNotEmpty || capitoliList.isNotEmpty) && !isListView)
            FadeTransition(
              opacity: _controlsAnimation,
              child: Container(
                height: 4,
                child: LinearProgressIndicator(
                  value: imagesBase64.isNotEmpty
                      ? (currentPage + 1) / imagesBase64.length
                      : capitoliList.isNotEmpty
                          ? (currentPage + 1) / capitoliList.length
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
                                  'Capitolo ${allChapters.indexWhere((ch) => ch.url == widget.capitolo.url) + 1} di ${allChapters.length}',
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
