import "package:flutter/material.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/api/web_novels_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga/manga_search_model.dart";
import "package:manga_read/model/novels/novel_models.dart";
import "package:manga_read/screen/manga/detail_screen.dart";
import "package:manga_read/screen/manga/home_manga.dart";
import "package:manga_read/screen/manga/manga_preferiti.dart";
import "package:manga_read/screen/novel/novel_detail.dart";

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

  allNoverls() async {
    setState(() {
      isLoadingNovel = true;
    });
    try {
      setState(() {
        mangaWorldList.clear(); // Clear previous results
      });

      var results = await webNovelsApi.getAllNovels();
      if (results.status == "ok") {
        setState(() {
          for (var novel in results.parametri) {
            novelList.add(NovelModels.fromJson(novel));
          }
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Nessuna novel trovata")));
      }
    } catch (e) {
      print("Error fetching all novels: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Errore nel caricamento: $e")));
    }
    setState(() {
      isLoadingNovel = false;
    });
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
            Tab(text: 'Manga'),
            Tab(text: 'Novel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          isLoading == true
              ? const Center(child: CircularProgressIndicator())
              : HomeManga(mangalist: mangaList),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  allNoverls();
                },
                child: const Text('Ricarica Novels'),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            builder: (context) => NovelDetail(novel: novel),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: novel.img.isNotEmpty
                                  ? Image.network(
                                      novel.img,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const SizedBox(
                                              height: 160,
                                              child: Icon(Icons.book, size: 48),
                                            );
                                          },
                                    )
                                  : const SizedBox(
                                      height: 160,
                                      child: Icon(Icons.menu_book, size: 48),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                height: 90,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        novel.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
