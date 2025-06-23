import 'package:flutter/material.dart';
import 'package:manga_read/api/web_novels_api.dart';
import 'package:manga_read/model/novels/nodel_charapters.dart';
import 'package:manga_read/model/novels/novel_models.dart';

class NovelDetail extends StatefulWidget {
  final NovelModels novel;

  const NovelDetail({super.key, required this.novel});

  @override
  State<NovelDetail> createState() => _NovelDetailState();
}

class _NovelDetailState extends State<NovelDetail> {
  bool isLoading = true;
  List<NodelCharapters> novelDetail = [];
  final WebNovelsApi webNovelsApi = WebNovelsApi();

  @override
  void initState() {
    super.initState();
    getNovelDetail();
  }

  getNovelDetail() async {
    setState(() {
      isLoading = true;
    });
    try {
      setState(() {
        novelDetail.clear();
      });

      var results = await webNovelsApi.getNovelDetail(widget.novel.url);
      if (results.status == "ok") {
        setState(() {
          for (var charapters in results.parametri) {
            novelDetail.add(NodelCharapters.fromJson(charapters));
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nessuna novel trovata")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching all novels: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Errore nel caricamento: $e")));
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: novelDetail.length,
              reverse: true,
              itemBuilder: (context, index) {
                final chapter = novelDetail[index];
                return ListTile(
                  title: Text(chapter.title),
                  onTap: () {
                  },
                );
              },
            ),
    );
  }
}
