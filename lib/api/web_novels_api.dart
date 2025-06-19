import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manga_read/model/manga/dataMangager.dart';

class WebNovelsApi {
  static const String baseUrl = 'http://192.168.86.25:5000';
  
  Future<DataManager> getAllNovels() async {
    DataManager dataManager = DataManager();
    Uri uri = Uri.parse('$baseUrl/get_all_webnovels');
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
}
