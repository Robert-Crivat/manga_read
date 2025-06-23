import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chapter.dart';
import 'package:manga_read/model/novels/novel_models.dart';

class WebNovelsApi {
  static const String baseUrl = 'http://192.168.1.63:5000';
  
  Future<List<NovelModels>> getAllNovels() async {
    Uri uri = Uri.parse('$baseUrl/getnovelsfire?max_pages=1'); // Limitato a una pagina per test, cambia a max_pages=448 per produzione
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonData = json.decode(response.body);
        List<dynamic> novelsData = jsonData['data'] ?? [];
        
        // Converti i dati JSON in oggetti NovelModels
        List<NovelModels> novels = novelsData.map((novel) => 
          NovelModels.fromJson(novel)).toList();
        
        return novels;
      } else {
        throw Exception('Failed to search novels: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching novels: $e');
    }
  }
  
  Future<DataManager> getNovelChapters(String novelUrl) async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/get_webnovel_chapters?url=${Uri.encodeComponent(novelUrl)}');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
      } else {
        throw Exception('Failed to get novel chapters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting novel chapters: $e');
    }
    return dataManager;
  }
  
  Future<List<NovelChapter>> getNovelFireChapters(String novelUrl) async {
    // Assicura che l'URL termini con /chapters come richiesto
    String url = novelUrl;
    if (!url.endsWith('/chapters')) {
      // Se l'URL termina con /, rimuovi / prima di aggiungere /chapters
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      url = '$url/chapters';
    }
    
    Uri uri = Uri.parse('$baseUrl/get_novelfire_chapters?url=${Uri.encodeComponent(url)}');
    
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonData = json.decode(response.body);
        List<dynamic> chaptersData = jsonData['data'] ?? [];
        
        // Converti i dati JSON in oggetti NovelChapter
        List<NovelChapter> chapters = chaptersData.map((chapter) => 
          NovelChapter.fromJson(chapter)).toList();
        
        return chapters;
      } else {
        throw Exception('Failed to get NovelFire chapters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting NovelFire chapters: $e');
    }
  }
  
  // Funzione per ottenere il contenuto di un capitolo specifico
  Future<NovelChapterContent> getNovelFireChapterContent(String chapterUrl) async {
    Uri uri = Uri.parse('$baseUrl/get_novelfire_chapter_content?url=${Uri.encodeComponent(chapterUrl)}');
    
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        return NovelChapterContent.fromJson(data);
      } else {
        throw Exception('Failed to get chapter content: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting chapter content: $e');
    }
  }
}
