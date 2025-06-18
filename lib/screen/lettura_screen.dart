import 'package:flutter/material.dart';
import 'package:manga_read/api/manga_world_api.dart';

class LetturaScreen extends StatefulWidget {
  final String url;
  final String mangaTitle;
  final List<String> capitoliList;
  final int chaptherIndex;

  const LetturaScreen({
    Key? key,
    required this.url,
    required this.mangaTitle,
    required this.capitoliList,
    required this.chaptherIndex,
  }) : super(key: key);

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
        for (var img in results.parametri) {
          capitoliList.add(img);
        }
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
      body: Stack(
        children: [
            capitoliList.isEmpty
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(Icons.menu_book, size: 80, color: Colors.grey[700]),
                const SizedBox(height: 24),
                const Text(
                  'Benvenuto nella schermata di lettura!',
                  style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                CircularProgressIndicator(),
                ],
              ),
              )
              : Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
              child: ListView.builder(
                itemCount: capitoliList.length,
                itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.network(
                  capitoliList[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(child: CircularProgressIndicator());
                  },
                  ),
                );
                },
              ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  'Capitolo ${widget.chaptherIndex + 1} di ${widget.capitoliList.length}',
                  style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                  color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Previous chapter button
                  ElevatedButton.icon(
                    onPressed: widget.chaptherIndex > 0 
                      ? () {
                        Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LetturaScreen(
                          url: widget.capitoliList[widget.chaptherIndex - 1],
                          mangaTitle: widget.mangaTitle,
                          capitoliList: widget.capitoliList,
                          chaptherIndex: widget.chaptherIndex - 1,
                          ),
                        ),
                        );
                      } 
                      : null,
                    icon: Icon(Icons.arrow_back),
                    label: Text('${widget.chaptherIndex}'),
                    style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 20),
                  // Next chapter button
                  ElevatedButton.icon(
                    onPressed: widget.chaptherIndex < widget.capitoliList.length - 1
                      ? () {
                        Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LetturaScreen(
                          url: widget.capitoliList[widget.chaptherIndex + 1],
                          mangaTitle: widget.mangaTitle,
                          capitoliList: widget.capitoliList,
                          chaptherIndex: widget.chaptherIndex + 1,
                          ),
                        ),
                        );
                      } 
                      : null,
                    icon: Icon(Icons.arrow_forward),
                    label: Text('${widget.chaptherIndex + 2}'),
                    style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    ),
                  ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.capitoliList.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                    onTap: () {
                      if (index != widget.chaptherIndex) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                        builder: (context) => LetturaScreen(
                          url: widget.capitoliList[index],
                          mangaTitle: widget.mangaTitle,
                          capitoliList: widget.capitoliList,
                          chaptherIndex: index,
                        ),
                        ),
                      );
                      }
                    },
                    child: Container(
                      width: 40,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                      color: index == widget.chaptherIndex
                        ? Colors.blue[700]
                        : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index == widget.chaptherIndex
                          ? Colors.white
                          : Colors.black,
                        fontWeight: index == widget.chaptherIndex
                          ? FontWeight.bold
                          : FontWeight.normal,
                      ),
                      ),
                    ),
                    );
                  },
                  ),
                ),
                ],
              ),
              ),
            ),
        ],
      ),
    );
  }
}
