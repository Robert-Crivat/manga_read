import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/lettura_screen.dart';

class DetailScreen extends StatefulWidget {
  final MangaSearchModel manga;

  const DetailScreen({Key? key, required this.manga}) : super(key: key);

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  List<ChapterModel> capitoliList = [];
  @override
  void initState() {
    // TODO: implement initState
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
          // Manga image and title section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Manga image
                Container(
                  height: 200,
                  width: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    widget.manga.img,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.image_not_supported, size: 50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Manga title
                Text(
                  widget.manga.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Chapters list (scrollable)
          Expanded(
            child: ListView.builder(
              itemCount: ((capitoliList.length - 1) ~/ 100) + 1,
              itemBuilder: (context, groupIndex) {
                int startIndex = groupIndex * 100;
                int endIndex = (groupIndex + 1) * 100;
                if (endIndex > capitoliList.length)
                  endIndex = capitoliList.length;

                return ExpansionTile(
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
                            builder: (context) => LetturaScreen(
                              url: cap.url,
                              mangaTitle: cap.mangaTitle,
                              chaptherIndex: index,
                              capitoliList: capitoliList,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
