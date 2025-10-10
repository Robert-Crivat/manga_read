import 'package:flutter/material.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;
  bool isLoading = false;
  bool isInitialized = false;
  List<MangaSearchModel> mangaList = [];
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final WebNovelsApi webNovelsApi = WebNovelsApi();
  bool isLoadingNovel = false;
  List<NovelModels> novelList = [];
  String url = "";
  late TextEditingController urlController;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  _initializeApp() async {
    url = sharedPrefs.url;
    urlController = TextEditingController(text: url);
    await _loadThemePreference();
    setState(() {
      isInitialized = true;
    });
    await allManga();
    await allNoverls();
  }

  @override
  void dispose() {
    if (isInitialized) {
      urlController.dispose();
    }
    super.dispose();
  }

  _loadThemePreference() async {
    bool isDark = await sharedPrefs.getDarkMode();
    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await sharedPrefs.setDarkMode(_isDarkMode);
  }

  allManga() async {
    setState(() {
      isLoading = true;
    });
    try {
      setState(() {
        mangaList.clear(); // Clear previous results
      });

      var results = await mangaWorldApi.getAllManga();
      if (!mounted) return;

      if (results.status == "ok") {
        setState(() {
          for (var manga in results.parametri) {
            mangaList.add(MangaSearchModel.fromJson(manga));
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nessun manga trovato")));
      }
    } catch (e) {
      debugPrint("Error fetching all manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Errore nel caricamento: $e")));
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  allNoverls() async {
    setState(() {
      isLoadingNovel = true;
    });
    try {
      setState(() {
        novelList.clear();
      });

      var results = await webNovelsApi.getAllNovels();
      if (!mounted) return;

      if (results.status == "ok") {
        setState(() {
          for (var novel in results.parametri) {
            novelList.add(NovelModels.fromJson(novel));
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Nessuna novel trovata")));
        }
      }
    } catch (e) {
      debugPrint("Error fetching all novels: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Errore nel caricamento: $e")));
      }
    }
    if (mounted) {
      setState(() {
        isLoadingNovel = false;
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
          brightness: Brightness.light,
          primary: Colors.deepPurple,
          secondary: Colors.purpleAccent,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          primary: Colors.deepPurple[300]!,
          secondary: Colors.purpleAccent[200]!,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
          error: Colors.redAccent,
        ),
        cardColor: const Color(0xFF1E1E1E),
        canvasColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple[300]!, width: 2),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: !isInitialized || isLoading == true || isLoadingNovel == true
          ? Builder(
              builder: (context) => Scaffold(
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isDarkMode
                            ? [
                                const Color(0xFF1a1a2e),
                                const Color(0xFF16213e),
                                const Color(0xFF0f3460),
                              ]
                            : [
                                Colors.deepPurple.shade100,
                                Colors.purple.shade200,
                                Colors.deepPurple.shade300,
                              ],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo o icona animata
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, double value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple.withOpacity(0.3),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // Indicatore di caricamento moderno
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isDarkMode ? Colors.white : Colors.deepPurple,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Testo con animazione fade-in
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1200),
                              builder: (context, double value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Text(
                                    "Caricamento in corso...",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: _isDarkMode ? Colors.white : Colors.deepPurple.shade900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Preparazione dei contenuti...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _isDarkMode 
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.deepPurple.shade700.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Pulsante offline con design moderno
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple.shade400,
                                    Colors.purple.shade600,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OfflinePage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.wifi_off_outlined, color: Colors.white),
                                label: const Text(
                                  "Accedi Offline",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.endDocked,
                  floatingActionButton: isInitialized
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: FloatingActionButton(
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Aggiornamento dati in corso...")),
                                  );
                                  await allManga();
                                  await allNoverls();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Dati aggiornati con successo!")),
                                    );
                                  }
                                },
                                child: const Icon(Icons.refresh),
                                heroTag: 'refreshButton',
                              ),
                            ),
                            FloatingActionButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Configure API URL'),
                                      content: TextField(
                                        decoration: const InputDecoration(
                                          labelText: 'Manga API URL',
                                          hintText: 'Enter manga API URL',
                                        ),
                                        controller: urlController,
                                        onChanged: (value) {
                                          setState(() {
                                            url = value;
                                          });
                                        },
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () async {
                                            try {
                                              String newUrl =
                                                  urlController.text.trim();
                                              if (newUrl.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Please enter a valid URL'),
                                                  ),
                                                );
                                                return;
                                              }

                                              // Salva l'URL nelle SharedPreferences
                                              bool saved = await sharedPrefs
                                                  .setUrl(newUrl);

                                              if (!saved) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Failed to save URL'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                                return;
                                              }

                                              // Aggiorna la variabile locale
                                              setState(() {
                                                url = newUrl;
                                              });

                                              print(
                                                  'URL saved: ${sharedPrefs.url}');
                                              Navigator.pop(context);

                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'API URL updated successfully: $newUrl'),
                                                    duration: const Duration(
                                                        seconds: 3),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              print('Error saving URL: $e');
                                              Navigator.pop(context);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Error saving URL: $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: const Icon(Icons.api),
                              heroTag: 'apiButton',
                            ),
                          ],
                        )
                      : null))
          : MyHomePage(
              novelList: novelList,
              mangaList: mangaList,
              title: 'Manga Reader',
              toggleTheme: _toggleTheme,
              isDarkMode: _isDarkMode,
            ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final Function toggleTheme;
  final bool isDarkMode;
  final List<MangaSearchModel> mangaList;
  final List<NovelModels> novelList;

  const MyHomePage({
    super.key,
    required this.title,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.mangaList,
    required this.novelList,
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
      toggleTheme: widget.toggleTheme,
      isDarkMode: widget.isDarkMode,
    );
  }
}
