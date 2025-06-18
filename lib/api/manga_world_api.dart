import 'dart:convert';
import 'package:http/http.dart' as http;

class MangaWorldApi {
  static const String baseUrl = 'http://192.168.86.25:5000';
  
  Future<List<Map<String, dynamic>>> searchManga(String keyword) async {
    Uri uri = Uri.parse('$baseUrl/search_manga?keyword=$keyword');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to search manga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching manga: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMangaChapters(String link) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/manga_chapters?link=$link'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get chapters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting chapters: $e');
    }
  }

  Future<List<String>> getChapterPages(String link) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chapter_pages?link=$link'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception('Failed to get pages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting pages: $e');
    }
  }
}
