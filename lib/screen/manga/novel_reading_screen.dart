import 'package:flutter/material.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chapter.dart';
import 'package:manga_read/service/shared_prefs.dart';

class NovelReadingScreen extends StatefulWidget {
  final String novelSlug;
  final String chapterId;
  final String title;

  const NovelReadingScreen({
    Key? key,
    required this.novelSlug,
    required this.chapterId,
    required this.title,
  }) : super(key: key);

  @override
  _NovelReadingScreenState createState() => _NovelReadingScreenState();
}

class _NovelReadingScreenState extends State<NovelReadingScreen> {
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  final SharedPrefs _prefs = SharedPrefs();
  NovelChapterContent? chapterContent;
  bool isLoading = true;
  bool isDarkMode = false;
  double fontSize = 16.0;

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
      DataManager result = await webNovelsApi.getChapterContent(
        widget.novelSlug,
        widget.chapterId,
      );

      if (result.status == 'ok' && result.parametri != null) {
        setState(() {
          chapterContent = NovelChapterContent.fromJson(result.parametri);
          isLoading = false;
        });
      } else {
        _showError('Failed to load chapter content');
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () async {
              bool newMode = !isDarkMode;
              await _prefs.setDarkMode(newMode);
              setState(() {
                isDarkMode = newMode;
              });
            },
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            onSelected: (double value) {
              setState(() {
                fontSize = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
              const PopupMenuItem<double>(
                value: 14.0,
                child: Text('Small'),
              ),
              const PopupMenuItem<double>(
                value: 16.0,
                child: Text('Medium'),
              ),
              const PopupMenuItem<double>(
                value: 18.0,
                child: Text('Large'),
              ),
              const PopupMenuItem<double>(
                value: 20.0,
                child: Text('Extra Large'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chapterContent == null
              ? const Center(child: Text('No chapter content available'))
              : _buildChapterContent(),
    );
  }

  Widget _buildChapterContent() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapterContent!.title,
              style: TextStyle(
                fontSize: fontSize + 4,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...chapterContent!.content.map((paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    paragraph,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.5,
                    ),
                  ),
                )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
