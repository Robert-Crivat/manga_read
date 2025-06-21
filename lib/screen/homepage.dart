import "package:flutter/material.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/api/web_novels_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga/manga_search_model.dart";
import "package:manga_read/model/novels/novel_models.dart";
import "package:manga_read/screen/detail_screen.dart";
import "package:manga_read/screen/manga_preferiti.dart";

class Homepage extends StatefulWidget {
  final Function? toggleTheme;
  final bool? isDarkMode;
  final List<MangaSearchModel> mangalist;

  const Homepage({super.key, this.toggleTheme, this.isDarkMode, required this.mangalist});

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
    _tabController = TabController(length: 2, vsync: this);
    sharedPrefs.init();
    //allNoverls();
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
                                      /*trailing: IconButton(
                                        icon: Icon(
                                          Icons.favorite,
                                          color:
                                              mangaPreferiti.any(
                                                (item) => item.url == manga.url,
                                              )
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () {
                                          final bool isAlreadyFavorite =
                                              mangaPreferiti.any(
                                                (item) => item.url == manga.url,
                                              );

                                          setState(() {
                                            if (isAlreadyFavorite) {
                                              // Remove from favorites
                                              mangaPreferiti.removeWhere(
                                                (item) => item.url == manga.url,
                                              );
                                              sharedPrefs.mangaPref.remove(
                                                manga.title,
                                              );
                                              sharedPrefs.mangaPrefurl.remove(
                                                manga.url,
                                              );
                                              sharedPrefs.mangaPrefurlImg
                                                  .remove(manga.img);

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${manga.title} rimosso dai preferiti',
                                                  ),
                                                ),
                                              );
                                            } else {
                                              // Add to favorites
                                              MangaSearchModel mangaPreferito =
                                                  MangaSearchModel(
                                                    title: manga.title,
                                                    img: manga.img,
                                                    url: manga.url,
                                                    story: "",
                                                    status: "",
                                                    type: "",
                                                    genres: "",
                                                    author: "",
                                                    artist: "",
                                                  );
                                              mangaPreferiti.add(
                                                mangaPreferito,
                                              );
                                              sharedPrefs.mangaPref.add(
                                                manga.title,
                                              );
                                              sharedPrefs.mangaPrefurl.add(
                                                manga.url,
                                              );
                                              sharedPrefs.mangaPrefurlImg.add(
                                                manga.img,
                                              );

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${manga.title} aggiunto ai preferiti',
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                        },
                                      ),*/
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
                                    child: Stack(
                                      children: [
                                        Column(
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
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Container(
                                                height:
                                                    90, // Altezza fissa per questa sezione
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        manga.title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (manga
                                                          .author
                                                          .isNotEmpty)
                                                        Text(
                                                          "Autore: ${manga.author}",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                      if (manga
                                                          .genres
                                                          .isNotEmpty)
                                                        Text(
                                                          "Genere: ${manga.genres}",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                      if (manga
                                                          .status
                                                          .isNotEmpty)
                                                        Text(
                                                          "Stato: ${manga.status}",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        /*Positioned(
                                          top: 5,
                                          right: 5,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                mangaPreferiti.any(
                                                      (item) =>
                                                          item.url == manga.url,
                                                    )
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                final bool isAlreadyFavorite =
                                                    mangaPreferiti.any(
                                                      (item) =>
                                                          item.url == manga.url,
                                                    );

                                                setState(() {
                                                  if (isAlreadyFavorite) {
                                                    // Remove from favorites
                                                    mangaPreferiti.removeWhere(
                                                      (item) =>
                                                          item.url == manga.url,
                                                    );
                                                    setState(() {
                                                      sharedPrefs.mangaPref
                                                          .remove(manga.title);
                                                      sharedPrefs.mangaPrefurl
                                                          .remove(manga.url);
                                                      sharedPrefs
                                                          .mangaPrefurlImg
                                                          .remove(manga.img);
                                                    });

                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${manga.title} rimosso dai preferiti',
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    // Add to favorites
                                                    MangaSearchModel
                                                    mangaPreferito =
                                                        MangaSearchModel(
                                                          title: manga.title,
                                                          img: manga.img,
                                                          url: manga.url,
                                                          story: "",
                                                          status: "",
                                                          type: "",
                                                          genres: "",
                                                          author: "",
                                                          artist: "",
                                                        );
                                                    setState(() {
                                                      mangaPreferiti.add(
                                                        mangaPreferito,
                                                      );
                                                      sharedPrefs.mangaPref.add(
                                                        manga.title,
                                                      );
                                                      sharedPrefs.mangaPrefurl
                                                          .add(manga.url);
                                                      sharedPrefs
                                                          .mangaPrefurlImg
                                                          .add(manga.img);
                                                    });

                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${manga.title} aggiunto ai preferiti',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ),*/
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
          /*isLoadingNovel == true
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
                ),*/
                Center(
                  child: Text(
                    'La sezione Novel è in fase di sviluppo...',
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
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
