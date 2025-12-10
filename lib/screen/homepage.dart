import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/api/web_novels_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga/manga_search_model.dart";
import "package:manga_read/model/novels/novel_models.dart";
import "package:manga_read/screen/manga/OfflinePage.dart";
import "package:manga_read/screen/manga/manga_detail_screen.dart";
// import "package:manga_read/screen/manga/home_manga.dart";
import "package:manga_read/screen/manga/manga_preferiti.dart";
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import "package:manga_read/service/shared_prefs.dart";

class Homepage extends StatefulWidget {
  final List<MangaSearchModel> mangalist;
  final List<NovelModels> novels;
  final Future<void> Function()? reloadManga;

  const Homepage({
    super.key,
    required this.mangalist,
    required this.novels,
    this.reloadManga,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  List<MangaSearchModel> mangaWorldList = [];
  List<MangaSearchModel> mangaList = [];
  List<NovelModels> novelList = [];
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool isLoadingNovel = false;
  bool isSearching = false;
  bool isLoadingMore = false;
  int currentPage = 1;

  SharedPrefs prefs = SharedPrefs();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    mangaList.addAll(widget.mangalist);
    novelList.addAll(widget.novels);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Aggiorna lo stato per il FAB quando cambia tab
      if (mounted) setState(() {});
    });

    // Listener per lo scroll infinito
    _scrollController.addListener(_onScroll);

    // Assumi che sharedPrefs sia un'istanza globale o gestita qui
    // sharedPrefs.init();
  }

  @override
  void didUpdateWidget(Homepage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronizza i dati quando vengono aggiornati dal main
    if (widget.mangalist != oldWidget.mangalist) {
      setState(() {
        mangaList.clear();
        mangaList.addAll(widget.mangalist);
        currentPage = 1;
        isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        !isSearching) {
      _loadMoreManga();
    }
  }

  Future<void> _loadMoreManga() async {
    if (isLoadingMore) return;

    setState(() => isLoadingMore = true);

    try {
      currentPage++;
      var results = await mangaWorldApi.progressiveLatestRelease(currentPage);

      if (!mounted) return;

      setState(() {
        for (var manga in results.parametri) {
          mangaList.add(MangaSearchModel.fromJson(manga));
        }
      });
    } catch (e) {
      debugPrint("Error loading more manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore nel caricamento: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  // --- API METHODS ---

  Future<void> searchMangaWorld(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        isSearching = false;
        mangaList = List.from(widget.mangalist); // Ripristina lista originale
      });
      return;
    }

    setState(() {
      isLoading = true;
      isSearching = true;
      mangaWorldList.clear();
    });

    try {
      var results = await mangaWorldApi.searchManga(keyword);
      if (!mounted) return;

      setState(() {
        for (var manga in results.parametri) {
          mangaWorldList.add(MangaSearchModel.fromJson(manga));
        }
        // Opzionale: Mostra i risultati della ricerca nella lista principale
        // mangaList = mangaWorldList;
      });
    } catch (e) {
      debugPrint("Error searching manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore nella ricerca: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildMangaCard(MangaSearchModel manga, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              // Haptic feedback
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MangaDetailScreen(manga: manga),
                ),
              );
              if (mounted) {
                setState(() {});
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image with Hero animation
                  Hero(
                    tag: 'manga_${manga.url}_cover',
                    child: manga.img.isNotEmpty
                        ? Image.network(
                            manga.img,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade300,
                                      Colors.grey.shade400,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.deepPurple,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Caricamento...',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade400,
                                      Colors.grey.shade600,
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.white70,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Immagine non disponibile',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade600,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_rounded,
                                  size: 50,
                                  color: Colors.white54,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Nessuna immagine',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Enhanced Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),

                  // Content
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            manga.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Tags Row
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (manga.type.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepPurple.shade400,
                                        Colors.purpleAccent.shade200,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.deepPurple.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    manga.type,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (manga.status.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: manga.status
                                            .toLowerCase()
                                            .contains('corso')
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (manga.status
                                                    .toLowerCase()
                                                    .contains('corso')
                                                ? Colors.green
                                                : Colors.orange)
                                            .withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        manga.status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Enhanced Favorite Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(25),
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final bool isAlreadyFavorite =
                                sharedPrefs.isMangaInFavorites(manga.url);

                            if (isAlreadyFavorite) {
                              final success = await sharedPrefs
                                  .removeMangaFromFavorites(url: manga.url);
                              if (success && mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.heart_broken,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                              '${manga.title} rimosso dai preferiti'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            } else {
                              final success =
                                  await sharedPrefs.addMangaToFavorites(
                                title: manga.title,
                                url: manga.url,
                                imgUrl: manga.img,
                              );
                              if (success && mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.favorite,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                              '${manga.title} aggiunto ai preferiti'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                sharedPrefs.isMangaInFavorites(manga.url)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(
                                    sharedPrefs.isMangaInFavorites(manga.url)),
                                color: sharedPrefs.isMangaInFavorites(manga.url)
                                    ? Colors.red.shade400
                                    : Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade900,
                Colors.deepPurple.shade600,
                Colors.purpleAccent.shade400,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'Scopri nuovi manga...',
                          hintStyle: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                          border: InputBorder.none,
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () async {
                                    searchController.clear();
                                    setState(() => isLoading = true);
                                    try {
                                      var results =
                                          await mangaWorldApi.latestRelease();
                                      if (mounted) {
                                        setState(() {
                                          mangaList.clear();
                                          mangaList.addAll(results.parametri
                                              .map((manga) =>
                                                  MangaSearchModel.fromJson(
                                                      manga)));
                                          isSearching = false;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint("Error refreshing manga: $e");
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Errore nel caricamento: $e")),
                                        );
                                      }
                                    } finally {
                                      if (mounted)
                                        setState(() => isLoading = false);
                                    }
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                )
                              : null,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (value) => searchMangaWorld(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Action Buttons
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const MangaPreferitiScreen()),
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (isSearching && mangaWorldList.isNotEmpty)
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: mangaWorldList.length,
                  itemBuilder: (context, index) {
                    return _buildMangaCard(mangaWorldList[index], index);
                  },
                )
              : mangaList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported,
                              size: 80, color: Colors.grey.shade300),
                          const Text("Nessun manga trovato",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : LiquidPullToRefresh(
                      onRefresh: () async {
                        if (widget.reloadManga != null) {
                          // Mostra loading locale invece della schermata del main
                          setState(() {
                            isLoading = true;
                          });

                          try {
                            var result = await mangaWorldApi.latestRelease();
                            if (mounted && result.status == "ok") {
                              for (var manga in result.parametri) {
                                mangaList.add(MangaSearchModel.fromJson(manga));
                              }
                            }
                          } catch (e) {
                            debugPrint("Error reloading manga: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Errore nel caricamento: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        }
                      },
                      color: Colors.deepPurple,
                      backgroundColor: Colors.deepPurple.shade50,
                      animSpeedFactor: 2,
                      child: Stack(
                        children: [
                          GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.65,
                            ),
                            itemCount: mangaList.length,
                            itemBuilder: (context, index) {
                              return _buildMangaCard(mangaList[index], index);
                            },
                          ),
                          if (isLoadingMore)
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Caricamento...',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade600,
              Colors.purpleAccent.shade400,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OfflinePage(
                  onBackToOnline: widget.reloadManga,
                ),
              ),
            );
          },
          icon: const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white,
          ),
          label: const Text(
            "Modalità Offline",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}
