import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';

class LetturaScreen extends StatefulWidget {
  final String url;
  final String mangaTitle;

  const LetturaScreen({Key? key, required this.url, required this.mangaTitle})
    : super(key: key);

  @override
  State<LetturaScreen> createState() => _LetturaScreenState();
}

class _LetturaScreenState extends State<LetturaScreen> {
  final MangaWorldApi mangaWorldApi = MangaWorldApi();
    List<String> capitoliList = [];
    bool isLoading = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getChaptersImg();
  }

  getChaptersImg() async {
    setState(() {
      isLoading = true;
    });
    try {
      var results = await mangaWorldApi.getChapterPages(widget.url);
      setState(() {
        capitoliList = results;
      });
    } catch (e) {
      print("Error searching manga: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Errore nella ricerca: $e")));
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mangaTitle)),
      body: capitoliList.isEmpty? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 24),
            const Text(
              'Benvenuto nella schermata di lettura!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator()
          ],
        ),
      ) : ListView.builder(
        itemCount: capitoliList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(
              capitoliList[index],
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}
