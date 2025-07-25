import 'package:flutter/material.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chapter.dart';
import 'package:manga_read/model/novels/novel_models.dart';
import 'package:manga_read/screen/novel/novel_reading_screen.dart';

class NovelDetail extends StatefulWidget {
  final NovelModels novel;

  const NovelDetail({super.key, required this.novel});

  @override
  State<NovelDetail> createState() => _NovelDetailState();
}

class _NovelDetailState extends State<NovelDetail> {
  bool isLoading = true;
  List<NovelChapter> novelChapters = [];
  final WebNovelsApi webNovelsApi = WebNovelsApi();

  @override
  void initState() {
    super.initState();
    getNovelChapters();
  }

  getNovelChapters() async {
    setState(() {
      isLoading = true;
    });
    try {
      setState(() {
        novelChapters.clear();
      });

      // Usa la funzione getNovelFireChapters invece di getNovelDetail
      DataManager chapters = await webNovelsApi.getNovelFireChapters(widget.novel.url);
      for (var chapter in chapters.parametri) {
        novelChapters.add(NovelChapter.fromJson(chapter));
      }
    } catch (e) {
      debugPrint("Error fetching novel chapters: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Errore nel caricamento dei capitoli: $e")));
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.novel.title)),
      body: Column(
        children: [
          // Novel cover image and title section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Novel image
                Container(
                  height: 200,
                  width: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    widget.novel.img,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.image_not_supported, size: 50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Novel title
                Text(
                  widget.novel.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                Text(
                  "${widget.novel.chapters} capitoli",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),

          // Mostra lo stato di caricamento o la lista dei capitoli
          isLoading 
          ? const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: novelChapters.isEmpty 
              ? const Center(
                  child: Text("Nessun capitolo trovato"),
                )
              : ListView.builder(
                  // Invertiamo l'ordine per mostrare prima i capitoli più recenti
                  reverse: true,
                  itemCount: novelChapters.length,
                  itemBuilder: (context, index) {
                    var chapter = novelChapters[index];
                    // Calcoliamo le informazioni per la navigazione tra capitoli
                    String? prevChapterUrl = index < novelChapters.length - 1 ? novelChapters[index + 1].link : null;
                    String? nextChapterUrl = index > 0 ? novelChapters[index - 1].link : null;
                    
                    return Card(
                      child: ListTile(
                        title: Text(chapter.title),
                        subtitle: chapter.chapterNumber != null 
                            ? Text("Capitolo ${chapter.chapterNumber}") 
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Naviga alla schermata di lettura del capitolo
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NovelReadingScreen(
                                chapterUrl: chapter.link,
                                title: chapter.title,
                                prevChapterUrl: prevChapterUrl,
                                nextChapterUrl: nextChapterUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ),
          ),
        ],
      ),
    );
  }
}
