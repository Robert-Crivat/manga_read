import "package:flutter/material.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/api/web_novels_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga/manga_search_model.dart";
import "package:manga_read/model/novels/novel_models.dart";
import "package:manga_read/screen/manga/home_manga.dart";
import "package:manga_read/screen/manga/manga_preferiti.dart";
import "package:manga_read/screen/novel/novel_detail.dart";
import "package:manga_read/screen/novel/widget/novel_card.dart";
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
        title: const Text(
          'Manga Reader',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Aggiungi pulsante per cambiare tema
          if (widget.toggleTheme != null)
            IconButton(
              icon: Icon(
                widget.isDarkMode ?? true ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
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
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MangaPreferitiScreen(),
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
          tabs: const [
            Tab(text: 'Novel'),
            Tab(text: 'Manga'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          isLoadingNovel
              ? const Center(child: CircularProgressIndicator())
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
                            return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          NovelDetail(novel: novel),
                                    ),
                                  );
                                },
                                child: NovelCard(novel: novel));
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
    );
  }
}
