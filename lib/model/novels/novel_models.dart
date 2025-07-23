class NovelModels {
  int chapters;
  String img;
  String title;
  String url;
  String rating;

  NovelModels({
    required this.img,
    required this.title,
    required this.url,
    required this.chapters,
    required this.rating,
  });

  factory NovelModels.fromJson(Map<String, dynamic> json) {
    return NovelModels(
      img: json['cover_image'],
      title: json['title'],
      url: json['url'],
      chapters: json['chapters_count'],
      rating: json["badges"]['rating']?.toString() ?? 'N/A',
    );
  }
}