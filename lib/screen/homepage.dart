import "package:flutter/material.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/api/web_novels_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga/manga_search_model.dart";
import "package:manga_read/model/novels/novel_models.dart";
import "package:manga_read/screen/manga/OfflinePage.dart";
import "package:manga_read/screen/manga/home_manga.dart";
import "package:manga_read/screen/manga/manga_preferiti.dart";
import "package:manga_read/screen/novel/novel_detail.dart";
import "package:manga_read/screen/novel/widget/novel_card.dart";
import "package:manga_read/screen/widgets/shimmer_loading.dart";
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

class Homepage extends StatefulWidget {
  final Function? toggleTheme;
  final bool? isDarkMode;
  final List<MangaSearchModel> mangalist;
  final List<NovelModels> novels;

  const Homepage({
    super.key,
    this.toggleTheme,
    this.isDarkMode,
    required this.mangalist,
    required this.novels,
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
  bool isLoading = false;
  bool isLoadingNovel = false;
  List<MangaSearchModel> mangaPreferiti = [];

  late final TabController _tabController;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    mangaList.addAll(widget.mangalist);
    novelList.addAll(widget.novels);
    _tabController = TabController(length: 2, vsync: this);
    sharedPrefs.init();
  }

  searchMangaWorld(String keyword) async {
    try {
      var results = await mangaWorldApi.searchManga(keyword);
      setState(() {
        for (var manga in results.parametri) {
          mangaWorldList.add(MangaSearchModel.fromJson(manga));
        }
      });
    } catch (e) {
      print("Error searching manga: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
    }
  }

  Future<void> allNoverls() async {
    setState(() {
      isLoadingNovel = true;
    });
    try {
      setState(() {
        novelList.clear();
      });

      var results = await webNovelsApi.getAllNovels();
      if (!mounted) return;

      if (results.status == "ok") {
        setState(() {
          for (var novel in results.parametri) {
            novelList.add(NovelModels.fromJson(novel));
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Nessuna novel trovata")));
        }
      }
    } catch (e) {
      debugPrint("Error fetching all novels: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Errore nel caricamento: $e")));
      }
    }
    if (mounted) {
      setState(() {
        isLoadingNovel = false;
      });
    }
  }

  Future<void> allManga() async {
    setState(() {
      isLoading = true;
    });
    try {
      setState(() {
        mangaList.clear(); // Clear previous results
      });

      var results = await mangaWorldApi.getAllManga();
      if (!mounted) return;

      if (results.status == "ok") {
        setState(() {
          for (var manga in results.parametri) {
            mangaList.add(MangaSearchModel.fromJson(manga));
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nessun manga trovato")));
      }
    } catch (e) {
      debugPrint("Error fetching all manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Errore nel caricamento: $e")));
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDarkMode ?? true
                  ? [
                      const Color(0xFF1E1E1E),
                      const Color(0xFF2C2C2C),
                    ]
                  : [
                      Colors.deepPurple,
                      Colors.deepPurple.shade700,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Manga Reader',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Aggiungi pulsante per cambiare tema con animazione
          if (widget.toggleTheme != null)
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 300),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return RotationTransition(
                            turns: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          widget.isDarkMode ?? true ? Icons.light_mode : Icons.dark_mode,
                          key: ValueKey(widget.isDarkMode ?? true),
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        if (widget.toggleTheme != null) {
                          widget.toggleTheme!();
                        }
                      },
                      tooltip: widget.isDarkMode ?? true
                          ? 'Passa al tema chiaro'
                          : 'Passa al tema scuro',
                    ),
                  ),
                );
              },
            ),
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const MangaPreferitiScreen(),
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
                    },
                    tooltip: 'Preferiti',
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.white.withOpacity(0.2),
          ),
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: [
            Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Novel'),
              ),
            ),
            Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Manga'),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          isLoadingNovel
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.55,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return const MangaCardSkeleton();
                    },
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: LiquidPullToRefresh(
                        onRefresh: allNoverls,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.55,
                          ),
                          itemCount: novelList.length,
                          itemBuilder: (context, index) {
                            final novel = novelList[index];
                            return TweenAnimationBuilder(
                              duration: Duration(milliseconds: 300 + (index * 50)),
                              tween: Tween<double>(begin: 0, end: 1),
                              curve: Curves.easeOutCubic,
                              builder: (context, double value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 50 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          NovelDetail(novel: novel),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOutCubic;
                                        var tween = Tween(begin: begin, end: end).chain(
                                          CurveTween(curve: curve),
                                        );
                                        var offsetAnimation = animation.drive(tween);
                                        return SlideTransition(
                                          position: offsetAnimation,
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 400),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: 'novel_${novel.url}',
                                  child: NovelCard(novel: novel),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
          isLoading == true
              ? const Center(child: CircularProgressIndicator())
              : LiquidPullToRefresh(
                  onRefresh: allManga,
                  child: HomeManga(mangalist: mangaList),
                ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: animation,
            child: child,
          );
        },
        child: _tabController.index == 1
            ? FloatingActionButton.extended(
                key: const ValueKey('offline_fab'),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const OfflinePage(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0);
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
                },
                icon: const Icon(Icons.wifi_off_outlined),
                label: const Text(
                  'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                backgroundColor: Colors.deepPurple,
                elevation: 6,
              )
            : null,
      ),
    );
  }
}
