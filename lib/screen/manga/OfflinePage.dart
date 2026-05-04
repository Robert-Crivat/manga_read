import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manga_read/screen/manga/manga_lettura_screen.dart';
import 'package:manga_read/main.dart';

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
    print(
        'DEBUG OfflinePage: Directory trovate: ${mangaDirs.map((d) => d.path.split('/').last).toList()}');

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

  Future<void> deleteDownloadedChapter(
      String mangaName, int chapterNumber) async {
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

  /// Elimina fisicamente un singolo capitolo offline dal dispositivo
  Future<bool> deleteOfflineChapterReal(String mangaName, String chapterName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chapterPath = '${dir.path}/$mangaName/$chapterName';
      final chapterDir = Directory(chapterPath);
      
      if (!chapterDir.existsSync()) {
        print('DEBUG: ❌ Capitolo non esistente: $chapterPath');
        return false;
      }
      
      // Calcola spazio prima dell'eliminazione
      int totalSize = 0;
      int fileCount = 0;
      
      final files = chapterDir.listSync(recursive: true).whereType<File>();
      for (var file in files) {
        totalSize += await file.length();
        fileCount++;
      }
      
      final sizeMB = totalSize / (1024 * 1024);
      print('DEBUG: 📊 Trovati $fileCount file, ${sizeMB.toStringAsFixed(2)} MB');
      
      // ELIMINAZIONE FISICA
      await chapterDir.delete(recursive: true);
      
      // Verifica eliminazione
      bool reallyDeleted = !chapterDir.existsSync();
      
      if (reallyDeleted) {
        print('DEBUG: ✅ ELIMINATO FISICAMENTE: $chapterPath');
        print('DEBUG: 💾 MEMORIA LIBERATA: ${sizeMB.toStringAsFixed(2)} MB');
        
        // Aggiorna UI
        await loadChapterList(mangaName);
        
        return true;
      } else {
        print('DEBUG: ❌ ERRORE: File non eliminati fisicamente!');
        return false;
      }
      
    } catch (e) {
      print('DEBUG: ❌ ERRORE eliminazione: $e');
      return false;
    }
  }

  /// Calcola la dimensione in MB di un capitolo offline
  Future<double> getChapterSizeMB(String mangaName, String chapterName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chapterDir = Directory('${dir.path}/$mangaName/$chapterName');
      
      if (!chapterDir.existsSync()) return 0.0;
      
      int totalSize = 0;
      final files = chapterDir.listSync(recursive: true).whereType<File>();
      
      for (var file in files) {
        totalSize += await file.length();
      }
      
      return totalSize / (1024 * 1024); // Ritorna MB
      
    } catch (e) {
      print('DEBUG: Errore calcolo dimensione: $e');
      return 0.0;
    }
  }

  /// Test completo di eliminazione con verifica
  Future<void> testChapterDeletion(String mangaName, String chapterName) async {
    print('DEBUG: 🧪 === INIZIO TEST ELIMINAZIONE ===');
    print('DEBUG: Manga: $mangaName, Capitolo: $chapterName');
    
    // 1. Verifica esistenza prima
    final dir = await getApplicationDocumentsDirectory();
    final chapterPath = '${dir.path}/$mangaName/$chapterName';
    final chapterDir = Directory(chapterPath);
    bool existsBefore = chapterDir.existsSync();
    
    print('DEBUG: 📁 Esistenza prima: $existsBefore');
    
    if (!existsBefore) {
      print('DEBUG: ❌ Capitolo non esiste, test terminato');
      if (mounted) {
        _showSnackBar('❌ Capitolo non trovato sul dispositivo');
      }
      return;
    }
    
    // 2. Dimensione prima
    double sizeBefore = await getChapterSizeMB(mangaName, chapterName);
    print('DEBUG: 📊 Dimensione prima: ${sizeBefore.toStringAsFixed(2)} MB');
    
    // 3. Lista file prima
    final filesBefore = chapterDir.listSync(recursive: true).whereType<File>().length;
    print('DEBUG: 📄 File prima: $filesBefore');
    
    // 4. Eliminazione
    print('DEBUG: 🗑️ Eliminando...');
    bool deleted = await deleteOfflineChapterReal(mangaName, chapterName);
    print('DEBUG: ✅ Risultato eliminazione: $deleted');
    
    // 5. Verifica dopo eliminazione
    bool existsAfter = chapterDir.existsSync();
    double sizeAfter = await getChapterSizeMB(mangaName, chapterName);
    
    print('DEBUG: 📁 Esistenza dopo: $existsAfter');
    print('DEBUG: 📊 Dimensione dopo: ${sizeAfter.toStringAsFixed(2)} MB');
    print('DEBUG: 💾 Memoria liberata: ${(sizeBefore - sizeAfter).toStringAsFixed(2)} MB');
    
    // 6. Risultato finale
    if (!existsAfter && sizeAfter == 0.0) {
      print('DEBUG: ✅ TEST PASSATO: Capitolo eliminato fisicamente!');
      
      if (mounted) {
        _showSnackBar('✅ Capitolo eliminato! Liberati ${sizeBefore.toStringAsFixed(2)} MB');
      }
    } else {
      print('DEBUG: ❌ TEST FALLITO: Capitolo non eliminato completamente!');
      
      if (mounted) {
        _showSnackBar('❌ Errore: Capitolo non eliminato completamente!');
      }
    }
    
    print('DEBUG: 🧪 === FINE TEST ELIMINAZIONE ===');
  }

  /// Ottieni informazioni complete su storage offline
  Future<Map<String, dynamic>> getOfflineStorageInfo(String mangaName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mangaDir = Directory('${dir.path}/$mangaName');
      
      if (!mangaDir.existsSync()) {
        return {
          'exists': false,
          'totalSize': 0,
          'totalFiles': 0,
          'chapters': <Map<String, dynamic>>[]
        };
      }
      
      int totalSize = 0;
      int totalFiles = 0;
      List<Map<String, dynamic>> chaptersInfo = [];
      
      // Analizza ogni capitolo
      final chapters = mangaDir.listSync().whereType<Directory>();
      for (var chapterDir in chapters) {
        final chapterName = chapterDir.path.split('/').last;
        
        int chapterSize = 0;
        int chapterFiles = 0;
        
        final files = chapterDir.listSync().whereType<File>();
        for (var file in files) {
          final size = await file.length();
          chapterSize += size;
          chapterFiles++;
        }
        
        totalSize += chapterSize;
        totalFiles += chapterFiles;
        
        chaptersInfo.add({
          'name': chapterName,
          'size': chapterSize,
          'files': chapterFiles,
          'sizeMB': chapterSize / (1024 * 1024),
        });
      }
      
      return {
        'exists': true,
        'totalSize': totalSize,
        'totalFiles': totalFiles,
        'totalSizeMB': totalSize / (1024 * 1024),
        'chapters': chaptersInfo,
      };
      
    } catch (e) {
      print('DEBUG: Errore nel calcolo spazio storage: $e');
      return {
        'exists': false,
        'totalSize': 0,
        'totalFiles': 0,
        'error': e.toString()
      };
    }
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
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  0.725, // Ridotto ulteriormente per dare più spazio verticale
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
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Info storage button
                      IconButton(
                        icon: const Icon(Icons.storage, color: Colors.orange, size: 20),
                        onPressed: () async {
                          final size = await getChapterSizeMB(selectedManga!, chapter);
                          if (!mounted) return;
                          
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              title: const Text('📊 Info Capitolo', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manga: $selectedManga',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Capitolo: $chapter',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '💾 Spazio occupato: ${size.toStringAsFixed(2)} MB',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Chiudi', style: TextStyle(color: Colors.grey)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Test delete button
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                        onPressed: () async {
                          // Dialog di conferma
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              title: const Text('🧪 Test Eliminazione', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Vuoi testare l\'eliminazione del capitolo?',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Manga: $selectedManga',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Capitolo: $chapter',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '⚠️ ATTENZIONE: Questo eliminerà FISICAMENTE il capitolo dal dispositivo!',
                                    style: TextStyle(color: Colors.red[300], fontSize: 12),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('🧪 Test Elimina', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirm == true) {
                            await testChapterDeletion(selectedManga!, chapter);
                          }
                        },
                      ),
                      // Freccia per entrare nel capitolo
                      const Icon(Icons.chevron_right, color: Colors.deepPurple),
                    ],
                  ),
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
                              Text(
                                'Immagine ${index + 1}',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
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
        content: Text(
            'Sei sicuro di voler eliminare "$mangaName" e tutti i suoi capitoli?'),
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final profiles = sharedPrefs.isInitialized
                ? sharedPrefs.getServerProfiles()
                : {'Remoto': 'http://80.97.160.102:8000'};
            
            // Assicuriamoci che profiles non sia vuoto
            if (profiles.isEmpty) {
              profiles['Remoto'] = 'http://80.97.160.102:8000';
            }
            
            final activeProfile = sharedPrefs.isInitialized
                ? sharedPrefs.getActiveServerProfile()
                : 'Remoto';
            
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.settings, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Profili Server',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profili Salvati:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap per attivare, usa i pulsanti per modificare/eliminare',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 200,
                      child: ListView.builder(
                        itemCount: profiles.length,
                        itemBuilder: (context, index) {
                          if (index >= profiles.length) {
                            return SizedBox.shrink(); // Sicurezza extra
                          }
                          final entries = profiles.entries.toList();
                          if (index >= entries.length) {
                            return SizedBox.shrink();
                          }
                          final entry = entries[index];
                          final isActive = entry.key == activeProfile;
                          
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isActive ? Colors.deepPurple : Colors.grey[300]!,
                                width: isActive ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: isActive ? Colors.deepPurple.withOpacity(0.1) : null,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive ? Colors.deepPurple : Colors.grey[400],
                                child: Text(
                                  entry.key[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                entry.value,
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isActive)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Attivo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (!isActive)
                                    TextButton(
                                      onPressed: () {
                                        _setActiveProfile(entry.key);
                                        setDialogState(() {});
                                      },
                                      child: Text('Usa', style: TextStyle(fontSize: 12)),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () {
                                      _showEditProfileDialog(entry.key, entry.value, setDialogState);
                                    },
                                    tooltip: 'Modifica profilo',
                                  ),
                                  if (profiles.length > 1)
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () {
                                        _removeProfile(entry.key);
                                        setDialogState(() {});
                                      },
                                      tooltip: 'Elimina profilo',
                                    ),
                                ],
                              ),
                              onTap: () {
                                if (!isActive) {
                                  _setActiveProfile(entry.key);
                                  setDialogState(() {});
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Chiudi'),
                ),
                ElevatedButton(
                  onPressed: () => _showAddProfileDialog(setDialogState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Nuovo Profilo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProfileDialog([Function? updateParentDialog]) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Nuovo Profilo Server'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nome Profilo',
                  hintText: 'es. Locale, Casa, Ufficio',
                  prefixIcon: Icon(Icons.label, color: Colors.deepPurple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL Server',
                  hintText: 'http://192.168.1.100:8000',
                  prefixIcon: Icon(Icons.language, color: Colors.deepPurple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.url,
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Esempi:\n• Locale: http://192.168.1.100:8000\n• Remoto: http://80.97.160.102:8000',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                _addNewProfile(nameController.text.trim(), urlController.text.trim(), updateParentDialog);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Aggiungi'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog(String currentName, String currentUrl, [Function? updateParentDialog]) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final TextEditingController urlController = TextEditingController(text: currentUrl);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Modifica Profilo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nome Profilo',
                  hintText: 'es. Locale, Casa, Ufficio',
                  prefixIcon: Icon(Icons.label, color: Colors.deepPurple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL Server',
                  hintText: 'http://192.168.1.100:8000',
                  prefixIcon: Icon(Icons.language, color: Colors.deepPurple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.url,
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange[700]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Stai modificando il profilo "$currentName".\nLe modifiche saranno applicate immediatamente.',
                        style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateProfile(currentName, nameController.text.trim(), urlController.text.trim(), updateParentDialog);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  void _setActiveProfile(String profileName) {
    if (sharedPrefs.isInitialized) {
      sharedPrefs.setActiveServerProfile(profileName);
      final url = sharedPrefs.getServerUrl();
      print('DEBUG: Profilo cambiato a $profileName con URL: $url');
      _showSnackBar('Profilo attivo: $profileName ($url)');
      setState(() {}); // Aggiorna l'UI
    } else {
      _showSnackBar('Errore: SharedPreferences non inizializzato');
    }
  }

  void _addNewProfile(String name, String url, [Function? updateParentDialog]) {
    if (name.isEmpty || url.isEmpty) {
      _showSnackBar('Nome e URL sono obbligatori');
      return;
    }
    
    // Aggiunge http:// se mancante
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    
    if (sharedPrefs.isInitialized) {
      sharedPrefs.addServerProfile(name, url);
      _showSnackBar('Profilo "$name" aggiunto con successo');
      
      // Aggiorna il dialog padre se disponibile
      if (updateParentDialog != null) {
        updateParentDialog(() {});
      }
    } else {
      _showSnackBar('Errore: SharedPreferences non inizializzato');
    }
  }

  void _removeProfile(String profileName) {
    if (sharedPrefs.isInitialized) {
      sharedPrefs.removeServerProfile(profileName);
      _showSnackBar('Profilo "$profileName" eliminato');
    } else {
      _showSnackBar('Errore: SharedPreferences non inizializzato');
    }
  }

  void _updateProfile(String oldName, String newName, String newUrl, [Function? updateParentDialog]) {
    if (newName.isEmpty || newUrl.isEmpty) {
      _showSnackBar('Nome e URL sono obbligatori');
      return;
    }
    
    // Aggiunge http:// se mancante
    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      newUrl = 'http://$newUrl';
    }
    
    if (sharedPrefs.isInitialized) {
      sharedPrefs.updateServerProfile(oldName, newName, newUrl);
      _showSnackBar('Profilo aggiornato: "$newName"');
      
      // Aggiorna il dialog padre se disponibile
      if (updateParentDialog != null) {
        updateParentDialog(() {});
      }
      
      setState(() {}); // Aggiorna l'UI principale
    } else {
      _showSnackBar('Errore: SharedPreferences non inizializzato');
    }
  }

  void _debugProfiles() {
    if (!sharedPrefs.isInitialized) {
      _showSnackBar('SharedPrefs non inizializzato');
      return;
    }
    
    final profiles = sharedPrefs.getServerProfiles();
    final activeProfile = sharedPrefs.getActiveServerProfile();
    final currentUrl = sharedPrefs.getServerUrl();
    
    print('=== DEBUG PROFILI ===');
    print('Profilo attivo: $activeProfile');
    print('URL corrente: $currentUrl');
    print('Tutti i profili:');
    profiles.forEach((name, url) {
      print('  $name: $url ${name == activeProfile ? "(ATTIVO)" : ""}');
    });
    print('==================');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Profili'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profilo attivo: $activeProfile', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('URL corrente: $currentUrl'),
            SizedBox(height: 16),
            Text('Tutti i profili:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...profiles.entries.map((entry) => Padding(
              padding: EdgeInsets.only(left: 16, top: 4),
              child: Text('${entry.key}: ${entry.value}'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Chiudi'),
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
          // Storage info button quando si è in un manga specifico
          if (selectedManga != null)
            IconButton(
              icon: const Icon(Icons.storage, color: Colors.orange),
              onPressed: () async {
                final storageInfo = await getOfflineStorageInfo(selectedManga!);
                
                if (!mounted) return;
                
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2A2A2A),
                    title: const Text('📊 Info Storage Manga', style: TextStyle(color: Colors.white)),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manga: $selectedManga',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (storageInfo['exists']) ...[
                            Text(
                              '💾 Spazio totale: ${storageInfo['totalSizeMB'].toStringAsFixed(2)} MB',
                              style: const TextStyle(color: Colors.green),
                            ),
                            Text(
                              '📄 File totali: ${storageInfo['totalFiles']}',
                              style: const TextStyle(color: Colors.blue),
                            ),
                            Text(
                              '📖 Capitoli: ${storageInfo['chapters'].length}',
                              style: const TextStyle(color: Colors.cyan),
                            ),
                            const SizedBox(height: 16),
                            const Text('Dettaglio capitoli:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...storageInfo['chapters'].map<Widget>((chapter) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      chapter['name'],
                                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    '${chapter['sizeMB'].toStringAsFixed(1)} MB',
                                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ] else ...[
                            const Text(
                              'Nessun capitolo offline trovato',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Chiudi', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                );
              },
            ),
          PopupMenuButton<String>(
            icon: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dns, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    sharedPrefs.isInitialized 
                        ? sharedPrefs.getActiveServerProfile()
                        : 'Remoto',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                ],
              ),
            ),
            tooltip: 'Cambia profilo server',
            onSelected: (String profileName) {
              _setActiveProfile(profileName);
            },
            itemBuilder: (BuildContext context) {
              final profiles = sharedPrefs.isInitialized 
                  ? sharedPrefs.getServerProfiles()
                  : {'Remoto': 'http://80.97.160.102:8000'};
              
              // Assicuriamoci che profiles non sia vuoto
              if (profiles.isEmpty) {
                profiles['Remoto'] = 'http://80.97.160.102:8000';
              }
              
              final activeProfile = sharedPrefs.isInitialized 
                  ? sharedPrefs.getActiveServerProfile()
                  : 'Remoto';
              
              return profiles.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: entry.key == activeProfile 
                            ? Colors.deepPurple 
                            : Colors.grey[400],
                        child: Text(
                          entry.key[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontWeight: entry.key == activeProfile 
                                          ? FontWeight.bold 
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (entry.key == activeProfile) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'ATTIVO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // Chiudi il popup
                                    _showEditProfileDialog(entry.key, entry.value);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, size: 28),
            tooltip: 'Gestisci profili',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: Icon(Icons.bug_report, size: 24),
            tooltip: 'Debug profili',
            onPressed: () {
              _debugProfiles();
            },
          ),
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
