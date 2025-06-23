class NodelCharapters {
  String title;
  String url;

  NodelCharapters({required this.title, required this.url});

  factory NodelCharapters.fromJson(Map<String, dynamic> json) {
    return NodelCharapters(title: json['title'], url: json['link']);
  }
}
