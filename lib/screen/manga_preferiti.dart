import 'package:flutter/material.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';

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

    if (mangaPrefList.isNotEmpty && mangaPrefUrlImgList.isNotEmpty && mangaPrefUrlList.isNotEmpty) {
      int itemCount = [
        mangaPrefList.length,
        mangaPrefUrlImgList.length,
        mangaPrefUrlList.length
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
                return ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(mangaPreferiti[index].title),
                );
              },
            ),
    );
  }
}
