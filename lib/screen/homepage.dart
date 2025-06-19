import "package:flutter/material.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/api/web_novels_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga/manga_search_model.dart";
import "package:manga_read/model/novels/novel_models.dart";
import "package:manga_read/screen/detail_screen.dart";

class Homepage extends StatefulWidget {
  const Homepage({super.key});

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

  late final TabController _tabController;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    sharedPrefs.init();
    allManga();
    allNoverls();
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

  allManga() async {
    setState(() {
      isLoading = true;
    });
    try {
      setState(() {
        mangaList.clear(); // Clear previous results
      });

      var results = await mangaWorldApi.getAllManga();
      if (results.status == "ok") {
        setState(() {
          for (var manga in results.parametri) {
            mangaList.add(MangaSearchModel.fromJson(manga));
          }
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Nessun manga trovato")));
      }
    } catch (e) {
      print("Error fetching all manga: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Errore nel caricamento: $e")));
    }
    setState(() {
      isLoading = false;
    });
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text("Home", style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(
              child: Text("Manga", style: TextStyle(color: Colors.white)),
            ),
            Tab(
              child: Text("Novels", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          isLoading == true
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                if (!hasFocus) {
                                  // Clear search results when unfocused
                                  setState(() {
                                    mangaWorldList.clear();
                                  });
                                }
                              },
                              child: TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: 'Cerca manga...',
                                  border: OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        mangaWorldList.clear();
                                        searchController.clear();
                                      });
                                      FocusScope.of(context).unfocus();
                                    },
                                    icon: Icon(Icons.clear),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    searchMangaWorld(value);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (searchController.text.isNotEmpty) {
                                searchMangaWorld(searchController.text);
                              }
                            },
                            child: const Text('Cerca'),
                          ),
                        ],
                      ),
                    ),
                    mangaWorldList.isNotEmpty
                        ? Expanded(
                            child: ListView.builder(
                              itemCount: mangaWorldList.length,
                              itemBuilder: (context, index) {
                                final manga = mangaWorldList[index];
                                return Card(
                                  margin: const EdgeInsets.all(8.0),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ListTile(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DetailScreen(manga: manga),
                                          ),
                                        );
                                      },
                                      leading: manga.img.isNotEmpty
                                          ? Image.network(
                                              manga.img,
                                              width: 50,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.book,
                                                    );
                                                  },
                                            )
                                          : const Icon(Icons.book),
                                      title: Text(manga.title),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio:
                                        0.55, // Ridotto ulteriormente per dare più spazio verticale
                                  ),
                              itemCount: mangaList.length,
                              itemBuilder: (context, index) {
                                final manga = mangaList[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailScreen(manga: manga),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize:
                                          MainAxisSize.min, // Fix overflow
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: manga.img.isNotEmpty
                                              ? Image.network(
                                                  manga.img,
                                                  height: 160,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return const SizedBox(
                                                          height: 160,
                                                          child: Icon(
                                                            Icons.book,
                                                            size: 48,
                                                          ),
                                                        );
                                                      },
                                                )
                                              : const SizedBox(
                                                  height: 160,
                                                  child: Icon(
                                                    Icons.book,
                                                    size: 48,
                                                  ),
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            height:
                                                90, // Altezza fissa per questa sezione
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    manga.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (manga.author.isNotEmpty)
                                                    Text(
                                                      "Autore: ${manga.author}",
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  if (manga.genres.isNotEmpty)
                                                    Text(
                                                      "Genere: ${manga.genres}",
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  if (manga.status.isNotEmpty)
                                                    Text(
                                                      "Stato: ${manga.status}",
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
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
          isLoading == true
              ? const Center(child: CircularProgressIndicator())
              : Column(
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
                              // Navigate to novel detail page
                              // Will need to create a NovelDetailScreen or adapt DetailScreen
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
                                    child: novel.img!.isNotEmpty
                                        ? Image.network(
                                            novel.img!,
                                            height: 160,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const SizedBox(
                                                    height: 160,
                                                    child: Icon(
                                                      Icons.book,
                                                      size: 48,
                                                    ),
                                                  );
                                                },
                                          )
                                        : const SizedBox(
                                            height: 160,
                                            child: Icon(
                                              Icons.menu_book,
                                              size: 48,
                                            ),
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
                                              novel.title!,
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
      //floatingActionButton: FloatingActionButton(
      //  onPressed: () {
      //    searchController.clear();
      //    Navigator.push(
      //      context,
      //      MaterialPageRoute(builder: (context) => MangaPreferitiScreen()),
      //    );
      //  },
      //  tooltip: 'Preferiti',
      //  child: const Icon(Icons.favorite_border),
      //),
    );
  }
}
