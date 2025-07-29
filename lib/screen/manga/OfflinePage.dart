import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  List<String> mangaList = [];
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
    setState(() {
      mangaList = mangaDirs.map((d) => d.path.split('/').last).toList();
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
                        return ListTile(
                          title: Text(manga,
                              style: Theme.of(context).textTheme.titleMedium),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            setState(() {
                              selectedManga = manga;
                            });
                            loadChapterList(manga);
                          },
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
    );
  }
}
