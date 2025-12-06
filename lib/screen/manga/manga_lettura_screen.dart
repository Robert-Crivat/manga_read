import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
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

class _LetturaScreenMangaState extends State<LetturaScreenManga> with SingleTickerProviderStateMixin {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  List<String> capitoliList = [];
  List<ChapterModel> allChapters = [];
  bool isLoading = false;
  bool isLoadingChapters = false;
  int currentPage = 0;
  bool showControls = true;
  bool isListView = false; // Switch tra PageView e ListView
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
    getChaptersImg();
    allChapters = widget.allChapters;
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
    setState(() {
      isLoading = true;
    });
    try {
      var results = await mangaWorldApi.getChapterPages(widget.capitolo.url);
      if (!mounted) return;
      
      setState(() {
        capitoliList = results.parametri.cast<String>();
        isLoading = false;
      });
    } catch (e) {
      print("Error searching manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void navigateToChapter(ChapterModel chapter) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LetturaScreenManga(
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
                if (capitoliList.isNotEmpty && !isListView)
                  Text(
                    'Pagina ${currentPage + 1} di ${capitoliList.length}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            actions: [
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
            child: capitoliList.isEmpty
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
                            child: const Icon(
                              Icons.menu_book,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Caricamento capitolo...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
                          itemCount: capitoliList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              color: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  // Immagine
                                  WidgetZoom(
                                    zoomWidget: Image.network(
                                      capitoliList[index],
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(40),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                                  color: Colors.deepPurple,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Caricamento ${index + 1}/${capitoliList.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => Center(
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
                                      ),
                                    ),
                                    heroAnimationTag: "image$index",
                                  ),
                                  // Separatore
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
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
                          itemCount: capitoliList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              color: Colors.black,
                              child: Center(
                                child: WidgetZoom(
                                  zoomWidget: Image.network(
                                    capitoliList[index],
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              color: Colors.deepPurple,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Caricamento ${index + 1}/${capitoliList.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Center(
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
                                  ),
                                  heroAnimationTag: "image$index",
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          // Page progress indicator (solo in PageView mode)
          if (capitoliList.isNotEmpty && !isListView)
            FadeTransition(
              opacity: _controlsAnimation,
              child: Container(
                height: 4,
                child: LinearProgressIndicator(
                  value: capitoliList.isNotEmpty 
                      ? (currentPage + 1) / capitoliList.length 
                      : 0,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ),
          // Chapter navigation bar
          FadeTransition(
            opacity: _controlsAnimation,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: isLoadingChapters
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      itemCount: allChapters.length,
                      itemBuilder: (context, index) {
                        final chapter = allChapters[index];
                        final isCurrentChapter = chapter.url == widget.capitolo.url;
                        return TweenAnimationBuilder(
                          duration: Duration(milliseconds: 300 + (index * 20)),
                          tween: Tween<double>(begin: 0, end: 1),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: 0.8 + (value * 0.2),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: GestureDetector(
                            onTap: () {
                              if (!isCurrentChapter) {
                                navigateToChapter(chapter);
                              }
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: isCurrentChapter
                                    ? const LinearGradient(
                                        colors: [Colors.deepPurple, Colors.purpleAccent],
                                      )
                                    : LinearGradient(
                                        colors: [Colors.grey[800]!, Colors.grey[700]!],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isCurrentChapter
                                    ? [
                                        BoxShadow(
                                          color: Colors.deepPurple.withOpacity(0.5),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  (index + 1).toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isCurrentChapter
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
