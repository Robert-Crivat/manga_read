import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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
import 'package:manga_read/service/notification_service.dart';
import 'package:path_provider/path_provider.dart';

class MangaDetailScreen extends StatefulWidget {
  final MangaSearchModel manga;

  const MangaDetailScreen({Key? key, required this.manga}) : super(key: key);

  @override
  _MangaDetailScreenState createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  MangaCompleteInfo? mangaInfo;
  List<DownloadedImage> downloadedImages = [];
  List<String> image = [];
  List<bool> capitoliScaricati = [];
  bool isSelectionMode = false;
  Set<int> selectedChapters = {};
  bool isDownloadingBulk = false;
  Map<int, bool> downloadingChapters = {};

  // Download manager state
  Map<int, double> downloadProgress = {};
  List<int> downloadQueue = [];
  bool isBackgroundDownloadActive = false;
  Isolate? backgroundDownloadIsolate;
  ReceivePort? receivePort;
  int maxConcurrentDownloads = 1; // Sempre 1 per download sequenziale
  Set<int> activeDownloads = {};
  
  // Notification service e contatori
  final NotificationService _notificationService = NotificationService();
  int _currentDownloadingChapter = 0;
  int _totalChaptersToDownload = 0;

  @override
  void initState() {
    super.initState();
    getMangaChapters();
    _initializeBackgroundDownloader();
    _initializeNotificationService();
  }

  Future<void> _initializeNotificationService() async {
    await _notificationService.initialize();
  }

  @override
  void dispose() {
    _stopBackgroundDownloader();
    // Cancella le notifiche solo se non ci sono download attivi
    if (activeDownloads.isEmpty) {
      _notificationService.cancelDownloadNotification(widget.manga.title);
    }
    super.dispose();
  }

  Future<void> _initializeBackgroundDownloader() async {
    receivePort = ReceivePort();

    receivePort!.listen((message) {
      if (!mounted) return;

      // Verifica che il messaggio abbia la struttura attesa
      if (message is! Map<String, dynamic>) return;

      switch (message['type']) {
        case 'progress':
          if (message['chapterIndex'] != null && message['progress'] != null) {
            setState(() {
              downloadProgress[message['chapterIndex']] = message['progress'] as double;
            });
          }
          break;
        case 'completed':
          if (message['chapterIndex'] != null) {
            setState(() {
              downloadingChapters[message['chapterIndex']] = false;
              downloadProgress.remove(message['chapterIndex']);
              activeDownloads.remove(message['chapterIndex']);
            });
            checkDownloadedChapters();
            _processDownloadQueue();
            
            if (mounted && message['message'] != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message['message'].toString()),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
          break;
        case 'error':
          if (message['chapterIndex'] != null) {
            setState(() {
              downloadingChapters[message['chapterIndex']] = false;
              downloadProgress.remove(message['chapterIndex']);
              activeDownloads.remove(message['chapterIndex']);
            });
            _processDownloadQueue();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Errore download capitolo ${message['chapterIndex'] + 1}: ${message['error'] ?? "Errore sconosciuto"}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
      }
    });
  }

  void _stopBackgroundDownloader() {
    backgroundDownloadIsolate?.kill(priority: Isolate.immediate);
    receivePort?.close();
  }

// Rimosso metodo isolate non utilizzato per evitare warning del compilatore

  // Metodo statico rimosso per evitare duplicazione del codice di download

  getMangaChapters() async {
    try {
      var results = await mangaWorldApi.getMangaChapters(widget.manga.url);
      if (!mounted) return;

      // Gestisce la nuova struttura della risposta con MangaChaptersResponse
      if (results.parametri is List && results.parametri.isNotEmpty) {
        final data = results.parametri as List;

        // Cerca le informazioni del manga e i capitoli
        Map<String, dynamic>? mangaData;
        List<dynamic>? chaptersData;

        for (var item in data) {
          if (item is Map<String, dynamic>) {
            if (item.containsKey('chapters')) {
              chaptersData = item['chapters'] as List<dynamic>?;
            } else {
              mangaData = item;
            }
          }
        }

        setState(() {
          if (mangaData != null) {
            // Aggiungi i capitoli al manga data se trovati
            if (chaptersData != null) {
              mangaData['chapters'] = chaptersData;
            }
            mangaInfo = MangaCompleteInfo.fromJson(mangaData);
          } else {
            // Fallback se non troviamo info manga
            mangaInfo = MangaCompleteInfo(
              chapters:
                  chaptersData?.map((e) => ChapterModel.fromJson(e)).toList() ??
                      [],
            );
          }
        });
      } else {
        // Fallback per vecchia struttura
        setState(() {
          mangaInfo = MangaCompleteInfo.fromJson(results.parametri);
        });
      }

      await checkDownloadedChapters();
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

  List<File> savedImages = [];
  bool isLoading = false;

  // Metodo deprecato - ora si usa _addToDownloadQueue
  @deprecated
  Future<void> downloadAndSaveImage(int index) async {
    // Reindirizza al nuovo sistema di download
    await _addToDownloadQueue([index]);
  }

  Future<void> saveImageLocally(
      Uint8List bytes, int index, int imageNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final mangaName = widget.manga.title;
    final chapterNumber = index + 1;

    final mangaDir = Directory('${directory.path}/$mangaName');
    final chapterDir = Directory('${mangaDir.path}/capitolo_$chapterNumber');
    if (!chapterDir.existsSync()) chapterDir.createSync(recursive: true);

    final filePath = '${chapterDir.path}/image_$imageNumber.png';
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
    final chapterDir =
        Directory('${directory.path}/$mangaName/capitolo_$chapterNumber');
    if (!chapterDir.existsSync()) return false;
    final files = chapterDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'));
    return files.isNotEmpty;
  }

  Future<void> deleteDownloadedChapter(
      String mangaName, int chapterNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final chapterDir =
        Directory('${directory.path}/$mangaName/capitolo_$chapterNumber');
    if (chapterDir.existsSync()) {
      final files = chapterDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'));
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
        final pngFiles = subDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'));
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
    final chapters = mangaInfo?.chapters;
    if (chapters != null) {
      for (int i = 0; i < chapters.length; i++) {
        bool isScaricato = await isChapterDownloaded(widget.manga.title, i + 1);
        scaricati.add(isScaricato);
      }
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
      final chapters = mangaInfo?.chapters;
      if (chapters != null) {
        selectedChapters = Set.from(List.generate(chapters.length, (i) => i)
            .where((i) =>
                !(capitoliScaricati.length > i && capitoliScaricati[i])));
      }
    });
  }

  void deselectAllChapters() {
    setState(() {
      selectedChapters.clear();
    });
  }

  Future<void> _addToDownloadQueue(List<int> chapterIndices) async {
    // Aggiungi solo capitoli non ancora scaricati alla coda
    for (int index in chapterIndices) {
      if (!downloadQueue.contains(index) &&
          !activeDownloads.contains(index) &&
          !(capitoliScaricati.length > index && capitoliScaricati[index])) {
        downloadQueue.add(index);
      }
    }
    
    // Imposta i contatori per le notifiche
    _totalChaptersToDownload = downloadQueue.length;
    _currentDownloadingChapter = 0;
    
    await _processDownloadQueue();
  }

  Future<void> _processDownloadQueue() async {
    // Download completamente sequenziale: solo un capitolo alla volta
    while (downloadQueue.isNotEmpty && activeDownloads.isEmpty) {
      int nextIndex = downloadQueue.removeAt(0);

      if (capitoliScaricati.length > nextIndex &&
          capitoliScaricati[nextIndex]) {
        continue; // Capitolo già scaricato
      }

      _currentDownloadingChapter++;
      activeDownloads.add(nextIndex);
      setState(() {
        downloadingChapters[nextIndex] = true;
        downloadProgress[nextIndex] = 0.0;
      });

      await _downloadChapterSequentially(nextIndex);
    }

    // Verifica se tutti i download sono completati
    if (downloadQueue.isEmpty && activeDownloads.isEmpty) {
      if (isDownloadingBulk || isSelectionMode) {
        // Mostra notifica di completamento
        await _notificationService.showDownloadCompleted(
          mangaTitle: widget.manga.title,
          totalChapters: _totalChaptersToDownload,
        );
        
        setState(() {
          isDownloadingBulk = false;
          isSelectionMode = false;
          selectedChapters.clear();
          _currentDownloadingChapter = 0;
          _totalChaptersToDownload = 0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tutti i download completati!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadChapterSequentially(int index) async {
    if (mangaInfo?.chapters == null || index >= mangaInfo!.chapters!.length)
      return;

    final chapter = mangaInfo!.chapters![index];

    try {
      // Se è il primo capitolo, scarica anche la copertina
      if (index == 0) {
        await _downloadAndSaveCover();
      }

      // Mostra notifica di inizio download del capitolo
      await _notificationService.showDownloadProgress(
        mangaTitle: widget.manga.title,
        currentChapter: _currentDownloadingChapter,
        totalChapters: _totalChaptersToDownload,
        progress: 0.0,
        currentImageInfo: 'Iniziando download capitolo ${index + 1}...',
      );

      // Download sequenziale del capitolo con notifiche per ogni immagine
      await _downloadChapterWithNotifications(index, chapter);

      // Marca il capitolo come scaricato
      setState(() {
        capitoliScaricati[index] = true;
        downloadingChapters[index] = false;
        downloadProgress.remove(index);
        activeDownloads.remove(index);
      });

      // Continua con il prossimo download
      _processDownloadQueue();

    } catch (e) {
      // Mostra notifica di errore
      await _notificationService.showDownloadError(
        mangaTitle: widget.manga.title,
        errorMessage: 'Errore capitolo ${index + 1}: ${e.toString()}',
      );

      setState(() {
        downloadingChapters[index] = false;
        downloadProgress.remove(index);
        activeDownloads.remove(index);
      });
      _processDownloadQueue();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore download capitolo ${index + 1}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadChapterWithNotifications(int index, dynamic chapter) async {
    final mangaTitle = widget.manga.title;
    final chapterUrl = chapter.url;
    final chapterNumber = index + 1;

    try {
      // Ottieni le pagine del capitolo
      var results = await mangaWorldApi.getChapterPages(chapterUrl);
      List<String> images = results.parametri.cast<String>();

      if (images.isEmpty) {
        throw Exception('Nessuna immagine trovata per il capitolo $chapterNumber');
      }

      // Crea la directory per il capitolo
      final directory = await getApplicationDocumentsDirectory();
      final mangaDir = Directory('${directory.path}/$mangaTitle');
      final chapterDir = Directory('${mangaDir.path}/capitolo_$chapterNumber');

      if (!chapterDir.existsSync()) {
        chapterDir.createSync(recursive: true);
      }

      int imageCount = 0;
      
      // Download sequenziale di ogni singola immagine con notifiche
      for (int i = 0; i < images.length; i++) {
        final imageUrl = images[i];
        
        try {
          // Aggiorna notifica per immagine corrente
          await _notificationService.showDownloadProgress(
            mangaTitle: mangaTitle,
            currentChapter: _currentDownloadingChapter,
            totalChapters: _totalChaptersToDownload,
            progress: i / images.length,
            currentImageInfo: 'Immagine ${i + 1}/${images.length}',
          );

          // Aggiorna progresso nell'UI
          setState(() {
            downloadProgress[index] = 0.2 + (0.7 * i / images.length);
          });

          // Chiamata API per singola immagine
          final uri = Uri.parse('http://192.168.2.50:8000').replace(
            path: '/download_single_image',
            queryParameters: {'url': imageUrl},
          );

          final imageResponse = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          );

          if (imageResponse.statusCode != 200) {
            throw Exception('Errore nel download dell\'immagine ${i + 1}: ${imageResponse.statusCode}');
          }

          final data = jsonDecode(imageResponse.body);

          if (data['status'] != 'ok' || data['data']?['uint8list_base64'] == null) {
            throw Exception('Immagine ${i + 1} non valida ricevuta');
          }

          // Salva l'immagine con numero progressivo
          Uint8List bytes = base64Decode(data['data']['uint8list_base64']);
          final filePath = '${chapterDir.path}/image_${(i + 1).toString().padLeft(3, '0')}.png';
          await File(filePath).writeAsBytes(bytes);
          imageCount++;
          
        } catch (e) {
          print('Errore download immagine ${i + 1}: $e');
          // Continua con la prossima immagine
        }
      }

      // Aggiorna notifica capitolo completato
      await _notificationService.showDownloadProgress(
        mangaTitle: mangaTitle,
        currentChapter: _currentDownloadingChapter,
        totalChapters: _totalChaptersToDownload,
        progress: 1.0,
        currentImageInfo: 'Capitolo $chapterNumber completato ($imageCount immagini)',
      );

      setState(() {
        downloadProgress[index] = 1.0;
      });

    } catch (e) {
      throw Exception('Errore nel download del capitolo $chapterNumber: ${e.toString()}');
    }
  }

  Future<void> downloadAllChapters() async {
    setState(() {
      isDownloadingBulk = true;
      final chapters = mangaInfo?.chapters;
      if (chapters != null) {
        selectedChapters = Set.from(List.generate(chapters.length, (i) => i)
            .where((i) =>
                !(capitoliScaricati.length > i && capitoliScaricati[i])));
      }
    });

    await _addToDownloadQueue(selectedChapters.toList());
  }

  Future<void> downloadSelectedChapters() async {
    if (selectedChapters.isEmpty) return;

    setState(() {
      isDownloadingBulk = true;
    });

    await _addToDownloadQueue(selectedChapters.toList());
  }

  Future<void> _stopAllDownloads() async {
    // Ferma tutti i download
    setState(() {
      downloadQueue.clear();
      activeDownloads.clear();
      downloadingChapters.clear();
      downloadProgress.clear();
      isDownloadingBulk = false;
      isSelectionMode = false;
      selectedChapters.clear();
      _currentDownloadingChapter = 0;
      _totalChaptersToDownload = 0;
    });

    // Cancella le notifiche di download
    await _notificationService.cancelDownloadNotification(widget.manga.title);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download fermati'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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

  // Widget per skeleton loader durante il caricamento delle info manga
  Widget _buildSkeletonLoader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton per l'immagine di copertina e info principali
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Row(
              children: [
                // Skeleton copertina con shimmer
                _buildShimmerContainer(
                  height: 220,
                  width: 140,
                  borderRadius: 16,
                  child: Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: Colors.grey.shade500,
                  ),
                ),
                SizedBox(width: 20),
                // Skeleton info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skeleton titolo
                      _buildShimmerContainer(
                        height: 24,
                        width: double.infinity,
                        borderRadius: 4,
                      ),
                      SizedBox(height: 12),
                      // Skeleton tags
                      Row(
                        children: [
                          _buildShimmerContainer(
                            height: 20,
                            width: 60,
                            borderRadius: 10,
                          ),
                          SizedBox(width: 8),
                          _buildShimmerContainer(
                            height: 20,
                            width: 80,
                            borderRadius: 10,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Skeleton descrizione
                      ...List.generate(4, (index) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: _buildShimmerContainer(
                          height: 12,
                          width: index == 3 ? 120 : double.infinity,
                          borderRadius: 4,
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget per skeleton loader dei capitoli
  Widget _buildChaptersSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 3, // Mostra 3 gruppi skeleton
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skeleton header gruppo
                _buildShimmerContainer(
                  height: 20,
                  width: 150,
                  borderRadius: 4,
                ),
                SizedBox(height: 16),
                // Skeleton capitoli
                ...List.generate(5, (chapterIndex) => Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Skeleton numero capitolo
                      _buildShimmerContainer(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                      ),
                      SizedBox(width: 16),
                      // Skeleton titolo capitolo
                      Expanded(
                        child: _buildShimmerContainer(
                          height: 16,
                          width: double.infinity,
                          borderRadius: 4,
                        ),
                      ),
                      SizedBox(width: 16),
                      // Skeleton pulsante azione
                      _buildShimmerContainer(
                        width: 40,
                        height: 40,
                        borderRadius: 8,
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget helper per creare container con effetto shimmer
  Widget _buildShimmerContainer({
    required double height,
    required double width,
    required double borderRadius,
    Widget? child,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 1500),
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade100,
            Colors.grey.shade300,
          ],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child != null ? Center(child: child) : null,
    );
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
              final bool isAlreadyFavorite =
                  sharedPrefs.isMangaInFavorites(widget.manga.url);

              if (isAlreadyFavorite) {
                // Rimuovi dai preferiti
                final success = await sharedPrefs.removeMangaFromFavorites(
                    url: widget.manga.url);

                if (success) {
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${widget.manga.title} rimosso dai preferiti'),
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
                        content:
                            Text('${widget.manga.title} aggiunto ai preferiti'),
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
          // Pulsanti basati sulla modalità
          ...isSelectionMode
              ? [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.select_all),
                        onPressed: selectAllChapters,
                        tooltip: 'Seleziona tutti',
                      ),
                      IconButton(
                        icon: Icon(Icons.download),
                        onPressed: selectedChapters.isEmpty || isDownloadingBulk
                            ? null
                            : downloadSelectedChapters,
                        tooltip: 'Scarica selezionati',
                      ),
                    ],
                  ),
                ] 
              : [
                  IconButton(
                    icon: Icon(Icons.download_for_offline),
                    onPressed: isDownloadingBulk || (activeDownloads.isNotEmpty)
                        ? null
                        : downloadAllChapters,
                    tooltip: 'Scarica tutto il manga',
                  ),
                  // Pulsante per fermare i download
                  if (activeDownloads.isNotEmpty || downloadQueue.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.stop),
                      onPressed: _stopAllDownloads,
                      tooltip: 'Ferma download',
                      color: Colors.red,
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
          // Overlay download migliorato con animazioni
          if (activeDownloads.isNotEmpty || downloadQueue.isNotEmpty)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.indigo.shade50],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Download in corso...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            SizedBox(height: 2),
                            if (_totalChaptersToDownload > 0)
                              Text(
                                'Capitolo $_currentDownloadingChapter di $_totalChaptersToDownload',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                ),
                              )
                            else
                              Text(
                                'Attivi: ${activeDownloads.length}${downloadQueue.isNotEmpty ? ' | In coda: ${downloadQueue.length}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Pulsante per cancellare la coda
                      if (downloadQueue.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                          onPressed: _stopAllDownloads,
                          tooltip: 'Ferma download',
                        ),
                    ],
                  ),
                  // Mostra progresso dettagliato per capitolo corrente
                  if (activeDownloads.isNotEmpty) ...[
                    SizedBox(height: 8),
                    for (int chapterIndex in activeDownloads)
                      Container(
                        margin: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Capitolo ${chapterIndex + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: LinearProgressIndicator(
                                value: downloadProgress[chapterIndex] ?? 0.0,
                                backgroundColor: Colors.blue.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${((downloadProgress[chapterIndex] ?? 0.0) * 100).round()}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          // Overlay modalità selezione
          if (isSelectionMode && selectedChapters.isNotEmpty)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.deepPurple.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Colors.deepPurple.shade600,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${selectedChapters.length} capitolo${selectedChapters.length != 1 ? 'i' : ''} selezionato${selectedChapters.length != 1 ? 'i' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: deselectAllChapters,
                    icon: Icon(
                      Icons.clear_all,
                      size: 16,
                      color: Colors.deepPurple.shade600,
                    ),
                    label: Text(
                      'Deseleziona',
                      style: TextStyle(
                        color: Colors.deepPurple.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ShowCase manga details con skeleton loader
          if (mangaInfo != null)
            ShowCaseMangaDetail(manga: mangaInfo!, mangaBasicInfo: widget.manga)
          else
            _buildSkeletonLoader(),
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
                if (mangaInfo?.chapters?.isNotEmpty == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${mangaInfo?.chapters?.length ?? 0}',
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
            child: mangaInfo == null
                ? _buildChaptersSkeleton()
                : mangaInfo!.chapters?.isEmpty == true
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nessun capitolo disponibile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount:
                        (((mangaInfo?.chapters?.length ?? 0) - 1) ~/ 100) + 1,
                    itemBuilder: (context, groupIndex) {
                      final chapters = mangaInfo?.chapters;
                      if (chapters == null) return const SizedBox.shrink();

                      int startIndex = groupIndex * 100;
                      int endIndex = (groupIndex + 1) * 100;
                      if (endIndex > chapters.length)
                        endIndex = chapters.length;

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ExpansionTile(
                          tilePadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          initiallyExpanded: groupIndex == 0,
                          title: Text(
                            'Capitoli ${startIndex + 1} - $endIndex',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          children: List.generate(endIndex - startIndex, (i) {
                            int index = startIndex + i;
                            final chapters = mangaInfo?.chapters;
                            if (chapters == null || index >= chapters.length)
                              return const SizedBox.shrink();

                            var cap = chapters[index];
                            bool isDownloaded =
                                capitoliScaricati.length > index &&
                                    capitoliScaricati[index];
                            bool isDownloading =
                                downloadingChapters[index] == true;

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: isSelectionMode
                                    ? isDownloaded
                                        ? Icon(Icons.check_circle,
                                            color: Colors.green, size: 28)
                                        : Checkbox(
                                            value: selectedChapters
                                                .contains(index),
                                            onChanged: (bool? value) {
                                              toggleChapterSelection(index);
                                            },
                                          )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isDownloaded
                                              ? Colors.green.shade50
                                              : Colors.deepPurple.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDownloaded
                                                  ? Colors.green.shade700
                                                  : Colors.deepPurple.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                title: Text(
                                  'Capitolo ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isDownloaded
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: isDownloaded
                                    ? Text(
                                        'Scaricato',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                                trailing: isSelectionMode
                                    ? null
                                    : isDownloading
                                        ? Container(
                                            width: 60,
                                            height: 45, // Aumentato da 40 a 45 per evitare overflow
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blue.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 18, // Ridotto da 20 a 18
                                                  height: 18, // Ridotto da 20 a 18
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 1.5, // Ridotto da 2 a 1.5
                                                    value: downloadProgress[index] ?? 0.0,
                                                    backgroundColor:
                                                        Colors.blue.shade100,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.blue.shade600,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 1), // Ridotto da 2 a 1
                                                Flexible( // Aggiunto Flexible per gestire overflow
                                                  child: Text(
                                                    '${((downloadProgress[index] ?? 0.0) * 100).clamp(0, 100).toInt()}%',
                                                    style: TextStyle(
                                                      fontSize: 7, // Ridotto da 8 a 7
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                    overflow: TextOverflow.ellipsis, // Aggiunto per sicurezza
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : isDownloaded
                                            ? IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.red,
                                                    size: 24),
                                                onPressed: () async {
                                                  try {
                                                    await deleteDownloadedChapter(
                                                        widget.manga.title,
                                                        index + 1);

                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              'Capitolo ${index + 1} eliminato!'),
                                                          backgroundColor:
                                                              Colors.orange,
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              'Errore eliminazione: $e'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              )
                                            : IconButton(
                                                icon: Icon(
                                                  Icons.download,
                                                  size: 24,
                                                  color: (activeDownloads
                                                              .contains(
                                                                  index) ||
                                                          downloadQueue
                                                              .contains(index))
                                                      ? Colors.grey.shade400
                                                      : Colors
                                                          .deepPurple.shade600,
                                                ),
                                                onPressed: (activeDownloads
                                                            .contains(index) ||
                                                        downloadQueue
                                                            .contains(index))
                                                    ? null
                                                    : () async {
                                                        await _addToDownloadQueue(
                                                            [index]);
                                                      },
                                                tooltip: (activeDownloads
                                                        .contains(index))
                                                    ? 'Download in corso'
                                                    : downloadQueue
                                                            .contains(index)
                                                        ? 'In coda per download'
                                                        : 'Scarica capitolo',
                                              ),
                                onTap: isSelectionMode
                                    ? () => toggleChapterSelection(index)
                                    : () {
                                        final chapters = mangaInfo?.chapters;
                                        if (chapters != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  LetturaScreenManga(
                                                capitolo: cap,
                                                manga: widget.manga,
                                                allChapters: chapters,
                                                isOfflineMode: false,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                              ),
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
