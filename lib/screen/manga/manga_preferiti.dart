import 'package:flutter/material.dart';
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/screen/manga/manga_detail_screen.dart';

class MangaPreferitiScreen extends StatefulWidget {
  const MangaPreferitiScreen({super.key});

  @override
  _MangaPreferitiScreenState createState() => _MangaPreferitiScreenState();
}

class _MangaPreferitiScreenState extends State<MangaPreferitiScreen> {
  List<MangaSearchModel> mangaPreferiti = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
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
    
    setState(() => _isLoading = false);
  }

  Future<void> _removeFromFavorites(MangaSearchModel manga, int index) async {
    final success = await sharedPrefs.removeMangaFromFavorites(url: manga.url);

    if (success) {
      setState(() {
        mangaPreferiti.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${manga.title} rimosso dai preferiti',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Annulla',
            textColor: Colors.white,
            onPressed: () async {
              await sharedPrefs.addMangaToFavorites(
                title: manga.title,
                url: manga.url,
                imgUrl: manga.img,
              );
              await _loadFavorites();
            },
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
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
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border,
                  size: 80,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Nessun manga tra i preferiti',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Aggiungi manga ai preferiti per\nritrovarli facilmente qui',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.explore, size: 20),
                label: Text('Esplora Manga'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMangaCard(MangaSearchModel manga, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(50 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key('${manga.url}_$index'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Rimuovi dai preferiti'),
              content: Text('Sei sicuro di voler rimuovere "${manga.title}" dai preferiti?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Annulla', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Rimuovi',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        background: _buildDismissibleBackground(),
        secondaryBackground: _buildDismissibleBackground(),
        onDismissed: (direction) => _removeFromFavorites(manga, index),
        child: Hero(
          tag: 'manga_${manga.url}_favorites',
          child: Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _navigateToDetail(manga),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Manga Cover
                    _buildMangaCover(manga),
                    SizedBox(width: 16),
                    
                    // Manga Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manga.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 12),
                          
                          // Favorite Badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.deepPurple, Colors.purpleAccent],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite, color: Colors.white, size: 14),
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
                    
                    // Navigation Icon
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMangaCover(MangaSearchModel manga) {
    return Container(
      width: 80,
      height: 110,
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
        child: manga.img.isNotEmpty
            ? Image.network(
                manga.img,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple[100]!, Colors.purple[100]!],
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.deepPurple,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple[300]!, Colors.purple[400]!],
                      ),
                    ),
                    child: Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 40,
                    ),
                  );
                },
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple[300]!, Colors.purple[400]!],
                  ),
                ),
                child: Icon(
                  Icons.book,
                  color: Colors.white,
                  size: 40,
                ),
              ),
      ),
    );
  }

  Widget _buildDismissibleBackground() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red, Colors.redAccent],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_forever, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
            'Rimuovi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(MangaSearchModel manga) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MangaDetailScreen(manga: manga),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.withOpacity(0.05), Colors.purple.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.purpleAccent],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(width: 16),
              Text(
                'I Tuoi Preferiti',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${mangaPreferiti.length}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(Icons.swipe_left, size: 20, color: Colors.deepPurple),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scorri verso sinistra per rimuovere dai preferiti',
                    style: TextStyle(
                      color: Colors.deepPurple[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
          'Manga Preferiti',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          if (mangaPreferiti.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadFavorites,
              tooltip: 'Aggiorna',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
              ),
            )
          : mangaPreferiti.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildHeader(),
                    SizedBox(height: 8),
                    Expanded(
                      child: RefreshIndicator(
                        color: Colors.deepPurple,
                        onRefresh: _loadFavorites,
                        child: ListView.builder(
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: 20),
                          itemCount: mangaPreferiti.length,
                          itemBuilder: (context, index) {
                            return _buildMangaCard(mangaPreferiti[index], index);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
