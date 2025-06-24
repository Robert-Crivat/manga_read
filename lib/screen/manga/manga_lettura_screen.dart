import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';

class LetturaScreenManga extends StatefulWidget {
final MangaSearchModel manga;
final ChapterModel capitolo;

  const LetturaScreenManga({Key? key, required this.manga, required this.capitolo})
    : super(key: key);

  @override
  State<LetturaScreenManga> createState() => _LetturaScreenMangaState();
}

class _LetturaScreenMangaState extends State<LetturaScreenManga> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
    List<String> capitoliList = [];
    bool isLoading = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getChaptersImg();
  }

  getChaptersImg() async {
    setState(() {
      isLoading = true;
    });
    try {
      var results = await mangaWorldApi.getChapterPages(widget.capitolo.url);
      setState(() {
        for (var capitolo in results.parametri) {
          capitoliList.add(capitolo);
        }
      });
    } catch (e) {
      print("Error searching manga: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.manga.title)),
      body: capitoliList.isEmpty? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 24),
            const Text(
              'Benvenuto nella schermata di lettura!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator()
          ],
        ),
      ) : ListView.builder(
        itemCount: capitoliList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(
              capitoliList[index],
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}
