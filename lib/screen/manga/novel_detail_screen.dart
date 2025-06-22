import 'package:flutter/material.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chapter.dart';
import 'package:manga_read/model/novels/novel_models.dart';
import 'package:manga_read/screen/manga/novel_reading_screen.dart';
import 'package:manga_read/service/shared_prefs.dart';

class NovelDetailScreen extends StatefulWidget {
  final NovelModels novel;

  const NovelDetailScreen({Key? key, required this.novel}) : super(key: key);

  @override
  _NovelDetailScreenState createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  final SharedPrefs _prefs = SharedPrefs();
  List<NovelChapter> chapters = [];
  bool isLoading = true;
  bool isDarkMode = false;
  String novelSlug = '';

  @override
  void initState() {
    super.initState();
    novelSlug = widget.novel.getSlug();
    _loadSettings();
    _loadChapters();
  }

  _loadSettings() async {
    bool darkMode = await _prefs.getDarkMode();
    setState(() {
      isDarkMode = darkMode;
    });
  }

  _loadChapters() async {
    setState(() {
      isLoading = true;
    });

    try {
      DataManager result = await webNovelsApi.getNovelChapters(novelSlug);

      if (result.status == 'ok' && result.parametri != null) {
        setState(() {
          if (result.parametri is List) {
            for (var chapter in result.parametri) {
              chapters.add(NovelChapter.fromJson(chapter));
            }
          } else if (result.parametri['data'] is List) {
            for (var chapter in result.parametri['data']) {
              chapters.add(NovelChapter.fromJson(chapter));
            }
          }
          isLoading = false;
        });
      } else {
        _showError('Failed to load chapters');
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
        title: Text(widget.novel.title ?? 'Novel Detail'),
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
        ],
      ),
      body: Column(
        children: [
          // Novel image and title section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Novel image
                Container(
                  height: 180,
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.novel.img != null
                      ? Image.network(
                          widget.novel.img!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                ),
                const SizedBox(width: 16),
                // Novel info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.novel.title ?? 'No Title',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      if (widget.novel.status != null)
                        Text(
                          'Status: ${widget.novel.status}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 8),
                      if (widget.novel.description != null)
                        Text(
                          widget.novel.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chapter list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chapters',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${chapters.length} chapters',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const Divider(),

          // Chapters list (scrollable)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chapters.isEmpty
                    ? const Center(child: Text('No chapters found'))
                    : _buildChaptersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList() {
    // Group chapters if there are many
    if (chapters.length > 100) {
      return ListView.builder(
        itemCount: ((chapters.length - 1) ~/ 100) + 1,
        itemBuilder: (context, groupIndex) {
          int startIndex = groupIndex * 100;
          int endIndex = (groupIndex + 1) * 100;
          if (endIndex > chapters.length) endIndex = chapters.length;

          return ExpansionTile(
            title: Text('Chapters ${startIndex + 1} - $endIndex'),
            shape: const Border(),
            collapsedShape: const Border(),
            children: List.generate(endIndex - startIndex, (i) {
              int index = startIndex + i;
              var chapter = chapters[index];
              return _buildChapterTile(chapter, index);
            }),
          );
        },
      );
    } else {
      // If there are fewer chapters, display them directly
      return ListView.builder(
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          return _buildChapterTile(chapters[index], index);
        },
      );
    }
  }

  Widget _buildChapterTile(NovelChapter chapter, int index) {
    return ListTile(
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text(chapter.title),
      subtitle: chapter.date != null ? Text(chapter.date!) : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NovelReadingScreen(
              novelSlug: novelSlug,
              chapterId: chapter.chapterId,
              title: chapter.title,
            ),
          ),
        );
      },
    );
  }
}
