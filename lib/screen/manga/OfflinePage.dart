import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:manga_read/db/manga_db.dart';
import 'package:manga_read/model/manga/db_model/manga.dart';
import 'package:manga_read/model/manga/downloaded_image.dart';

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _chapters = [];

  Future<List<Manga>> getAllMangas() async {
    final db = await MangaDatabase().database;
    final result = await db.query('mangas', orderBy: 'created_at DESC');

    return result.map((row) {
      return Manga(
        id: row['id'] as int,
        title: row['title'] as String,
        coverImage:
            row['cover_image'] != null ? row['cover_image'] as Uint8List : null,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Offline Mode'),
        ),
        body: Center(
          child: ListView.builder(
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final chapter = _chapters[index];
              final imageList = chapter['imageList'] as List<DownloadedImage>;

              return Card(
                margin: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "${chapter['mangaTitle']} - Capitolo ${chapter['chapterIndex']}",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Mostra le prime 3 immagini come anteprima
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (int i = 0; i < imageList.length && i < 3; i++)
                            Container(
                              width: 100,
                              margin: EdgeInsets.only(left: 8),
                              child: Image.memory(
                                imageList[i]
                                    .imagePath, // Usa imagePath direttamente
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ));
  }
}
