import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga/capitoli_model.dart';
import 'package:manga_read/model/manga/downloaded_image.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/manga_lettura_screen.dart';
import 'package:manga_read/screen/manga/widget/show_case_manga_detail.dart';
import 'package:path_provider/path_provider.dart';

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
  List<bool> capitoliScaricati = [];

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
      await checkDownloadedChapters(); // Controlla i capitoli scaricati dopo aver ottenuto la lista dei capitoli
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

  int imageCount = 0;
  List<File> savedImages = [];
  bool isLoading = false;

  Future<void> downloadAndSaveImage(int index) async {
    setState(() {
      isLoading = true;
    });

    final uri = Uri.parse('http://100.70.187.3:8000').replace(
      path: '/download_image',
      queryParameters: {'urls': json.encode(image)},
    );

    var response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // ✅ 1. Accedi alla struttura corretta: data -> data -> results
      if (data['data'] != null &&
          data['data']['results'] is List &&
          data['data']['results'].isNotEmpty) {
        for (var img in data['data']['results']) {
          // ✅ 2. Usa il nome corretto del campo: "uint8list_base64" (non "unit8list")
          if (img['uint8list_base64'] != null) {
            try {
              Uint8List bytes = base64Decode(img['uint8list_base64']);
              await saveImageLocally(bytes, index);
            } catch (e) {
              print('Errore decodifica base64: $e');
            }
          }
        }
        await loadSavedImages();
        setState(() {
          isLoading = false;
        });
      } else {
        print('Nessuna immagine trovata nella risposta del backend');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nessuna immagine valida ricevuta')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante il download delle immagini: ${response.statusCode}',
          ),
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveImageLocally(Uint8List bytes, int index) async {
    final directory = await getApplicationDocumentsDirectory();
    final mangaName = widget.manga.title;
    final chapterNumber = index + 1;

    final mangaDir = Directory('${directory.path}/$mangaName');
    final chapterDir = Directory('${mangaDir.path}/capitolo_$chapterNumber');
    if (!chapterDir.existsSync()) chapterDir.createSync(recursive: true);

    imageCount++;
    final filePath = '${chapterDir.path}/image_$imageCount.png';
    await File(filePath).writeAsBytes(bytes);
    print('Immagine salvata in: $filePath');
  }

  Future<List<File>> getSavedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path)); // Ordina per nome
  }

  Future<void> loadSavedImages() async {
    savedImages = await getSavedImages();
    setState(() {});
  }

  Future<bool> isChapterDownloaded(String mangaName, int chapterNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final chapterDir = Directory('${directory.path}/$mangaName/capitolo_$chapterNumber');
    if (!chapterDir.existsSync()) return false;
    final files = chapterDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'));
    return files.isNotEmpty;
  }

  Future<void> checkDownloadedChapters() async {
    List<bool> scaricati = [];
    for (int i = 0; i < capitoliList.length; i++) {
      bool isScaricato = await isChapterDownloaded(widget.manga.title, i + 1);
      scaricati.add(isScaricato);
    }
    setState(() {
      capitoliScaricati = scaricati;
    });
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
                          onPressed: capitoliScaricati.length > index && capitoliScaricati[index]
                              ? null
                              : () async {
                                  await getChaptersImg(cap.url);
                                  await downloadAndSaveImage(index);
                                  await checkDownloadedChapters();
                                  if (downloadedImages.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Immagini scaricate con successo!'),
                                      ),
                                    );
                                  }
                                },
                          icon: capitoliScaricati.length > index && capitoliScaricati[index]
                              ? Icon(Icons.check, color: Colors.green)
                              : Icon(Icons.download),
                        ),
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
