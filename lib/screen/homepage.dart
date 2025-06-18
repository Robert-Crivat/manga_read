import "package:flutter/material.dart";
import "package:manga_read/api/manga_world_api.dart";
import "package:manga_read/main.dart";
import "package:manga_read/model/manga_search_model.dart";
import "package:manga_read/screen/detail_screen.dart";
import "package:manga_read/screen/manga_preferiti.dart";

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<Manga> mangaWorldList = [];
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    sharedPrefs.init();
  }

  searchMangaWorld(String keyword) async {
    try {
      var results = await mangaWorldApi.searchManga(keyword);
      setState(() {
        for (var manga in results) {
          mangaWorldList.add(Manga.fromJson(manga));
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text("Home", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: FocusNode(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Cerca manga...',
                      border: OutlineInputBorder(),
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
          GestureDetector(
            onTap: () {
              setState(() {
                sharedPrefs.mangaPref.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferiti cancellati!')),
                );
              });
            },
            child: Container(child: Text("clear shared")),
          ),
          Expanded(
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
                            builder: (context) => DetailScreen(manga: manga),
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
                      title: Text(manga.alt ?? 'Titolo non disponibile'),
                      trailing: IconButton(
                        icon:
                            sharedPrefs.mangaPref.any(
                              (fav) => fav.link == manga.link,
                            )
                            ? Icon(Icons.favorite)
                            : Icon(Icons.favorite_border),
                        color: Colors.red,
                        onPressed: () {
                          setState(() {
                            final isFavorite = sharedPrefs.mangaPref.any(
                              (fav) => fav.link == manga.link,
                            );
                            if (isFavorite) {
                              sharedPrefs.mangaPref.removeWhere(
                                (fav) => fav.link == manga.link,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Rimosso dai preferiti!'),
                                ),
                              );
                            } else {
                              sharedPrefs.mangaPref.add(manga);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Aggiunto ai preferiti!'),
                                ),
                              );
                            }
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          searchController.clear();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MangaPreferitiScreen()),
          );
        },
        tooltip: 'Preferiti',
        child: const Icon(Icons.favorite_border),
      ),
    );
  }
}
