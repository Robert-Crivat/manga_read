import 'package:flutter/material.dart';
import 'package:manga_read/screen/homepage.dart';
import 'package:manga_read/service/shared_prefs.dart';


final sharedPrefs = SharedPrefs();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sharedPrefs.init(); // Assicuriamo che SharedPrefs sia inizializzato
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true; // Tema scuro predefinito

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  // Carica la preferenza del tema dalle SharedPreferences
  _loadThemePreference() async {
    bool isDark = await sharedPrefs.getDarkMode();
    setState(() {
      _isDarkMode = isDark;
    });
  }

  // Aggiorna il tema
  void _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await sharedPrefs.setDarkMode(_isDarkMode);
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
      home: MyHomePage(
        title: 'Manga Reader', 
        toggleTheme: _toggleTheme, 
        isDarkMode: _isDarkMode
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final Function toggleTheme;
  final bool isDarkMode;

  const MyHomePage({
    super.key, 
    required this.title, 
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Homepage(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode);
  }
}
