class NovelModels {
  int chapters;
  String img;
  String title;
  String url;

  NovelModels({
    required this.img,
    required this.title,
    required this.url,
    required this.chapters,
  });

  factory NovelModels.fromJson(Map<String, dynamic> json) {
    return NovelModels(
      img: json['cover_image'],
      title: json['title'],
      url: json['url'],
      chapters: json['chapters_count'],
    );
  }
}