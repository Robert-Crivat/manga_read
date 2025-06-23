class NovelModels {
  String img;
  String title;
  String url;

  NovelModels({
    required this.img,
    required this.title,
    required this.url,
  });

  factory NovelModels.fromJson(Map<String, dynamic> json) {
    return NovelModels(
      img: json['cover_image'],
      title: json['title'],
      url: json['url'],
    );
  }

  // You can add methods to convert to/from JSON if needed
}