import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/manga/manga_search_model.dart';
import 'package:manga_read/model/novels/novel_models.dart';
import 'package:manga_read/screen/homepage.dart';
import 'package:manga_read/screen/manga/OfflinePage.dart';
import 'package:manga_read/service/shared_prefs.dart';
import 'package:translator/translator.dart';

final sharedPrefs = SharedPrefs();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final translator = GoogleTranslator();
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
          const SnackBar(content: Text("Nessun manga trovato"))
        );
      }
    } catch (e) {
      debugPrint("Error fetching all manga: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore nel caricamento: $e"))
        );
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
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          primary: Colors.deepPurple[300],
          surface: const Color(0xFF121212),
          background: const Color(0xFF121212),
          error: Colors.redAccent,
        ),
        cardColor: const Color(0xFF1E1E1E),
        canvasColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: !isInitialized || isLoading == true || isLoadingNovel == true
          ? Builder(
              builder: (context) => Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            Text(
                              "Manga in caricamente, si prega di attendere...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                            ElevatedButton(onPressed: (){Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OfflinePage()));}, child: Text("Accedi Offline"))

                          ],
                        ),
                      ),
                    ),
                    floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
                    floatingActionButton: isInitialized ? Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: FloatingActionButton(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Aggiornamento dati in corso...")),
                          );
                          await allManga();
                          await allNoverls();
                          if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Dati aggiornati con successo!")),
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
                                String newUrl = urlController.text.trim();
                                if (newUrl.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                  content: Text('Please enter a valid URL'),
                                  ),
                                );
                                return;
                                }
                                
                                // Salva l'URL nelle SharedPreferences
                                bool saved = await sharedPrefs.setUrl(newUrl);
                                
                                if (!saved) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                  content: Text('Failed to save URL'),
                                  backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                                }
                                
                                // Aggiorna la variabile locale
                                setState(() {
                                url = newUrl;
                                });
                                
                                print('URL saved: ${sharedPrefs.url}');
                                Navigator.pop(context);
                                
                                if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                  content: Text('API URL updated successfully: $newUrl'),
                                  duration: const Duration(seconds: 3),
                                  ),
                                );
                                }
                              } catch (e) {
                                print('Error saving URL: $e');
                                Navigator.pop(context);
                                if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                  content: Text('Error saving URL: $e'),
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
                    ) : null
                  ))
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
