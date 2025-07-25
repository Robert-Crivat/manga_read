import 'package:flutter/material.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chaprter_content.dart';
import 'package:translator/translator.dart';
import 'package:manga_read/service/shared_prefs.dart';

class NovelReadingScreen extends StatefulWidget {
  final String chapterUrl;
  final String title;
  final String? prevChapterUrl;
  final String? nextChapterUrl;

  const NovelReadingScreen({
    Key? key,
    required this.chapterUrl,
    required this.title,
    this.prevChapterUrl,
    this.nextChapterUrl,
  }) : super(key: key);

  @override
  _NovelReadingScreenState createState() => _NovelReadingScreenState();
}

class _NovelReadingScreenState extends State<NovelReadingScreen> {
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  final SharedPrefs _prefs = SharedPrefs();
  NovelChaprterContent? chapterContent;
  bool isLoading = true;
  bool isDarkMode = false;
  bool isInTranslate = false;
  double fontSize = 16.0;
  String translationMode = 'default'; // Opzioni: default, dynamic, robust, lore
  late GoogleTranslator translator;
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadChapterContent();
  }

  _loadSettings() async {
    bool darkMode = await _prefs.getDarkMode();
    setState(() {
      isDarkMode = darkMode;
      // Default font size, could be stored in SharedPrefs as well
      fontSize = 16.0;
    });
  }

  _loadChapterContent() async {
    setState(() {
      isLoading = true;
    });

    try {
      DataManager reponse = await webNovelsApi.getNovelFireChapterContent(
        widget.chapterUrl,
        translationMode: translationMode,
      );

      if (reponse.parametri.isNotEmpty) {
        chapterContent = NovelChaprterContent.fromJson(reponse.parametri);
        // Translate to Italian
        setState(() {
          isInTranslate = true;
        });
        final translatedContent =
            await chapterContent!.translateContent(from: 'en', to: 'it');

        if (translatedContent.content.isNotEmpty) {
          setState(() {
            isInTranslate = false;
            chapterContent!.content = translatedContent.content;
          });
        }
      } else {
        chapterContent = null;
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      _showError('Error: $e');
    }
  }

  _showError(String message) {
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _changeTranslationMode(String mode) {
    if (mode != translationMode) {
      setState(() {
        translationMode = mode;
      });
      _loadChapterContent(); // Ricarica il contenuto con la nuova modalità di traduzione
    }
  }

  void _navigateToChapter(String? url, String direction) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nessun capitolo $direction disponibile')),
      );
      return;
    }

    String title = direction == 'precedente'
        ? 'Capitolo Precedente'
        : 'Capitolo Successivo';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NovelReadingScreen(
          chapterUrl: url,
          title: title,
          prevChapterUrl: direction == 'successivo' ? widget.chapterUrl : null,
          nextChapterUrl: direction == 'precedente' ? widget.chapterUrl : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Pulsante per la traduzione
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            tooltip: 'Modalità traduzione',
            onSelected: _changeTranslationMode,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'default',
                child: Text('Default'),
              ),
              const PopupMenuItem<String>(
                value: 'dynamic',
                child: Text('Dynamic'),
              ),
              const PopupMenuItem<String>(
                value: 'robust',
                child: Text('Robust'),
              ),
              const PopupMenuItem<String>(
                value: 'lore',
                child: Text('Lore'),
              ),
            ],
          ),
          // Pulsante per modalità scura
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Modalità chiara' : 'Modalità scura',
            onPressed: () async {
              bool newMode = !isDarkMode;
              await _prefs.setDarkMode(newMode);
              setState(() {
                isDarkMode = newMode;
              });
            },
          ),
          // Pulsante per dimensione testo
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Dimensione testo',
            onSelected: (double value) {
              setState(() {
                fontSize = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
              const PopupMenuItem<double>(
                value: 14.0,
                child: Text('Piccolo'),
              ),
              const PopupMenuItem<double>(
                value: 16.0,
                child: Text('Medio'),
              ),
              const PopupMenuItem<double>(
                value: 18.0,
                child: Text('Grande'),
              ),
              const PopupMenuItem<double>(
                value: 20.0,
                child: Text('Extra Grande'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isInTranslate
                    ? Icon(
                        Icons.translate,
                        size: 25,
                      )
                    : CircularProgressIndicator(),
                isInTranslate
                    ? Text('Traduzione in corso...')
                    : Text('Caricamento capitolo...'),
              ],
            ))
          : chapterContent == null
              ? const Center(child: Text('Nessun contenuto disponibile'))
              : _buildChapterContent(),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Precedente'),
            onPressed: /* chapterContent?.prevChapter != null
                ? () => _navigateToChapter(chapterContent!.prevChapter, 'precedente')
                :*/
                null,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Successivo'),
            onPressed: /*chapterContent?.nextChapter != null
                ? () => _navigateToChapter(chapterContent!.nextChapter, 'successivo')
                : */
                null,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterContent() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo del capitolo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                chapterContent!.chapterTitle,
                style: TextStyle(
                  fontSize: fontSize + 6,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Badge che mostra la modalità di traduzione attiva
            if (translationMode != 'default')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Chip(
                  label: Text('Traduzione: ${translationMode.toUpperCase()}'),
                  backgroundColor: Colors.blue.shade100,
                ),
              ),

            // Contenuto del capitolo paragrafo per paragrafo
            ...chapterContent!.content.split('\n\n').map((paragraph) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  paragraph,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.5,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
