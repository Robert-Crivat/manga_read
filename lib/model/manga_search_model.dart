class Manga {
  final String alt;
  final String img;
  final String link;

  Manga({required this.alt, required this.img, required this.link});

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      alt: json['alt'] as String? ?? '',
      img: json['src'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }
}
