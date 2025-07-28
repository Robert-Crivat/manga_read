import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manga_read/model/manga/dataMangager.dart';
import 'package:manga_read/main.dart';

class MangaWorldApi {
  String get baseUrl => "http://${sharedPrefs.url}:8000";

  Future<DataManager> searchManga(String keyword) async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/search_manga?keyword=$keyword');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
      } else {
        throw Exception('Failed to search manga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching manga: $e');
    }
    return dataManager;
  }

  Future<DataManager> getMangaChapters(String link) async {
    DataManager dataManager = DataManager();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/manga_chapters?link=$link'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
        return dataManager;
      } else {
        throw Exception('Failed to get chapters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting chapters: $e');
    }
  }

  Future<DataManager> getChapterPages(String link) async {
    DataManager dataManager = DataManager();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chapter_pages?link=$link'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
        return dataManager;
      } else {
        throw Exception('Failed to get pages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting pages: $e');
    }
  }

  Future<DataManager> getAllManga() async {
    DataManager dataManager = DataManager();
    try {
      Uri url = Uri.parse('$baseUrl/all_manga?max_pages=5');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
        return dataManager;
      } else {
        throw Exception('Failed to get all manga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting all manga: $e');
    }
  }

  String removeQueryFromUrl(String url) {
    if (url.isEmpty) return url;
    final questionMarkIndex = url.indexOf('?');
    if (questionMarkIndex == -1) {
      return url;
    }
    return url.substring(0, questionMarkIndex);
  }

  Future<DataManager> downloadMultipleImages(List<String> imageUrls) async {
    const String baseUrl = 'http://100.70.187.3:8000';

    // Codifica la lista di URL come stringa JSON
    final encodedUrls = json.encode(imageUrls);

    // Costruisci URI in modo sicuro
    final uri = Uri.parse(baseUrl).replace(
      path: '/download_image',
      queryParameters: {
        'urls': encodedUrls,
      },
    );

    print('Calling URL: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DataManager.fromJson(data);
      } else {
        throw Exception('Errore nel download immagini: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Eccezione nella richiesta HTTP: $e');
    }
  }

  Future<DataManager> downloadSingleImage(String imageUrl) async {
    DataManager dataManager = DataManager();
    final uri = Uri.parse('$baseUrl/download_single_image?url=$imageUrl');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        dataManager = DataManager.fromJson(data);
        return dataManager;
      } else {
        throw Exception('Failed to get all manga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting all manga: $e');
    }
  }
}
