
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/main.dart';
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
  bool isSelectionMode = false;
  Set<int> selectedChapters = {};
  bool isDownloadingBulk = false;
  Map<int, bool> downloadingChapters = {}; // Traccia quali capitoli sono in download

  @override
  void initState() {
    super.initState();
    getMangaChapters();
  }


Future<void> downloadChaptersInBackground(Map<String, dynamic> params) async {
  String mangaTitle = params['mangaTitle'];
  List<String> selectedUrls = List<String>.from(params['selectedUrls']);
  List<int> selectedIndices = List<int>.from(params['selectedIndices']);

  final MangaWorldApi api = MangaWorldApi();

  for (int i = 0; i < selectedUrls.length; i++) {
    String url = selectedUrls[i];
    int index = selectedIndices[i];

    try {
      var results = await api.getChapterPages(url);
      List<String> images = results.parametri.cast<String>();

      final uri = Uri.parse('http://80.97.160.102:8000').replace(
        path: '/download_image',
        queryParameters: {'urls': json.encode(images)},
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

        if (data['data'] != null &&
            data['data']['results'] is List &&
            data['data']['results'].isNotEmpty) {
          int imageCount = 0;
          for (var img in data['data']['results']) {
            if (img['uint8list_base64'] != null) {
              try {
                Uint8List bytes = base64Decode(img['uint8list_base64']);
                await saveImageLocallyBackground(bytes, mangaTitle, index + 1, imageCount);
                imageCount++;
              } catch (e) {
                print('Errore decodifica base64: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Errore download capitolo $index: $e');
    }
  }
}

Future<void> saveImageLocallyBackground(Uint8List bytes, String mangaName, int chapterNumber, int imageCount) async {
  final directory = await getApplicationDocumentsDirectory();
  final mangaDir = Directory('${directory.path}/$mangaName');
  final chapterDir = Directory('${mangaDir.path}/capitolo_$chapterNumber');
  if (!chapterDir.existsSync()) chapterDir.createSync(recursive: true);

  final filePath = '${chapterDir.path}/image_${imageCount + 1}.png';
  await File(filePath).writeAsBytes(bytes);
  print('Immagine salvata in: $filePath');
}

  getMangaChapters() async {
    try {
      var results = await mangaWorldApi.getMangaChapters(widget.manga.url);
      if (!mounted) return;
      
      setState(() {
        for (var capitolo in results.parametri) {
          capitoliList.add(ChapterModel.fromJson(capitolo));
        }
      });
      await checkDownloadedChapters(); // Controlla i capitoli scaricati dopo aver ottenuto la lista dei capitoli
    } catch (e) {
      print("Error searching manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
      }
    }
  }

  getChaptersImg(String cap) async {
    try {
      var results = await mangaWorldApi.getChapterPages(cap);
      if (!mounted) return;
      
      setState(() {
        image = results.parametri.cast<String>();
      });
    } catch (e) {
      print("Error searching manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
      }
    }
  }

  int imageCount = 0;
  List<File> savedImages = [];
  bool isLoading = false;

  Future<void> downloadAndSaveImage(int index) async {
    setState(() {
      isLoading = true;
      downloadingChapters[index] = true;
    });

    // Se è il primo capitolo, scarica anche la copertina
    if (index == 0) {
      await _downloadAndSaveCover();
    }

    final uri = Uri.parse('http://80.97.160.102:8000').replace(
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
        if (!mounted) return;
        
        setState(() {
          isLoading = false;
          downloadingChapters[index] = false;
        });
      } else {
        print('Nessuna immagine trovata nella risposta del backend');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nessuna immagine valida ricevuta')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore durante il download delle immagini: ${response.statusCode}',
            ),
          ),
        );
        setState(() {
          isLoading = false;
          downloadingChapters[index] = false;
        });
      }
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
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> isChapterDownloaded(String mangaName, int chapterNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final chapterDir = Directory('${directory.path}/$mangaName/capitolo_$chapterNumber');
    if (!chapterDir.existsSync()) return false;
    final files = chapterDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'));
    return files.isNotEmpty;
  }

  Future<void> deleteDownloadedChapter(String mangaName, int chapterNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final chapterDir = Directory('${directory.path}/$mangaName/capitolo_$chapterNumber');
    if (chapterDir.existsSync()) {
      final files = chapterDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'));
      for (var file in files) {
        await file.delete();
      }
      // Dopo aver eliminato le immagini, elimina la cartella del capitolo se vuota
      if (chapterDir.listSync().isEmpty) {
        await chapterDir.delete();
      }
    }

    // Se non ci sono più capitoli scaricati, elimina la cartella del manga e rimuovi dalla lista locale
    final mangaDir = Directory('${directory.path}/$mangaName');
    bool hasOtherChapters = false;
    if (mangaDir.existsSync()) {
      final subDirs = mangaDir.listSync().whereType<Directory>();
      for (var subDir in subDirs) {
        final pngFiles = subDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'));
        if (pngFiles.isNotEmpty) {
          hasOtherChapters = true;
          break;
        }
      }
      if (!hasOtherChapters) {
        await mangaDir.delete(recursive: true);
        // Rimuovi il manga dalla lista locale (se usi una lista locale tipo sharedPrefs/localDb)
        // Esempio: se hai una funzione removeLocalManga(String title)
        if (mounted) {
          // TODO: implementa la rimozione dal tuo storage locale
          // await sharedPrefs.removeLocalManga(mangaName);
        }
      }
    }

    await checkDownloadedChapters();
    if (!mounted) return;
    setState(() {});
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

  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedChapters.clear();
      }
    });
  }

  void toggleChapterSelection(int index) {
    // Non permettere la selezione di capitoli già scaricati
    if (capitoliScaricati.length > index && capitoliScaricati[index]) {
      return;
    }
    
    setState(() {
      if (selectedChapters.contains(index)) {
        selectedChapters.remove(index);
      } else {
        selectedChapters.add(index);
      }
    });
  }

  void selectAllChapters() {
    setState(() {
      // Seleziona solo i capitoli non ancora scaricati
      selectedChapters = Set.from(
        List.generate(capitoliList.length, (i) => i)
            .where((i) => !(capitoliScaricati.length > i && capitoliScaricati[i]))
      );
    });
  }

  void deselectAllChapters() {
    setState(() {
      selectedChapters.clear();
    });
  }

  Future<void> downloadAllChapters() async {
    setState(() {
      // Seleziona solo i capitoli non ancora scaricati
      selectedChapters = Set.from(
        List.generate(capitoliList.length, (i) => i)
            .where((i) => !(capitoliScaricati.length > i && capitoliScaricati[i]))
      );
    });
    await downloadSelectedChapters();
  }

  Future<void> downloadSelectedChapters() async {
    if (selectedChapters.isEmpty) return;

    setState(() {
      isDownloadingBulk = true;
      // Imposta lo stato di loading per tutti i capitoli selezionati
      for (var index in selectedChapters) {
        downloadingChapters[index] = true;
      }
    });

    // Scarica tutti i capitoli in parallelo
    List<Future<void>> downloadTasks = [];
    
    for (var index in selectedChapters) {
      downloadTasks.add(_downloadSingleChapter(index));
    }

    // Attendi che tutti i download siano completati
    await Future.wait(downloadTasks);

    await checkDownloadedChapters();
    if (!mounted) return;
    
    setState(() {
      isDownloadingBulk = false;
      isSelectionMode = false;
      selectedChapters.clear();
      // Rimuovi lo stato di loading per tutti i capitoli
      downloadingChapters.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download completato!')),
      );
    }
  }

  Future<void> _downloadSingleChapter(int index) async {
    try {
      // Se è il primo capitolo, scarica anche la copertina
      if (index == 0) {
        await _downloadAndSaveCover();
      }

      var cap = capitoliList[index];
      
      // Ottieni le immagini del capitolo
      var results = await mangaWorldApi.getChapterPages(cap.url);
      List<String> images = results.parametri.cast<String>();

      final uri = Uri.parse('http://80.97.160.102:8000').replace(
        path: '/download_image',
        queryParameters: {'urls': json.encode(images)},
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

        if (data['data'] != null &&
            data['data']['results'] is List &&
            data['data']['results'].isNotEmpty) {
          int imgCount = 0;
          for (var img in data['data']['results']) {
            if (img['uint8list_base64'] != null) {
              try {
                Uint8List bytes = base64Decode(img['uint8list_base64']);
                await _saveChapterImage(bytes, widget.manga.title, index + 1, imgCount);
                imgCount++;
              } catch (e) {
                print('Errore decodifica base64 capitolo $index: $e');
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          downloadingChapters[index] = false;
        });
      }
    } catch (e) {
      print('Errore download capitolo $index: $e');
      if (mounted) {
        setState(() {
          downloadingChapters[index] = false;
        });
      }
    }
  }

  Future<void> _saveChapterImage(Uint8List bytes, String mangaName, int chapterNumber, int imageCount) async {
    final directory = await getApplicationDocumentsDirectory();
    final mangaDir = Directory('${directory.path}/$mangaName');
    final chapterDir = Directory('${mangaDir.path}/capitolo_$chapterNumber');
    if (!chapterDir.existsSync()) chapterDir.createSync(recursive: true);

    final filePath = '${chapterDir.path}/image_${imageCount + 1}.png';
    await File(filePath).writeAsBytes(bytes);
  }

  Future<void> _downloadAndSaveCover() async {
    try {
      // Scarica la copertina del manga
      final response = await http.get(Uri.parse(widget.manga.img));
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final mangaDir = Directory('${directory.path}/${widget.manga.title}');
        if (!mangaDir.existsSync()) mangaDir.createSync(recursive: true);

        final coverPath = '${mangaDir.path}/cover.png';
        await File(coverPath).writeAsBytes(response.bodyBytes);
        print('Copertina salvata in: $coverPath');
      }
    } catch (e) {
      print('Errore nel salvare la copertina: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.title),
        actions: [
          IconButton(
            icon: Icon(
              sharedPrefs.isMangaInFavorites(widget.manga.url)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: sharedPrefs.isMangaInFavorites(widget.manga.url)
                  ? Colors.red
                  : null,
            ),
            onPressed: () async {
              final bool isAlreadyFavorite = sharedPrefs.isMangaInFavorites(widget.manga.url);

              if (isAlreadyFavorite) {
                // Rimuovi dai preferiti
                final success = await sharedPrefs.removeMangaFromFavorites(url: widget.manga.url);

                if (success) {
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.manga.title} rimosso dai preferiti'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Errore nel rimuovere dai preferiti'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // Aggiungi ai preferiti
                final success = await sharedPrefs.addMangaToFavorites(
                  title: widget.manga.title,
                  url: widget.manga.url,
                  imgUrl: widget.manga.img,
                );

                if (success) {
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.manga.title} aggiunto ai preferiti'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Manga già presente nei preferiti'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              }
            },
            tooltip: sharedPrefs.isMangaInFavorites(widget.manga.url)
                ? 'Rimuovi dai preferiti'
                : 'Aggiungi ai preferiti',
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.download_for_offline),
                onPressed: isDownloadingBulk ? null : downloadAllChapters,
                tooltip: 'Scarica tutto il manga',
              ),
              Text("scarica il manga")
            ],
          ),
          if (isSelectionMode) ...[
            IconButton(
              icon: Icon(Icons.download),
              onPressed: isDownloadingBulk ? null : downloadSelectedChapters,
              tooltip: 'Scarica selezionati',
            ),
          ],
          IconButton(
            icon: Icon(isSelectionMode ? Icons.close : Icons.checklist),
            onPressed: toggleSelectionMode,
            tooltip: isSelectionMode ? 'Esci selezione' : 'Modalità selezione',
          ),
        ],
      ),
      body: Column(
        children: [
          if (isDownloadingBulk)
            LinearProgressIndicator(),
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
                        leading: isSelectionMode
                            ? (capitoliScaricati.length > index && capitoliScaricati[index])
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : Checkbox(
                                    value: selectedChapters.contains(index),
                                    onChanged: (bool? value) {
                                      toggleChapterSelection(index);
                                    },
                                  )
                            : CircleAvatar(child: Text('${index + 1}')),
                        title: Text('Capitolo ${index + 1}'),
                        trailing: isSelectionMode
                            ? null
                            : downloadingChapters[index] == true
                                ? Container(
                                    width: 40,
                                    height: 40,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : capitoliScaricati.length > index && capitoliScaricati[index]
                                    ? IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          await deleteDownloadedChapter(widget.manga.title, index + 1);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Capitolo eliminato dalla memoria!')),
                                          );
                                        },
                                      )
                                    : IconButton(
                                        icon: Icon(Icons.download),
                                        onPressed: () async {
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
                                      ),
                        onTap: isSelectionMode
                            ? () => toggleChapterSelection(index)
                            : () {
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
