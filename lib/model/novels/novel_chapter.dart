class NovelChapter {
  final String link;
  final String title;
  final String? chapterNumber;
  final String? datePublished;

  NovelChapter({
    required this.link,
    required this.title,
    this.chapterNumber,
    this.datePublished,
  });

  factory NovelChapter.fromJson(Map<String, dynamic> json) {
    // Estrai il numero del capitolo dal titolo se disponibile
    String? chapterNumber;
    String title = json['title'] ?? '';
    
    // Il titolo potrebbe contenere il numero del capitolo in vari formati
    final RegExp regExp = RegExp(r'Chapter\s+(\d+)', caseSensitive: false);
    final match = regExp.firstMatch(title);
    
    if (match != null && match.groupCount >= 1) {
      chapterNumber = match.group(1);
    }
    
    return NovelChapter(
      link: json['link'] ?? '',
      title: title,
      chapterNumber: chapterNumber,
      datePublished: json['date_published'], // Questo potrebbe non essere presente nell'API
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'link': link,
      'title': title,
      'chapterNumber': chapterNumber,
      'datePublished': datePublished,
    };
  }
}

class NovelChapterContent {
  final String title;
  final String content;
  final List<String> paragraphs;
  final String? prevChapter;
  final String? nextChapter;
  final String translationMode;

  NovelChapterContent({
    required this.title,
    required this.content,
    required this.paragraphs,
    this.prevChapter,
    this.nextChapter,
    this.translationMode = 'default',
  });

  factory NovelChapterContent.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = json['data'] ?? {};
    
    return NovelChapterContent(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      paragraphs: List<String>.from(data['paragraphs'] ?? []),
      prevChapter: data['prev_chapter'],
      nextChapter: data['next_chapter'],
      translationMode: data['translation_mode'] ?? 'default',
    );
  }
}
