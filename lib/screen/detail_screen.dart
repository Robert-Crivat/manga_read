import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/screen/lettura_screen.dart';

class DetailScreen extends StatefulWidget {
  final String url;
  final String mangaTitle;

  const DetailScreen({Key? key, required this.url, required this.mangaTitle})
    : super(key: key);

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  List<Map<String, dynamic>> capitoliList = [];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getMangaChapters();
  }

  getMangaChapters() async {
    try {
      var results = await mangaWorldApi.getMangaChapters(widget.url);
      setState(() {
        capitoliList = results;
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
      appBar: AppBar(title: Text(widget.mangaTitle)),
      body: ListView.builder(
        itemCount: capitoliList.length,
        itemBuilder: (context, index) {
          var cap = capitoliList[index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(cap['title'] ?? 'Capitolo ${index + 1}'),
            onTap: () {
              Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LetturaScreen(
                              url: cap['link'],
                              mangaTitle:
                                  cap['alt'] ?? 'Titolo non disponibile',
                            ),
                          ),
                        );
            },
          );
        },
      ),
    );
  }
}
