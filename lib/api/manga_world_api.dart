import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manga_read/model/dataMangager.dart';

class MangaWorldApi {
  static const String baseUrl = 'http://192.168.68.13:5000';
  
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
      final response = await http.get(
        Uri.parse('$baseUrl/all_manga'),
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
