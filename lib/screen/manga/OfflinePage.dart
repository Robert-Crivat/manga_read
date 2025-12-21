import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manga_read/screen/manga/manga_lettura_screen.dart';

class OfflinePage extends StatefulWidget {
  final VoidCallback? onBackToOnline;
  
  const OfflinePage({super.key, this.onBackToOnline});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  List<String> mangaList = [];
  Map<String, File?> mangaCovers = {};
  String? selectedManga;
  List<String> chapterList = [];
  String? selectedChapter;
  List<File> images = [];
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    loadMangaList();
  }

  Future<void> loadMangaList() async {
    final dir = await getApplicationDocumentsDirectory();
    print('DEBUG OfflinePage: Directory Documents: ${dir.path}');
    
    final mangaDirs = Directory(dir.path).listSync().whereType<Directory>();
    print('DEBUG OfflinePage: Directory trovate: ${mangaDirs.map((d) => d.path.split('/').last).toList()}');
    
    List<String> mangas = [];
    Map<String, File?> covers = {};
    
    for (var mangaDir in mangaDirs) {
      String mangaName = mangaDir.path.split('/').last;
      mangas.add(mangaName);
      
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
        .whereType<Directory>()
        .where((d) => d.path.split('/').last.startsWith('capitolo_'))
        .toList();
    
    // Ordina i capitoli in base al numero del capitolo
    chapters.sort((a, b) {
      final RegExp regExp = RegExp(r'capitolo_(\d+)$');
      final matchA = regExp.firstMatch(a.path.split('/').last);
      final matchB = regExp.firstMatch(b.path.split('/').last);
      
      if (matchA != null && matchB != null) {
        final numA = int.parse(matchA.group(1)!);
        final numB = int.parse(matchB.group(1)!);
        return numA.compareTo(numB);
      }
      
      // Fallback per ordinamento alfabetico
      return a.path.compareTo(b.path);
    });
    
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
    
    // Ordina i file in base al numero nell'immagine (image_001.png, image_002.png, etc.)
    files.sort((a, b) {
      // Estrai il numero dal nome del file
      final RegExp regExp = RegExp(r'image_(\d+)\.png$');
      final matchA = regExp.firstMatch(a.path.split('/').last);
      final matchB = regExp.firstMatch(b.path.split('/').last);
      
      if (matchA != null && matchB != null) {
        final numA = int.parse(matchA.group(1)!);
        final numB = int.parse(matchB.group(1)!);
        return numA.compareTo(numB);
      }
      
      // Fallback per ordinamento alfabetico se il pattern non corrisponde
      return a.path.compareTo(b.path);
    });
    
    setState(() {
      images = files;
      _currentImageIndex = 0;
    });
  }

  Future<void> deleteDownloadedChapter(String mangaName, int chapterNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final mangaDir = Directory('${directory.path}/$mangaName');
    
    if (mangaDir.existsSync()) {
      await mangaDir.delete(recursive: true);
    }

    await loadMangaList();
    if (!mounted) return;
    setState(() {});
    _showSnackBar('$mangaName eliminato con successo');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void resetToMangaList() {
    setState(() {
      selectedManga = null;
      chapterList = [];
      selectedChapter = null;
      images = [];
      _currentImageIndex = 0;
    });
  }

  Widget _buildMangaList() {
    if (mangaList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_off,
        title: 'Nessun manga offline',
        subtitle: 'Scarica alcuni manga per leggerli offline',
        actionText: 'Torna Online',
        onAction: () {
          if (widget.onBackToOnline != null) {
            widget.onBackToOnline!();
          }
          Navigator.pop(context);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 16),
          child: Text(
            'Manga Salvati (${mangaList.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: mangaList.length,
            itemBuilder: (context, index) {
              final manga = mangaList[index];
              final cover = mangaCovers[manga];
              
              return _buildMangaCard(manga, cover);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMangaCard(String manga, File? cover) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            selectedManga = manga;
          });
          loadChapterList(manga);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[100],
                ),
                child: cover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.file(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderIcon();
                          },
                        ),
                      )
                    : _buildPlaceholderIcon(),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        manga,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteDialog(manga);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Elimina'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.book,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildChapterList() {
    if (chapterList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open,
        title: 'Nessun capitolo trovato',
        subtitle: 'Questo manga non ha capitoli salvati',
        actionText: 'Torna indietro',
        onAction: resetToMangaList,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackButton('Seleziona Capitolo'),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 16),
          child: Text(
            'Capitoli (${chapterList.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: chapterList.length,
            itemBuilder: (context, index) {
              final chapter = chapterList[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                elevation: 2,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.article, color: Colors.deepPurple),
                  ),
                  title: Text(
                    chapter,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.deepPurple),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LetturaScreenManga(
                          offlineMangaName: selectedManga,
                          offlineChapterName: chapter,
                          isOfflineMode: true,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageReader() {
    if (images.isEmpty) {
      return _buildEmptyState(
        icon: Icons.image_not_supported,
        title: 'Nessuna immagine',
        subtitle: 'Impossibile caricare le immagini del capitolo',
        actionText: 'Torna indietro',
        onAction: () {
          setState(() {
            images = [];
            selectedChapter = null;
            _currentImageIndex = 0;
          });
        },
      );
    }

    return Column(
      children: [
        _buildBackButton('Lettore Manga'),
        Expanded(
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Errore nel caricamento'),
                              SizedBox(height: 4),
                              Text('Immagine ${index + 1}',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pagina ${_currentImageIndex + 1} di ${images.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                selectedChapter ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.deepPurple),
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
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(Icons.refresh),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String mangaName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Elimina Manga'),
        content: Text('Sei sicuro di voler eliminare "$mangaName" e tutti i suoi capitoli?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteDownloadedChapter(mangaName, 0);
            },
            child: Text(
              'Elimina',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Offline Manga',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.cloud, size: 28),
            tooltip: 'Torna online',
            onPressed: () {
              if (widget.onBackToOnline != null) {
                widget.onBackToOnline!();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Builder(
            builder: (context) {
              if (selectedManga == null) {
                return _buildMangaList();
              }
              if (selectedChapter == null) {
                return _buildChapterList();
              }
              return _buildImageReader();
            },
          ),
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
