import 'package:flutter/material.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';

class MangaPreferitiScreen extends StatelessWidget {
  const MangaPreferitiScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<MangaSearchModel> mangaWorldList = sharedPrefs.mangaPref;

    return Scaffold(
      appBar: AppBar(title: const Text('Manga Preferiti')),
      body: mangaWorldList.isEmpty
          ? const Center(
              child: Text(
                'Nessun manga tra i preferiti.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: mangaWorldList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(mangaWorldList[index].title),
                );
              },
            ),
    );
  }
}
