import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/db/manga_db.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/downloaded_image.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/manga_lettura_screen.dart';
import 'package:manga_read/screen/manga/widget/show_case_manga_detail.dart';
import 'package:sqflite/sqflite.dart';

class MangaDetailScreen extends StatefulWidget {
  final MangaSearchModel manga;

  const MangaDetailScreen({Key? key, required this.manga}) : super(key: key);

  @override
  _MangaDetailScreenState createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  List<ChapterModel> capitoliList = [];
  List<DownloadedImage> downloadedImages = [];
  List<String> image = [];
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

  getChaptersImg(String cap) async {
    try {
      var results = await mangaWorldApi.getChapterPages(cap);
      setState(() {
        image = results.parametri.cast<String>();
      });
    } catch (e) {
      print("Error searching manga: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
    }
  }

  String removeQueryFromUrl(String url) {
    if (url.isEmpty) return url;
    final questionMarkIndex = url.indexOf('?');
    if (questionMarkIndex == -1) {
      return url;
    }
    return url.substring(0, questionMarkIndex);
  }

  getMangaImg(String coverImage) async {
    Uint8List? coverImageData;
    try {
      String ccImg = removeQueryFromUrl(coverImage);
      var results = await mangaWorldApi.downloadSingleImage(ccImg);
      var data = results.parametri;
      setState(() {
        coverImageData = base64.decode(data["uint8list_base64"]);
      });
      return coverImageData;
    } catch (e) {
      print("Error downloading images: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Errore nel download: $e")));
    }
  }

  Future<int> saveManga(String title, String? coverImage) async {
    final db = await MangaDatabase().database;

    return await db.insert(
        'mangas',
        {
          'title': title,
          'cover_image': await getMangaImg(coverImage!),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  downloadImage(String a, int indexCap) async {
    await saveManga(widget.manga.title, widget.manga.img);
    await getChaptersImg(a);
    try {
      var results = await mangaWorldApi.downloadMultipleImages(image);
      var data = results.parametri;
      if (data is Map<String, dynamic>) {
        for (var value in data.values) {
          downloadedImages.add(DownloadedImage.fromJson(value["uint8list_base64"]));
        }
      } else if (data is Iterable) {
        for (var a in data) {
          downloadedImages.add(DownloadedImage.fromJson({"uint8list_base64": a}));
        }
      }

      if (downloadedImages.length == image.length) {
        await MangaDatabase()
            .saveChapter(widget.manga.title, indexCap, downloadedImages);
      }
    } catch (e) {
      print("Error downloading images: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Errore nel download: $e")));
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
                        trailing: IconButton(
                            onPressed: () async {
                              await downloadImage(cap.url, index);
                              if (downloadedImages.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Immagini scaricate con successo!'),
                                  ),
                                );
                              }
                            },
                            icon: Icon(Icons.download)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LetturaScreenManga(
                                capitolo: cap,
                                manga: widget.manga,
                                allChapters: capitoliList,
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
