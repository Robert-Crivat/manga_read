import 'dart:typed_data';

class Manga {
  final int id;
  final String title;
  final Uint8List? coverImage;

  Manga({required this.id, required this.title, this.coverImage});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'coverImage': coverImage,
    };
  }
}

class Chapter {
  final int id;
  final int mangaId;
  final int chapterIndex;
  final String title;
  final List<Uint8List> images;

  Chapter({
    required this.id,
    required this.mangaId,
    required this.chapterIndex,
    this.title = '',
    this.images = const [],
  });
}