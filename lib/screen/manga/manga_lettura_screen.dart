import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/service/shared_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_zoom/widget_zoom.dart';

class LetturaScreenManga extends StatefulWidget {
  final String url;
  final String mangaTitle;
  final List<ChapterModel> capitoliList;
  int chaptherIndex;

  LetturaScreenManga({
    Key? key,
    required this.url,
    required this.mangaTitle,
    required this.capitoliList,
    required this.chaptherIndex,
  }) : super(key: key);

  @override
  State<LetturaScreenManga> createState() => _LetturaScreenMangaState();
}

class _LetturaScreenMangaState extends State<LetturaScreenManga> {
  List<MangaSearchModel> favorites = [];
  bool isLoading = true;
  final SharedPrefs pref = SharedPrefs();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      isLoading = true;
    });

    // Carica i preferiti
    favorites = pref.getAllFavorites();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _removeFavorite(MangaSearchModel manga) async {
    final success = await pref.removeMangaFromFavorites(
      url: manga.url,
    );

    if (success) {
      await _loadFavorites(); // Ricarica la lista

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${manga.title} rimosso dai preferiti'),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () async {
              // Ripristina il preferito
              await pref.addMangaToFavorites(
                title: manga.title,
                url: manga.url,
                imgUrl: manga.img,
              );
              await _loadFavorites();
            },
          ),
        ),
      );
    }
  }

  Future<void> _clearAllFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Vuoi rimuovere tutti i preferiti?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await pref.clearAllFavorites();
      if (success) {
        await _loadFavorites();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tutti i preferiti sono stati rimossi')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preferiti (${favorites.length})'),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllFavorites,
              tooltip: 'Rimuovi tutti',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nessun preferito',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aggiungi manga ai preferiti per vederli qui',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFavorites,
              child: ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final manga = favorites[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          manga.img,
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 70,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        ),
                      ),
                      title: Text(
                        manga.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        manga.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () {
                              // Naviga al manga
                              // Navigator.push(context, ...);
                            },
                            tooltip: 'Apri',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeFavorite(manga),
                            tooltip: 'Rimuovi',
                          ),
                        ],
                      ),
                      onTap: () {
                        // Naviga al manga
                        // Navigator.push(context, ...);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
