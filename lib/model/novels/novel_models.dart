class NovelModels {
  String? bookID;
  String? img;
  String? title;
  String? url;

  NovelModels({
    this.bookID,
    this.img,
    this.title,
    this.url,
  });

  factory NovelModels.fromJson(Map<String, dynamic> json) {
    return NovelModels(
      bookID: json['book_id'] as String?,
      img: json['cover_image'] as String?,
      title: json['title'] as String?,
      url: json['url'] as String?,
    );
  }

  // You can add methods to convert to/from JSON if needed
}