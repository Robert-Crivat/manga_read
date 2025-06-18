import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';
import 'package:manga_read/model/manga_search_model.dart';
import 'package:manga_read/screen/detail_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      home: const MyHomePage(title: 'Manga Reader'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<MangaSearchModel> mangaList = [];
  List<Map<String, dynamic>> mangaWorldList = [];
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  searchMangaWorld(String keyword) async {
    try {
      var results = await mangaWorldApi.searchManga(keyword);
      setState(() {
        mangaWorldList = results;
      });
    } catch (e) {
      print("Error searching manga: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Cerca manga...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (searchController.text.isNotEmpty) {
                      searchMangaWorld(searchController.text);
                    }
                  },
                  child: const Text('Cerca'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: mangaWorldList.length,
              itemBuilder: (context, index) {
                final manga = mangaWorldList[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailScreen(
                              url: manga['link'],
                              mangaTitle:
                                  manga['alt'] ?? 'Titolo non disponibile',
                            ),
                          ),
                        );
                      },
                      leading: manga['src'] != null
                          ? Image.network(
                              manga['src'],
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.book);
                              },
                            )
                          : const Icon(Icons.book),
                      title: Text(manga['alt'] ?? 'Titolo non disponibile'),
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
