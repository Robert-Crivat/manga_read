class ChapterModel {
  final String url;
  final String mangaTitle;

  const ChapterModel({
    required this.url,
    required this.mangaTitle,
  });
  

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      mangaTitle: json['alt'] ?? 'Titolo non disponibile',
      url: json['link'] ?? '',
    );
  }
}