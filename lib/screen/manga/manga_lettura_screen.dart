import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:widget_zoom/widget_zoom.dart';

class LetturaScreenManga extends StatefulWidget {
  final MangaSearchModel manga;
  final ChapterModel capitolo;
  final List<ChapterModel> allChapters;

  const LetturaScreenManga(
      {Key? key,
      required this.manga,
      required this.capitolo,
      required this.allChapters})
      : super(key: key);

  @override
  State<LetturaScreenManga> createState() => _LetturaScreenMangaState();
}

class _LetturaScreenMangaState extends State<LetturaScreenManga> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  List<String> capitoliList = [];
  List<ChapterModel> allChapters = [];
  bool isLoading = false;
  bool isLoadingChapters = false;

  @override
  void initState() {
    super.initState();
    getChaptersImg();
    allChapters = widget.allChapters;
  }

  getChaptersImg() async {
    setState(() {
      isLoading = true;
    });
    try {
      var results = await mangaWorldApi.getChapterPages(widget.capitolo.url);
      setState(() {
        capitoliList = results.parametri.cast<String>();
        isLoading = false;
      });
    } catch (e) {
      print("Error searching manga: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
      setState(() {
        isLoading = false;
      });
    }
  }

  void navigateToChapter(ChapterModel chapter) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LetturaScreenManga(
          allChapters: allChapters,
          manga: widget.manga,
          capitolo: chapter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.manga.title)),
      body: Column(
        children: [
          // Main content area for reading
          Expanded(
            child: capitoliList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book,
                            size: 80, color: Colors.grey[700]),
                        const SizedBox(height: 24),
                        const Text(
                          'Benvenuto nella schermata di lettura!',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CircularProgressIndicator()
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: capitoliList.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: WidgetZoom(
                          zoomWidget: Image.network(
                            capitoliList[index],
                            fit: BoxFit.cover,
                          ),
                          heroAnimationTag: "image$index",
                        ),
                      );
                    },
                  ),
          ),
          Container(
            height: 40,
            color: Colors.black.withAlpha(100),
            child: isLoadingChapters
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = allChapters[index];
                      final isCurrentChapter =
                          chapter.url == widget.capitolo.url;
                      return GestureDetector(
                        onTap: () {
                          if (!isCurrentChapter) {
                            navigateToChapter(chapter);
                          }
                        },
                        child: Container(
                          width: 40,
                          margin: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isCurrentChapter
                                ? Colors.greenAccent
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(
                                color: isCurrentChapter
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: isCurrentChapter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
