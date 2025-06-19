import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_zoom/widget_zoom.dart';

class LetturaScreen extends StatefulWidget {
  final String url;
  final String mangaTitle;
  final List<ChapterModel> capitoliList;
  int chaptherIndex;

  LetturaScreen({
    Key? key,
    required this.url,
    required this.mangaTitle,
    required this.capitoliList,
    required this.chaptherIndex,
  }) : super(key: key);

  @override
  State<LetturaScreen> createState() => _LetturaScreenState();
}

class _LetturaScreenState extends State<LetturaScreen> {
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
      var results = await mangaWorldApi.getChapterPages(widget.url);
      setState(() {
        for (var img in results.parametri) {
          capitoliList.add(img);
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

  getImgonRun(fromURL) async {
    setState(() {
      isLoading = true;
      capitoliList.clear();
    });
    try {
      var results = await mangaWorldApi.getChapterPages(fromURL);
      setState(() {
        for (var img in results.parametri) {
          capitoliList.add(img);
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
      appBar: AppBar(
        title: Text(widget.mangaTitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            // TODO: da implementare il salvataggio dell'ultimo capitolo letto
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('${widget.mangaTitle}_lastChapterIndex', widget.chaptherIndex);
        Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          capitoliList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 80, color: Colors.grey[700]),
                      const SizedBox(height: 24),
                      const Text(
                        'Benvenuto nella schermata di lettura!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CircularProgressIndicator(),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                  child: ListView.builder(
                    itemCount: capitoliList.length,
                    itemBuilder: (context, index) {
                      return WidgetZoom(
                        heroAnimationTag: 'zoom_$index',
                        zoomWidget: Image.network(
                          capitoliList[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator());
                          },
                        ),
                      );
                    },
                  ),
                ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 90,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: ListView.builder(
                        controller: ScrollController(
                          initialScrollOffset: (widget.chaptherIndex * 48)
                              .toDouble(),
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.capitoliList.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              if (index != widget.chaptherIndex) {
                                getImgonRun(widget.capitoliList[index].url);
                                setState(() {
                                  widget.chaptherIndex = index;
                                });
                              }
                            },
                            child: Container(
                              width: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: index == widget.chaptherIndex
                                    ? Colors.blue[700]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: index == widget.chaptherIndex
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: index == widget.chaptherIndex
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
