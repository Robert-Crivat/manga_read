import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manga_read/main.dart';
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/model/novels/novel_chapter.dart';
import 'package:manga_read/model/novels/novel_models.dart';

class WebNovelsApi {
  String get baseUrl => "http://${sharedPrefs.url}:8000";

  Future<DataManager> getAllNovels() async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse(
        '$baseUrl/getnovelsfire?max_pages=5'); // Limitato a una pagina per test, cambia a max_pages=448 per produzione
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
        dataManager;
        print("dataManager: $dataManager");
      } else {
        throw Exception('Failed to search manga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching manga: $e');
    }
    return dataManager;
  }

  Future<DataManager> getNovelDetail(String url) async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/get_novelfire_chapters?url=$url');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
      } else {
        throw Exception('Failed to get novel details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting novel details: $e');
    }
    return dataManager;
  }

  Future<DataManager> getNovelChapters(String slug) async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/getchapters/$slug');
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

  Future<DataManager> getChapterContent(String slug, String chapterId) async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/getchapter/$slug/$chapterId');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
      } else {
        throw Exception(
          'Failed to get chapter content: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error getting chapter content: $e');
    }
    return dataManager;
  }

  Future<DataManager> getNovelFireChapters(String novelUrl) async {
    // Assicura che l'URL termini con /chapters come richiesto
    String url = novelUrl;
    if (!url.endsWith('/chapters')) {
      // Se l'URL termina con /, rimuovi / prima di aggiungere /chapters
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      url = '$url/chapters';
    }

    Uri uri = Uri.parse(
        '$baseUrl/get_novelfire_chapters?url=${Uri.encodeComponent(url)}');

    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      DataManager dataManager = DataManager();

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);

        return dataManager;
      } else {
        throw Exception(
            'Failed to get NovelFire chapters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting NovelFire chapters: $e');
    }
  }

  Future<DataManager> getNovelFireChapterContent(
    String chapterUrl, {
    String translationMode =
        'default', // Opzioni: default, dynamic, robust, lore
  }) async {
    Uri uri = Uri.parse(
      '$baseUrl/get_novelfire_chapter_content?url=${Uri.encodeComponent(chapterUrl)}&translation=$translationMode',
    );

    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      DataManager dataManager = DataManager();

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);

        return dataManager;
      } else {
        throw Exception(
            'Failed to get chapter content: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting chapter content: $e');
    }
  }

  Future<List<NovelModels>> getAllNovelsFire() async {
    Uri uri = Uri.parse(
        '$baseUrl/getnovelsfire?max_pages=1'); // Limitato a una pagina per test, cambia a max_pages=448 per produzione
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonData = json.decode(response.body);
        List<dynamic> novelsData = jsonData['data'] ?? [];

        // Converti i dati JSON in oggetti NovelModels
        List<NovelModels> novels =
            novelsData.map((novel) => NovelModels.fromJson(novel)).toList();

        return novels;
      } else {
        throw Exception('Failed to search novels: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching novels: $e');
    }
  }
}
