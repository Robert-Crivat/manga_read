class NovelChapter {
  final String title;
  final String url;
  final String chapterId;
  final String? date;
  final dynamic number; // Could be int or string depending on API

  NovelChapter({
    required this.title,
    required this.url,
    required this.chapterId,
    this.date,
    this.number,
  });

  factory NovelChapter.fromJson(Map<String, dynamic> json) {
    return NovelChapter(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      chapterId: json['chapter_id'] ?? '',
      date: json['date'],
      number: json['number'],
    );
  }
}

class NovelChapterContent {
  final String title;
  final List<String> content;
  final String novelSlug;
  final String chapterId;
  final String url;

  NovelChapterContent({
    required this.title,
    required this.content,
    required this.novelSlug,
    required this.chapterId,
    required this.url,
  });

  factory NovelChapterContent.fromJson(Map<String, dynamic> json) {
    List<String> contentList = [];
    if (json['content'] != null) {
      contentList = List<String>.from(json['content']);
    }

    return NovelChapterContent(
      title: json['title'] ?? '',
      content: contentList,
      novelSlug: json['novel_slug'] ?? '',
      chapterId: json['chapter_id'] ?? '',
      url: json['url'] ?? '',
    );
  }
}