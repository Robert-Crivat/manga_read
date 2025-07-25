class NovelChaprterContent {
  String bookTitle;
  String content;
  String chapterTitle;

  NovelChaprterContent({
    required this.bookTitle,
    required this.content,
    required this.chapterTitle,
  });

  factory NovelChaprterContent.fromJson(Map<String, dynamic> json) {
    return NovelChaprterContent(
      bookTitle: json["titles"]['book_title'] ?? '',
      content: json['content'].toString() ?? '',
      chapterTitle: json["titles"]['chapter_title'] ?? '',
    );
  }
}