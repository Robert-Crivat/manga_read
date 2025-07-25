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