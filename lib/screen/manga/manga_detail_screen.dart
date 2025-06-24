import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/manga_lettura_screen.dart';
import 'package:manga_read/screen/manga/widget/show_case_manga_detail.dart';

class MangaDetailScreen extends StatefulWidget {
  final MangaSearchModel manga;

  const MangaDetailScreen({Key? key, required this.manga}) : super(key: key);

  @override
  _MangaDetailScreenState createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  List<ChapterModel> capitoliList = [];
  @override
  void initState() {
    super.initState();
    getMangaChapters();
  }

  getMangaChapters() async {
    try {
      var results = await mangaWorldApi.getMangaChapters(widget.manga.url);
      setState(() {
        for (var capitolo in results.parametri) {
          capitoliList.add(ChapterModel.fromJson(capitolo));
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
      appBar: AppBar(title: Text(widget.manga.title)),
      body: Column(
        children: [
          ShowCaseMangaDetail(manga: widget.manga),

          // Chapters list (scrollable)
          Expanded(
            child: ListView.builder(
              itemCount: ((capitoliList.length - 1) ~/ 100) + 1,
              itemBuilder: (context, groupIndex) {
                int startIndex = groupIndex * 100;
                int endIndex = (groupIndex + 1) * 100;
                if (endIndex > capitoliList.length)
                  endIndex = capitoliList.length;

                return Card(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.all(8.0),
                    initiallyExpanded: true,
                    title: Text('Capitoli ${startIndex + 1} - ${endIndex}'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: List.generate(endIndex - startIndex, (i) {
                      int index = startIndex + i;
                      var cap = capitoliList[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text('Capitolo ${index + 1}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LetturaScreenManga(
                                capitolo: cap,
                                manga: widget.manga,
                              ),
                            ),
                          );
                        },
                      );
                    }),
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
