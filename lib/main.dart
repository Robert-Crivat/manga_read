import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/model/novels/novel_models.dart';
import 'package:manga_read/screen/homepage.dart';
import 'package:manga_read/screen/manga/OfflinePage.dart';
import 'package:manga_read/service/shared_prefs.dart';

final sharedPrefs = SharedPrefs();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sharedPrefs.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((fn){runApp(const MyApp());});
  
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLoading = true;
  List<MangaSearchModel> mangaList = [];
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  List<NovelModels> novelList = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  _initializeApp() async {
    // Carica dati API in parallelo
    try {
      await Future.wait([
        // Fetch Manga
        mangaWorldApi.latestRelease().then((results) {
          if (mounted && results.status == "ok") {
            for (var manga in results.parametri) {
              mangaList.add(MangaSearchModel.fromJson(manga));
            }
          }
        }),
        // Fetch Novels
        // webNovelsApi.getAllNovels().then((results) {
        //   if (mounted && results.status == "ok") {
        //     for (var novel in results.parametri) {
        //       novelList.add(NovelModels.fromJson(novel));
        //     }
        //   }
        // }),
      ]);
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      // Opzionale: mostrare una snackbar o un messaggio di errore all'utente
    }

    if (!mounted) return;
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _reloadManga() async {
    setState(() {
      isLoading = true;
    });

    try {
      var results = await mangaWorldApi.latestRelease();
      if (mounted && results.status == "ok") {
        setState(() {
          mangaList.clear();
          for (var manga in results.parametri) {
            mangaList.add(MangaSearchModel.fromJson(manga));
          }
        });
      }
    } catch (e) {
      debugPrint("Error reloading manga: $e");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Reader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          primary: Colors.deepPurple[300],
          surface: const Color(0xFF1A1A1A),
          background: const Color(0xFF121212),
          error: Colors.redAccent,
        ),
        cardColor: const Color(0xFF2A2A2A),
        canvasColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple[600],
            foregroundColor: Colors.white,
            elevation: 5,
            shadowColor: Colors.black.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: isLoading
          ? Scaffold(
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.shade900,
                      Colors.deepPurple.shade600,
                      Colors.deepPurple.shade300,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder(
                        duration: const Duration(seconds: 2),
                        tween: Tween<double>(begin: 0.5, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, double scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.deepPurple.shade200],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 5,
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.book,
                                size: 50,
                                color: Colors.deepPurple,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Caricamento in corso...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(1, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfflinePage(
                        onBackToOnline: _reloadManga,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.download),
              ),
            )
          : MyHomePage(
              novelList: novelList,
              mangaList: mangaList,
              title: 'Manga Reader',
              reloadManga: _reloadManga,
            ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final List<MangaSearchModel> mangaList;
  final List<NovelModels> novelList;
  final Future<void> Function() reloadManga;

  const MyHomePage({
    super.key,
    required this.title,
    required this.mangaList,
    required this.novelList,
    required this.reloadManga,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Homepage(
      novels: widget.novelList,
      mangalist: widget.mangaList,
      reloadManga: widget.reloadManga,
    );
  }
}
