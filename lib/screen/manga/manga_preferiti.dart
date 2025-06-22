import 'package:flutter/material.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/detail_screen.dart';

class MangaPreferitiScreen extends StatefulWidget {
  const MangaPreferitiScreen({Key? key}) : super(key: key);

  @override
  _MangaPreferitiScreenState createState() => _MangaPreferitiScreenState();
}

class _MangaPreferitiScreenState extends State<MangaPreferitiScreen> {
  List<MangaSearchModel> mangaPreferiti = [];

  @override
  void initState() {
    super.initState();
    getPref();
  }

  getPref() async {
    await sharedPrefs.init();
    List<String> mangaPrefList = sharedPrefs.mangaPref;
    List<String> mangaPrefUrlImgList = sharedPrefs.mangaPrefurlImg;
    List<String> mangaPrefUrlList = sharedPrefs.mangaPrefurl;
    mangaPreferiti.clear();

    if (mangaPrefList.isNotEmpty &&
        mangaPrefUrlImgList.isNotEmpty &&
        mangaPrefUrlList.isNotEmpty) {
      int itemCount = [
        mangaPrefList.length,
        mangaPrefUrlImgList.length,
        mangaPrefUrlList.length,
      ].reduce((a, b) => a < b ? a : b);
      for (int i = 0; i < itemCount; i++) {
        MangaSearchModel manga = MangaSearchModel(
          title: mangaPrefList[i],
          img: mangaPrefUrlImgList[i],
          url: mangaPrefUrlList[i],
          story: "",
          status: "",
          type: "",
          genres: "",
          author: "",
          artist: "",
        );
        mangaPreferiti.add(manga);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manga Preferiti')),
      body: mangaPreferiti.isEmpty
          ? const Center(
              child: Text(
                'Nessun manga tra i preferiti.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: mangaPreferiti.length,
              itemBuilder: (context, index) {
                MangaSearchModel manga = mangaPreferiti[index];
                return ListTile(
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
                        final success = await sharedPrefs.addMangaToFavorites(
                          title: manga.title,
                          url: manga.url,
                          imgUrl: manga.img,
                        );

                        if (success) {
                          // Aggiorna anche la lista locale se necessario
                          setState(() {
                            MangaSearchModel mangaPreferito = MangaSearchModel(
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
                              content: Text('Manga già presente nei preferiti'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }

                      // Aggiorna l'UI
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
