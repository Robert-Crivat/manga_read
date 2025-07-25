import 'package:translator/translator.dart';

class NovelChaprterContent {
  String bookTitle;
  String content; // or consider List<String> if content is multiple paragraphs
  String chapterTitle;

  NovelChaprterContent({
    required this.bookTitle,
    required this.content,
    required this.chapterTitle,
  });

  factory NovelChaprterContent.fromJson(Map<String, dynamic> json) {
    return NovelChaprterContent(
      bookTitle: json["titles"]['book_title'] ?? '',
      content: json['content'].join('\n'), // assuming it's a list of strings
      chapterTitle: json["titles"]['chapter_title'] ?? '',
    );
  }

  // Async method to translate content
  Future<NovelChaprterContent> translateContent({String from = 'en', String to = 'it'}) async {
    final List<String> paragraphs = content.split('\n').where((p) => p.isNotEmpty).toList();
    final List<String> translated = [];

    for (var paragraph in paragraphs) {
      if (paragraph.trim().isNotEmpty) {
        var result = await GoogleTranslator().translate(paragraph, from: from, to: to);
        translated.add(result.text);
      } else {
        translated.add(paragraph);
      }
    }

    return NovelChaprterContent(
      bookTitle: bookTitle,
      content: translated.join('\n'),
      chapterTitle: await GoogleTranslator().translate(chapterTitle, from: from, to: to).then((r) => r.text),
    );
  }
}