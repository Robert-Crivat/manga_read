import "package:flutter/material.dart";
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
import "package:manga_read/screen/novel/novel_detail_new.dart";
import "package:manga_read/service/shared_prefs.dart";

class Homepage extends StatefulWidget {
  final Function? toggleTheme;
  final bool? isDarkMode;
  final List<MangaSearchModel> mangalist;
  final List<NovelModels> novels;
  final Future<void> Function()? reloadManga;

  const Homepage({
    super.key,
    this.toggleTheme,
    this.isDarkMode,
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

  bool isLoading = false;
  bool isLoadingNovel = false;
  bool isSearching = false;

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

    // Assumi che sharedPrefs sia un'istanza globale o gestita qui
    // sharedPrefs.init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
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

  // --- WIDGET BUILDERS ---

  // Widget _buildModernNovelCard(NovelModels novel, int index) {
  //   return TweenAnimationBuilder(
  //     duration: Duration(milliseconds: 300 + (index * 50)),
  //     tween: Tween<double>(begin: 0, end: 1),
  //     curve: Curves.easeOutCubic,
  //     builder: (context, double value, child) {
  //       return Transform.translate(
  //         offset: Offset(0, 30 * (1 - value)),
  //         child: Opacity(
  //           opacity: value,
  //           child: child,
  //         ),
  //       );
  //     },
  //     child: Container(
  //       decoration: BoxDecoration(
  //         borderRadius: BorderRadius.circular(16),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withOpacity(0.15),
  //             blurRadius: 10,
  //             offset: const Offset(0, 4),
  //           ),
  //         ],
  //       ),
  //       child: Material(
  //         color: Colors.transparent,
  //         child: InkWell(
  //           borderRadius: BorderRadius.circular(16),
  //           onTap: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (context) => NovelDetail(novel: novel),
  //               ),
  //             );
  //           },
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(16),
  //             child: Stack(
  //               fit: StackFit.expand,
  //               children: [
  //                 novel.img.isNotEmpty
  //                     ? Image.network(
  //                         novel.img,
  //                         fit: BoxFit.cover,
  //                         loadingBuilder: (context, child, loadingProgress) {
  //                           if (loadingProgress == null) return child;
  //                           return Container(
  //                             color: Colors.grey.shade800,
  //                             child: const Center(child: CircularProgressIndicator()),
  //                           );
  //                         },
  //                         errorBuilder: (context, error, stackTrace) {
  //                           return Container(color: Colors.grey.shade800, child: const Icon(Icons.broken_image, color: Colors.white54));
  //                         },
  //                       )
  //                     : Container(
  //                         color: Colors.grey.shade800,
  //                         child: const Icon(Icons.book, size: 50, color: Colors.white54),
  //                       ),

  //                 // Gradiente
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     gradient: LinearGradient(
  //                       begin: Alignment.topCenter,
  //                       end: Alignment.bottomCenter,
  //                       colors: [
  //                         Colors.transparent,
  //                         Colors.black.withOpacity(0.3),
  //                         Colors.black.withOpacity(0.85),
  //                       ],
  //                       stops: const [0.4, 0.7, 1.0],
  //                     ),
  //                   ),
  //                 ),

  //                 // Info
  //                 Positioned(
  //                   bottom: 0, left: 0, right: 0,
  //                   child: Padding(
  //                     padding: const EdgeInsets.all(12.0),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       mainAxisSize: MainAxisSize.min,
  //                       children: [
  //                         Text(
  //                           novel.title,
  //                           style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
  //                           maxLines: 2,
  //                           overflow: TextOverflow.ellipsis,
  //                         ),
  //                         const SizedBox(height: 6),
  //                       //   if (novel.category != null && novel.category!.isNotEmpty)
  //                       //     Container(
  //                       //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                       //       decoration: BoxDecoration(color: Colors.teal.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
  //                       //       child: Text(
  //                       //         novel.category!,
  //                       //         style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
  //                       //       ),
  //                       //     ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //                  Positioned(
  //                   top: 8, right: 8,
  //                   child: Container(
  //                     decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
  //                     child: IconButton(
  //                       icon: Icon(
  //                         sharedPrefs.isMangaInFavorites(manga.url)
  //                             ? Icons.favorite
  //                             : Icons.favorite_border,
  //                         color: sharedPrefs.isMangaInFavorites(manga.url)
  //                             ? Colors.red
  //                             : Colors.white,
  //                         size: 20,
  //                       ),
  //                       onPressed: () async {
  //                         final bool isAlreadyFavorite = sharedPrefs.isMangaInFavorites(manga.url);

  //                         if (isAlreadyFavorite) {
  //                           final success = await sharedPrefs.removeMangaFromFavorites(url: manga.url);
  //                           if (success && mounted) {
  //                             setState(() {});
  //                             ScaffoldMessenger.of(context).showSnackBar(
  //                               SnackBar(
  //                                 content: Text('${manga.title} rimosso dai preferiti'),
  //                                 backgroundColor: Colors.orange,
  //                               ),
  //                             );
  //                           }
  //                         } else {
  //                           final success = await sharedPrefs.addMangaToFavorites(
  //                             title: manga.title,
  //                             url: manga.url,
  //                             imgUrl: manga.img,
  //                           );
  //                           if (success && mounted) {
  //                             setState(() {});
  //                             ScaffoldMessenger.of(context).showSnackBar(
  //                               SnackBar(
  //                                 content: Text('${manga.title} aggiunto ai preferiti'),
  //                                 backgroundColor: Colors.green,
  //                               ),
  //                             );
  //                           }
  //                         }
  //                       },
  //                       padding: const EdgeInsets.all(6),
  //                       constraints: const BoxConstraints(),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildMangaCard(MangaSearchModel manga, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MangaDetailScreen(manga: manga),
                ),
              );
              // Refresh della UI quando si torna indietro
              if (mounted) {
                setState(() {});
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  manga.img.isNotEmpty
                      ? Image.network(
                          manga.img,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey.shade800,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.broken_image,
                                    color: Colors.white54));
                          },
                        )
                      : Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.image_not_supported,
                              size: 50, color: Colors.white54),
                        ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            manga.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (manga.type.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                manga.type,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          const SizedBox(height: 4),
                          if (manga.status.isNotEmpty)
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: manga.status
                                            .toLowerCase()
                                            .contains('corso')
                                        ? Colors.green
                                        : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    manga.status,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Favorite Icon Overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle),
                      child: IconButton(
                        icon: Icon(
                          sharedPrefs.isMangaInFavorites(manga.url)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: sharedPrefs.isMangaInFavorites(manga.url)
                              ? Colors.red
                              : Colors.white,
                          size: 20,
                        ),
                        onPressed: () async {
                          final bool isAlreadyFavorite =
                              sharedPrefs.isMangaInFavorites(manga.url);

                          if (isAlreadyFavorite) {
                            final success = await sharedPrefs
                                .removeMangaFromFavorites(url: manga.url);
                            if (success && mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${manga.title} rimosso dai preferiti'),
                                  backgroundColor: Colors.orange,
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
                                  content: Text(
                                      '${manga.title} aggiunto ai preferiti'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
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
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade500],
            ),
          ),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Cerca Manga...',
              hintStyle: TextStyle(color: Colors.white70),
              prefixIcon: Icon(Icons.search, color: Colors.white70),
              border: InputBorder.none,
              suffixIcon: IconButton(
                  onPressed: () async {
                    searchController.clear();
                    setState(() => isLoading = true);
                    try {
                      var results = await mangaWorldApi.getAllManga();
                      if (mounted) {
                        setState(() {
                          mangaList.clear();
                          mangaList.addAll(results.parametri.map(
                              (manga) => MangaSearchModel.fromJson(manga)));
                        });
                      }
                    } catch (e) {
                      debugPrint("Error refreshing manga: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Errore nel caricamento: $e")),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  },
                  icon: Icon(Icons.clear, color: Colors.white70)),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            onSubmitted: (value) => searchMangaWorld(value),
          ),
        ),
        actions: [
          // Tasto Tema
          if (widget.toggleTheme != null)
            IconButton(
              icon: Icon(widget.isDarkMode == true
                  ? Icons.light_mode
                  : Icons.dark_mode),
              color: Colors.white,
              onPressed: () => widget.toggleTheme!(),
            ),
          // Tasto Preferiti
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MangaPreferitiScreen()),
              );
              // Refresh della UI quando si torna indietro
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ],
        // bottom:
        // TabBar(
        //   controller: _tabController,
        //   indicatorColor: Colors.white,
        //   indicatorWeight: 3,
        //   labelColor: Colors.white,
        //   unselectedLabelColor: Colors.white60,
        //   tabs: const [
        //     Tab(text: "Novel"),
        //     Tab(text: "Manga"),
        //   ],
        // ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (isSearching && mangaWorldList.isNotEmpty)
              // Visualizza risultati ricerca se attiva
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
                        setState(() => isLoading = true);
                        try {
                          var results = await mangaWorldApi.getAllManga();
                          if (mounted) {
                            setState(() {
                              mangaList.clear();
                              mangaList.addAll(results.parametri.map(
                                  (manga) => MangaSearchModel.fromJson(manga)));
                            });
                          }
                        } catch (e) {
                          debugPrint("Error refreshing manga: $e");
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Errore nel caricamento: $e")),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => isLoading = false);
                        }
                      },
                      color: Colors.deepPurple,
                      backgroundColor: Colors.deepPurple.shade50,
                      animSpeedFactor: 2,
                      child: GridView.builder(
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
                    ),

      /*TabBarView(
        controller: _tabController,
        children: [
          // --- TAB NOVEL ---
          isLoadingNovel
              ? const Center(child: CircularProgressIndicator())
              : novelList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book,
                              size: 80, color: Colors.grey.shade300),
                          const Text("Nessuna novel trovata",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : LiquidPullToRefresh(
                      onRefresh: () async {
                        setState(() => isLoadingNovel = true);
                        try {
                          var results = await webNovelsApi.getAllNovels();
                          if (mounted) {
                            setState(() {
                              novelList.clear();
                              novelList.addAll(results.parametri);
                            });
                          }
                        } catch (e) {
                          debugPrint("Error refreshing novels: $e");
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Errore nel caricamento: $e")),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => isLoadingNovel = false);
                        }
                      },
                      color: Colors.teal,
                      backgroundColor: Colors.teal.shade50,
                      animSpeedFactor: 2,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: novelList.length,
                        itemBuilder: (context, index) {
                          return _buildModernNovelCard(novelList[index], index);
                        },
                      ),
                    ),

          // --- TAB MANGA ---
          ],
      ),*/
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OfflinePage(
                onBackToOnline: widget.reloadManga,
              ),
            ),
          );
        },
        icon: const Icon(Icons.wifi_off),
        label: const Text("Offline"),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}
