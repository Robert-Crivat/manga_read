import 'package:manga_read/model/manga/capitoli_model.dart';

class MangaSearchModel {
  final String title;
  final String url;
  final String img;
  final String story;
  final String status;
  final String type;
  final String genres;
  final String author;
  final String artist;

  MangaSearchModel({
    required this.title,
    required this.url,
    required this.img,
    required this.story,
    required this.status,
    required this.type,
    required this.genres,
    required this.author,
    required this.artist,
  });

  factory MangaSearchModel.fromJson(Map<String, dynamic> json) {
    return MangaSearchModel(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      img: json['thumbnail'] ?? '',
      story: json['story'] ?? '',
      status: json['status'] ?? '',
      type: json['main_genre'] ?? '',
      genres: json['genres'] ?? '',
      author: json['author'] ?? '',
      artist: json['artist'] ?? '',
    );
  }
}

class MangaCompleteInfo {
  final String? title;
  final String? alternativeTitles;
  final String? author;
  final String? authorUrl;
  final String? artist;
  final String? artistUrl;
  final String? fansub;
  final String? fansubUrl;
  final List<String>? genres;
  final String? genresText;
  final String? status;
  final String? statusUrl;
  final String? type;
  final String? typeUrl;
  final int? releaseYear;
  final String? releaseYearUrl;
  final int? views;
  final List<ChapterModel>? chapters;

  MangaCompleteInfo({
    this.title,
    this.alternativeTitles,
    this.author,
    this.authorUrl,
    this.artist,
    this.artistUrl,
    this.fansub,
    this.fansubUrl,
    this.genres,
    this.genresText,
    this.status,
    this.statusUrl,
    this.type,
    this.typeUrl,
    this.releaseYear,
    this.releaseYearUrl,
    this.views,
    this.chapters,
  });

  factory MangaCompleteInfo.fromJson(Map<String, dynamic> json) {
    return MangaCompleteInfo(
      title: json['title'] ?? '',
      alternativeTitles: json['alternative_titles'] ?? '',
      author: json['author'] ?? '',
      authorUrl: json['author_url'] ?? '',
      artist: json['artist'] ?? '',
      artistUrl: json['artist_url'] ?? '',
      fansub: json['fansub'] ?? '',
      fansubUrl: json['fansub_url'] ?? '',
      genres: json['genres'] != null 
        ? List<String>.from(json['genres'] as List? ?? [])
        : [],
      genresText: json['genres_text'] ?? '',
      status: json['status'] ?? '',
      statusUrl: json['status_url'] ?? '',
      type: json['type'] ?? '',
      typeUrl: json['type_url'] ?? '',
      releaseYear: json['release_year'] ?? 0,
      releaseYearUrl: json['release_year_url'] ?? '',
      views: json['views'] ?? 0,
      chapters: json['chapters'] != null
          ? (json['chapters'] as List)
              .map((chapter) => ChapterModel.fromJson(chapter))
              .toList()
          : [],
    );
  }
}