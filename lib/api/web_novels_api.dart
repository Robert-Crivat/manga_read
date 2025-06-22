import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manga_read/model/manga/dataMangager.dart';

class WebNovelsApi {
  static const String baseUrl = 'http://192.168.68.10:5000';
  
  Future<DataManager> getAllNovels() async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/getnovels');
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
  
  Future<DataManager> getNovelDetail(String slug) async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/getnovel/$slug');
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
        throw Exception('Failed to get chapter content: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting chapter content: $e');
    }
    return dataManager;
  }
}
