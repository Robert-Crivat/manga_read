import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/manga_detail_screen.dart';
import 'package:manga_read/screen/manga/widget/manga_card.dart';

class HomeManga extends StatefulWidget {
  final List<MangaSearchModel> mangalist;
  const HomeManga({super.key, required this.mangalist});

  @override
  State<HomeManga> createState() => _HomeMangaState();
}

class _HomeMangaState extends State<HomeManga> {
  List<MangaSearchModel> mangaWorldList = [];
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  List<MangaSearchModel> mangaList = [];
  final TextEditingController searchController = TextEditingController();
  List<MangaSearchModel> mangaPreferiti = [];

  @override
  void initState() {
    super.initState();
    mangaList.addAll(widget.mangalist);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: '🔍 Cerca manga...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[850]
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.deepPurple.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    mangaWorldList.clear();
                                    searchController.clear();
                                  });
                                  FocusScope.of(context).unfocus();
                                },
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {}); // Per aggiornare l'icona clear
                      },
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          searchMangaWorld(value);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (searchController.text.isNotEmpty) {
                      searchMangaWorld(searchController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Cerca',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
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
                                    MangaDetailScreen(manga: manga),
                              ),
                            );
                          },
                          leading: manga.img.isNotEmpty
                              ? Image.network(
                                  manga.img,
                                  width: 50,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.book);
                                  },
                                )
                              : const Icon(Icons.book),
                          title: Text(manga.title),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: sharedPrefs.isMangaInFavorites(manga.url)
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            onPressed: () async {
                              final bool isAlreadyFavorite = sharedPrefs
                                  .isMangaInFavorites(manga.url);

                              if (isAlreadyFavorite) {
                                // Rimuovi dai preferiti
                                final success = await sharedPrefs
                                    .removeMangaFromFavorites(url: manga.url);

                                if (success) {
                                  // Aggiorna anche la lista locale se necessario
                                  setState(() {
                                    mangaPreferiti.removeWhere(
                                      (item) => item.url == manga.url,
                                    );
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${manga.title} rimosso dai preferiti',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Errore nel rimuovere dai preferiti',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                // Aggiungi ai preferiti
                                final success = await sharedPrefs
                                    .addMangaToFavorites(
                                      title: manga.title,
                                      url: manga.url,
                                      imgUrl: manga.img,
                                    );

                                if (success) {
                                  // Aggiorna anche la lista locale se necessario
                                  setState(() {
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
                                    mangaPreferiti.add(mangaPreferito);
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${manga.title} aggiunto ai preferiti',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Manga già presente nei preferiti',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }

                              // Aggiorna l'UI
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            : Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        0.725, // Ridotto ulteriormente per dare più spazio verticale
                  ),
                  itemCount: mangaList.length,
                  itemBuilder: (context, index) {
                    final manga = mangaList[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                MangaDetailScreen(manga: manga),
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
                        tag: 'manga_${manga.url}',
                        child: MangaCard(
                          manga: manga,
                          widget: IconButton(
                          icon: Icon(
                            Icons.favorite,
                            color: sharedPrefs.isMangaInFavorites(manga.url)
                                ? Colors.red
                                : Colors.grey,
                          ),
                          onPressed: () async {
                            final bool isAlreadyFavorite = sharedPrefs
                                .isMangaInFavorites(manga.url);

                            if (isAlreadyFavorite) {
                              // Rimuovi dai preferiti
                              final success = await sharedPrefs
                                  .removeMangaFromFavorites(url: manga.url);

                              if (success) {
                                // Aggiorna anche la lista locale se necessario
                                setState(() {
                                  mangaPreferiti.removeWhere(
                                    (item) => item.url == manga.url,
                                  );
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${manga.title} rimosso dai preferiti',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Errore nel rimuovere dai preferiti',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else {
                              // Aggiungi ai preferiti
                              final success = await sharedPrefs
                                  .addMangaToFavorites(
                                    title: manga.title,
                                    url: manga.url,
                                    imgUrl: manga.img,
                                  );

                              if (success) {
                                // Aggiorna anche la lista locale se necessario
                                setState(() {
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
                                  mangaPreferiti.add(mangaPreferito);
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${manga.title} aggiunto ai preferiti',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Manga già presente nei preferiti',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }

                            // Aggiorna l'UI
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}
