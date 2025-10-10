import 'package:flutter/material.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chaprter_content.dart';
import 'package:manga_read/service/shared_prefs.dart';

class NovelReadingScreen extends StatefulWidget {
  final String chapterUrl;
  final String title;
  final String? prevChapterUrl;
  final String? nextChapterUrl;

  const NovelReadingScreen({
    Key? key,
    required this.chapterUrl,
    required this.title,
    this.prevChapterUrl,
    this.nextChapterUrl,
  }) : super(key: key);

  @override
  _NovelReadingScreenState createState() => _NovelReadingScreenState();
}

class _NovelReadingScreenState extends State<NovelReadingScreen> with SingleTickerProviderStateMixin {
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  final SharedPrefs _prefs = SharedPrefs();
  final ScrollController _scrollController = ScrollController();
  NovelChaprterContent? chapterContent;
  bool isLoading = true;
  bool isDarkMode = false;
  bool isInTranslate = false;
  double fontSize = 16.0;
  String translationMode = 'default'; // Opzioni: default, dynamic, robust, lore
  double readingProgress = 0.0;
  bool showAppBar = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _loadSettings();
    _loadChapterContent();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        readingProgress = maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
      });
    }
  }

  _loadSettings() async {
    bool darkMode = await _prefs.getDarkMode();
    setState(() {
      isDarkMode = darkMode;
      // Default font size, could be stored in SharedPrefs as well
      fontSize = 16.0;
    });
  }

  _loadChapterContent() async {
    setState(() {
      isLoading = true;
    });

    try {
      DataManager reponse = await webNovelsApi.getNovelFireChapterContent(
        widget.chapterUrl,
        translationMode: translationMode,
      );

      if (reponse.parametri.isNotEmpty) {
        chapterContent = NovelChaprterContent.fromJson(reponse.parametri);
        // Translate to Italian
        setState(() {
          isInTranslate = true;
        });
        final translatedContent =
            await chapterContent!.translateContent(from: 'en', to: 'it');

        if (translatedContent.content.isNotEmpty) {
          setState(() {
            isInTranslate = false;
            chapterContent!.content = translatedContent.content;
          });
        }
      } else {
        chapterContent = null;
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      _showError('Error: $e');
    }
  }

  _showError(String message) {
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _changeTranslationMode(String mode) {
    if (mode != translationMode) {
      setState(() {
        translationMode = mode;
      });
      _loadChapterContent(); // Ricarica il contenuto con la nuova modalità di traduzione
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: readingProgress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
        actions: [
          // Pulsante per la traduzione
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            tooltip: 'Modalità traduzione',
            onSelected: _changeTranslationMode,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'default',
                child: Row(
                  children: [
                    Icon(Icons.translate, size: 18),
                    SizedBox(width: 8),
                    Text('Default'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'dynamic',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18),
                    SizedBox(width: 8),
                    Text('Dynamic'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'robust',
                child: Row(
                  children: [
                    Icon(Icons.shield, size: 18),
                    SizedBox(width: 8),
                    Text('Robust'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'lore',
                child: Row(
                  children: [
                    Icon(Icons.book, size: 18),
                    SizedBox(width: 8),
                    Text('Lore'),
                  ],
                ),
              ),
            ],
          ),
          // Pulsante per modalità scura
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Modalità chiara' : 'Modalità scura',
            onPressed: () async {
              bool newMode = !isDarkMode;
              await _prefs.setDarkMode(newMode);
              setState(() {
                isDarkMode = newMode;
              });
            },
          ),
          // Pulsante per dimensione testo
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Dimensione testo',
            onSelected: (double value) {
              setState(() {
                fontSize = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
              const PopupMenuItem<double>(
                value: 14.0,
                child: Row(
                  children: [
                    Icon(Icons.text_decrease, size: 18),
                    SizedBox(width: 8),
                    Text('Piccolo'),
                  ],
                ),
              ),
              const PopupMenuItem<double>(
                value: 16.0,
                child: Row(
                  children: [
                    Icon(Icons.text_fields, size: 18),
                    SizedBox(width: 8),
                    Text('Medio'),
                  ],
                ),
              ),
              const PopupMenuItem<double>(
                value: 18.0,
                child: Row(
                  children: [
                    Icon(Icons.text_increase, size: 18),
                    SizedBox(width: 8),
                    Text('Grande'),
                  ],
                ),
              ),
              const PopupMenuItem<double>(
                value: 20.0,
                child: Row(
                  children: [
                    Icon(Icons.format_size, size: 18),
                    SizedBox(width: 8),
                    Text('Extra Grande'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder(
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
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.purpleAccent],
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
                    child: Icon(
                      isInTranslate ? Icons.translate : Icons.menu_book,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isInTranslate
                      ? 'Traduzione in corso...'
                      : 'Caricamento capitolo...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ))
          : chapterContent == null
              ? const Center(child: Text('Nessun contenuto disponibile'))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildChapterContent(),
                ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.prevChapterUrl != null
                        ? [Colors.deepPurple[300]!, Colors.deepPurple[400]!]
                        : [Colors.grey[300]!, Colors.grey[400]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: widget.prevChapterUrl != null
                      ? [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.prevChapterUrl != null
                        ? () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    NovelReadingScreen(
                                      chapterUrl: widget.prevChapterUrl!,
                                      title: 'Capitolo Precedente',
                                      prevChapterUrl: null,
                                      nextChapterUrl: widget.chapterUrl,
                                    ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(-1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutCubic;
                                  var tween = Tween(begin: begin, end: end).chain(
                                    CurveTween(curve: curve),
                                  );
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ),
                            );
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: widget.prevChapterUrl != null ? Colors.white : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Precedente',
                          style: TextStyle(
                            color: widget.prevChapterUrl != null ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.nextChapterUrl != null
                        ? [Colors.deepPurple[400]!, Colors.deepPurple[500]!]
                        : [Colors.grey[300]!, Colors.grey[400]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: widget.nextChapterUrl != null
                      ? [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.nextChapterUrl != null
                        ? () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    NovelReadingScreen(
                                      chapterUrl: widget.nextChapterUrl!,
                                      title: 'Capitolo Successivo',
                                      prevChapterUrl: widget.chapterUrl,
                                      nextChapterUrl: null,
                                    ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutCubic;
                                  var tween = Tween(begin: begin, end: end).chain(
                                    CurveTween(curve: curve),
                                  );
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ),
                            );
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Successivo',
                          style: TextStyle(
                            color: widget.nextChapterUrl != null ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: widget.nextChapterUrl != null ? Colors.white : Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterContent() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo del capitolo con gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    chapterContent!.chapterTitle,
                    style: TextStyle(
                      fontSize: fontSize + 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(chapterContent!.content.split(' ').length / 200).ceil()} min di lettura',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badge che mostra la modalità di traduzione attiva
            if (translationMode != 'default')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Traduzione: ${translationMode.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Contenuto del capitolo paragrafo per paragrafo con animazioni
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: chapterContent!.content
                    .split('\n\n')
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final paragraph = entry.value;
                  
                  return TweenAnimationBuilder(
                    duration: Duration(milliseconds: 400 + (index * 50)),
                    tween: Tween<double>(begin: 0, end: 1),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        paragraph,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.8,
                          letterSpacing: 0.3,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
