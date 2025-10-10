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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.manga.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          ShowCaseMangaDetail(manga: widget.manga),
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.purpleAccent],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Capitoli',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (capitoliList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${capitoliList.length}',
                      style: TextStyle(
                        color: Colors.deepPurple[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Chapters list (scrollable)
          Expanded(
            child: capitoliList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: ((capitoliList.length - 1) ~/ 100) + 1,
                    itemBuilder: (context, groupIndex) {
                      int startIndex = groupIndex * 100;
                      int endIndex = (groupIndex + 1) * 100;
                      if (endIndex > capitoliList.length)
                        endIndex = capitoliList.length;

                      return TweenAnimationBuilder(
                        duration: Duration(milliseconds: 300 + (groupIndex * 100)),
                        tween: Tween<double>(begin: 0, end: 1),
                        curve: Curves.easeOut,
                        builder: (context, double value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            initiallyExpanded: groupIndex == 0,
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.deepPurple, Colors.purpleAccent],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.auto_stories,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              'Capitoli ${startIndex + 1} - $endIndex',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            children: List.generate(endIndex - startIndex, (i) {
                              int index = startIndex + i;
                              var cap = capitoliList[index];
                              final isDownloaded = capitoliScaricati.length > index && capitoliScaricati[index];
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isDownloaded 
                                          ? Colors.green.withOpacity(0.3)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isDownloaded
                                              ? [Colors.green, Colors.green[700]!]
                                              : [Colors.deepPurple[200]!, Colors.deepPurple[400]!],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      'Capitolo ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isDownloaded)
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                          )
                                        else
                                          IconButton(
                                            onPressed: () async {
                                              await getChaptersImg(cap.url);
                                              await downloadAndSaveImage(index);
                                              await checkDownloadedChapters();
                                              if (downloadedImages.isNotEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Row(
                                                      children: [
                                                        Icon(Icons.check_circle, color: Colors.white),
                                                        SizedBox(width: 12),
                                                        Text('Capitolo scaricato con successo!'),
                                                      ],
                                                    ),
                                                    backgroundColor: Colors.green,
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.download,
                                                color: Colors.deepPurple[700],
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              LetturaScreenManga(
                                                capitolo: cap,
                                                manga: widget.manga,
                                                allChapters: capitoliList,
                                              ),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.easeInOutCubic;
                                            var tween = Tween(begin: begin, end: end).chain(
                                              CurveTween(curve: curve),
                                            );
                                            return SlideTransition(
                                              position: animation.drive(tween),
                                              child: child,
                                            );
                                          },
                                          transitionDuration: const Duration(milliseconds: 400),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
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
