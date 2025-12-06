import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class OfflinePage extends StatefulWidget {
  final VoidCallback? onBackToOnline;
  
  const OfflinePage({super.key, this.onBackToOnline});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  List<String> mangaList = [];
  Map<String, File?> mangaCovers = {}; // Mappa per le copertine
  String? selectedManga;
  List<String> chapterList = [];
  String? selectedChapter;
  List<File> images = [];

  @override
  void initState() {
    super.initState();
    loadMangaList();
  }

  Future<void> loadMangaList() async {
    final dir = await getApplicationDocumentsDirectory();
    final mangaDirs = Directory(dir.path).listSync().whereType<Directory>();
    
    List<String> mangas = [];
    Map<String, File?> covers = {};
    
    for (var mangaDir in mangaDirs) {
      String mangaName = mangaDir.path.split('/').last;
      mangas.add(mangaName);
      
      // Cerca la copertina
      final coverFile = File('${mangaDir.path}/cover.png');
      if (coverFile.existsSync()) {
        covers[mangaName] = coverFile;
      } else {
        covers[mangaName] = null;
      }
    }
    
    setState(() {
      mangaList = mangas;
      mangaCovers = covers;
    });
  }

  Future<void> loadChapterList(String manga) async {
    final dir = await getApplicationDocumentsDirectory();
    final chapters = Directory('${dir.path}/$manga')
        .listSync()
        .whereType<Directory>();
    setState(() {
      chapterList = chapters.map((d) => d.path.split('/').last).toList();
      selectedChapter = null;
      images = [];
    });
  }

  Future<void> loadImages(String manga, String chapter) async {
    final dir = await getApplicationDocumentsDirectory();
    final files = Directory('${dir.path}/$manga/$chapter')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    setState(() {
      images = files;
    });
  }

    Future<void> deleteDownloadedChapter(String mangaName, int chapterNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final mangaDir = Directory('${directory.path}/$mangaName');
    
    // Elimina l'intera cartella del manga con tutti i capitoli
    if (mangaDir.existsSync()) {
      await mangaDir.delete(recursive: true);
    }

    await loadMangaList();
    if (!mounted) return;
    setState(() {});
  }

  void resetToMangaList() {
    setState(() {
      selectedManga = null;
      chapterList = [];
      selectedChapter = null;
      images = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offline Manga'),
        leading: (selectedManga != null)
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  if (images.isNotEmpty) {
                    setState(() {
                      images = [];
                      selectedChapter = null;
                    });
                  } else if (chapterList.isNotEmpty) {
                    resetToMangaList();
                  }
                },
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.cloud),
            tooltip: 'Torna online',
            onPressed: () {
              // Chiama il callback e torna indietro
              if (widget.onBackToOnline != null) {
                widget.onBackToOnline!();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Builder(
          builder: (context) {
            // Step 1: Show manga list
            if (selectedManga == null) {
              return mangaList.isEmpty
                  ? Center(child: Text('Nessun manga offline'))
                  : ListView.separated(
                      itemCount: mangaList.length,
                      separatorBuilder: (_, __) => Divider(),
                      itemBuilder: (context, index) {
                        final manga = mangaList[index];
                        final cover = mangaCovers[manga];
                        
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: Container(
                              width: 60,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[300],
                              ),
                              child: cover != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        cover,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.book, size: 40);
                                        },
                                      ),
                                    )
                                  : Icon(Icons.book, size: 40),
                            ),
                            title: Text(manga,
                                style: Theme.of(context).textTheme.titleMedium),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    deleteDownloadedChapter(manga, index);
                                  },
                                ),
                                Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                selectedManga = manga;
                              });
                              loadChapterList(manga);
                            },
                          ),
                        );
                      },
                    );
            }
            // Step 2: Show chapter list
            if (selectedChapter == null) {
              return chapterList.isEmpty
                  ? Center(child: Text('Nessun capitolo trovato'))
                  : ListView.separated(
                      itemCount: chapterList.length,
                      separatorBuilder: (_, __) => Divider(),
                      itemBuilder: (context, index) {
                        final chapter = chapterList[index];
                        return ListTile(
                          title: Text(chapter,
                              style: Theme.of(context).textTheme.titleMedium),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            setState(() {
                              selectedChapter = chapter;
                            });
                            loadImages(selectedManga!, chapter);
                          },
                        );
                      },
                    );
            }
            // Step 3: Show images
            return images.isEmpty
                ? Center(child: Text('Nessuna immagine'))
                : ListView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, index) => Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Image.file(images[index]),
                    ),
                  );
          },
        ),
      ),
      floatingActionButton: mangaList.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                if (widget.onBackToOnline != null) {
                  widget.onBackToOnline!();
                }
                Navigator.pop(context);
              },
              icon: Icon(Icons.cloud),
              label: Text('Torna Online'),
              backgroundColor: Colors.deepPurple,
            )
          : null,
    );
  }
}
