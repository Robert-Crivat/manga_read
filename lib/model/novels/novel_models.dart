class NovelModels {
  String? status;
  String? img;
  String? title;
  String? url;
  String? description;
  List<dynamic>? chapters;
  int? totalChapters;
  String? slug;

  NovelModels({
    this.status,
    this.img,
    this.title,
    this.url,
    this.description,
    this.chapters,
    this.totalChapters,
    this.slug,
  });

  factory NovelModels.fromJson(Map<String, dynamic> json) {
    // Extract slug from URL if available
    String? extractedSlug;
    if (json['url'] != null) {
      String url = json['url'] as String;
      List<String> parts = url.split('/');
      if (parts.length > 0) {
        extractedSlug = parts.last;
      }
    }

    return NovelModels(
      status: json['status'] as String?,
      img: json['cover_image'] as String?,
      title: json['title'] as String?,
      url: json['url'] as String?,
      description: json['description'] as String?,
      chapters: json['chapters'] as List<dynamic>?,
      totalChapters: json['total_chapters'] as int?,
      slug: extractedSlug,
    );
  }

  // Method to get the slug from the URL
  String getSlug() {
    if (slug != null) {
      return slug!;
    } else if (url != null) {
      List<String> parts = url!.split('/');
      if (parts.isNotEmpty) {
        return parts.last;
      }
    }
    return '';
  }
}