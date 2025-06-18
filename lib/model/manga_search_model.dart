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
      title: json['title'],
      url: json['url'],
      img: json['thumbnail'],
      story: json['story'],
      status: json['status'],
      type: json['main_genre'],
      genres: json['genres'],
      author: json['author'],
      artist: json['artist'],
    );
  }
}
