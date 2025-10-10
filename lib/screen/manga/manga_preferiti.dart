import 'package:flutter/material.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/manga_detail_screen.dart';

class MangaPreferitiScreen extends StatefulWidget {
  const MangaPreferitiScreen({Key? key}) : super(key: key);

  @override
  _MangaPreferitiScreenState createState() => _MangaPreferitiScreenState();
}

class _MangaPreferitiScreenState extends State<MangaPreferitiScreen> {
  List<MangaSearchModel> mangaPreferiti = [];

  @override
  void initState() {
    super.initState();
    getPref();
  }

  getPref() async {
    await sharedPrefs.init();
    List<String> mangaPrefList = sharedPrefs.mangaPref;
    List<String> mangaPrefUrlImgList = sharedPrefs.mangaPrefurlImg;
    List<String> mangaPrefUrlList = sharedPrefs.mangaPrefurl;
    mangaPreferiti.clear();

    if (mangaPrefList.isNotEmpty &&
        mangaPrefUrlImgList.isNotEmpty &&
        mangaPrefUrlList.isNotEmpty) {
      int itemCount = [
        mangaPrefList.length,
        mangaPrefUrlImgList.length,
        mangaPrefUrlList.length,
      ].reduce((a, b) => a < b ? a : b);
      for (int i = 0; i < itemCount; i++) {
        MangaSearchModel manga = MangaSearchModel(
          title: mangaPrefList[i],
          img: mangaPrefUrlImgList[i],
          url: mangaPrefUrlList[i],
          story: "",
          status: "",
          type: "",
          genres: "",
          author: "",
          artist: "",
        );
        mangaPreferiti.add(manga);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manga Preferiti',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: mangaPreferiti.isEmpty
          ? Center(
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.withOpacity(0.1),
                            Colors.purpleAccent.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        size: 100,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Nessun manga tra i preferiti',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aggiungi manga ai preferiti\nper trovarli qui',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
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
                        '${mangaPreferiti.length} ${mangaPreferiti.length == 1 ? "Manga" : "Manga"}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_left,
                              size: 16,
                              color: Colors.deepPurple[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Swipe per eliminare',
                              style: TextStyle(
                                color: Colors.deepPurple[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: mangaPreferiti.length,
                    itemBuilder: (context, index) {
                      MangaSearchModel manga = mangaPreferiti[index];
                      return TweenAnimationBuilder(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        tween: Tween<double>(begin: 0, end: 1),
                        curve: Curves.easeOut,
                        builder: (context, double value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(30 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: Dismissible(
                          key: Key(manga.url),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.red, Colors.redAccent],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_sweep,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Elimina',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (direction) async {
                            final success = await sharedPrefs.removeMangaFromFavorites(
                              url: manga.url,
                            );

                            if (success) {
                              setState(() {
                                mangaPreferiti.removeAt(index);
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('${manga.title} rimosso dai preferiti'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Hero(
                            tag: 'manga_${manga.url}_favorites',
                            child: Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          MangaDetailScreen(manga: manga),
                                      transitionsBuilder:
                                          (context, animation, secondaryAnimation, child) {
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
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      // Manga Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: manga.img.isNotEmpty
                                            ? Image.network(
                                                manga.img,
                                                width: 70,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 70,
                                                    height: 100,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.deepPurple[300]!,
                                                          Colors.deepPurple[500]!,
                                                        ],
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.book,
                                                      color: Colors.white,
                                                      size: 40,
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                width: 70,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.deepPurple[300]!,
                                                      Colors.deepPurple[500]!,
                                                    ],
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.book,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Manga Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              manga.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Colors.deepPurple, Colors.purpleAccent],
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.favorite,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Preferito',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Arrow Icon
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[400],
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
