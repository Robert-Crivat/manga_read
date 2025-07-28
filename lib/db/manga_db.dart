import 'dart:io';

import 'package:manga_read/model/manga/downloaded_image.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class MangaDatabase {
  static final MangaDatabase _instance = MangaDatabase._internal();
  factory MangaDatabase() => _instance;
  MangaDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String dbPath = path.join(dir.path, 'manga_reader.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Tabella manga (con copertina)
        await db.execute('''
          CREATE TABLE mangas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE,
            cover_image BLOB,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Tabella capitoli
        await db.execute('''
          CREATE TABLE chapters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            manga_id INTEGER NOT NULL,
            chapter_index INTEGER NOT NULL,
            title TEXT,
            downloaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(manga_id) REFERENCES mangas(id) ON DELETE CASCADE
          )
        ''');

        // Tabella immagini dei capitoli
        await db.execute('''
          CREATE TABLE images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter_id INTEGER NOT NULL,
            page_index INTEGER NOT NULL,
            image_data BLOB NOT NULL,
            FOREIGN KEY(chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
          )
        ''');

        // Indici per prestazioni
        await db.execute('CREATE INDEX idx_chapters_manga ON chapters(manga_id)');
      },
    );
  }


  /// Salva un capitolo con le sue immagini
  Future<void> saveChapter(String mangaTitle, int chapterIndex, List<DownloadedImage> imageList) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 1. Inserisci o ottieni l'ID del capitolo
      int chapterId;
      final chapterResult = await txn.query(
        'chapters',
        where: 'manga_title = ? AND chapter_index = ?',
        whereArgs: [mangaTitle, chapterIndex],
      );
      
      if (chapterResult.isNotEmpty) {
        chapterId = chapterResult.first['id'] as int;
        // Cancella le immagini esistenti per aggiornare
        await txn.delete('images', where: 'chapter_id = ?', whereArgs: [chapterId]);
      } else {
        chapterId = await txn.insert('chapters', {
          'manga_title': mangaTitle,
          'chapter_index': chapterIndex,
        });
      }
      
      // 2. Inserisci tutte le immagini
      for (int i = 0; i < imageList.length; i++) {
        await txn.insert('images', {
          'chapter_id': chapterId,
          'page_index': i,
          'image_data': imageList[i].imagePath, // Usa direttamente imagePath
        });
      }
    });
  }

  /// Ottieni un capitolo completo con tutte le immagini
  Future<Map<String, dynamic>?> getChapter(String mangaTitle, int chapterIndex) async {
    final db = await database;
    
    // 1. Ottieni l'ID del capitolo
    final chapterResult = await db.query(
      'chapters',
      where: 'manga_title = ? AND chapter_index = ?',
      whereArgs: [mangaTitle, chapterIndex],
    );
    
    if (chapterResult.isEmpty) return null;
    
    final chapterId = chapterResult.first['id'] as int;
    
    // 2. Ottieni tutte le immagini del capitolo
    final imagesResult = await db.query(
      'images',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'page_index ASC',
    );
    
    // Costruisci la lista di DownloadedImage
    final imageList = imagesResult
        .map((e) => DownloadedImage(imagePath: e['image_data'] as Uint8List))
        .toList();
    
    return {
      'mangaTitle': mangaTitle,
      'chapterIndex': chapterIndex,
      'imageList': imageList,
    };
  }

  /// Ottieni tutti i capitoli per un manga
  Future<List<Map<String, dynamic>>> getAllChaptersForManga(String mangaTitle) async {
    final db = await database;
    
    // 1. Ottieni tutti i capitoli del manga
    final chaptersResult = await db.query(
      'chapters',
      where: 'manga_title = ?',
      whereArgs: [mangaTitle],
      orderBy: 'chapter_index ASC',
    );
    
    final chapters = <Map<String, dynamic>>[];
    
    // 2. Per ogni capitolo, ottieni le immagini
    for (var chapter in chaptersResult) {
      final chapterId = chapter['id'] as int;
      final chapterIndex = chapter['chapter_index'] as int;
      
      final imagesResult = await db.query(
        'images',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
        orderBy: 'page_index ASC',
      );
      
      // Costruisci la lista di DownloadedImage
      final imageList = imagesResult
          .map((e) => DownloadedImage(imagePath: e['image_data'] as Uint8List))
          .toList();
      
      chapters.add({
        'mangaTitle': mangaTitle,
        'chapterIndex': chapterIndex,
        'imageList': imageList,
      });
    }
    
    return chapters;
  }

  /// Elimina un capitolo
  Future<void> deleteChapter(String mangaTitle, int chapterIndex) async {
    final db = await database;
    
    final chapterResult = await db.query(
      'chapters',
      where: 'manga_title = ? AND chapter_index = ?',
      whereArgs: [mangaTitle, chapterIndex],
    );
    
    if (chapterResult.isNotEmpty) {
      final chapterId = chapterResult.first['id'] as int;
      await db.delete('chapters', where: 'id = ?', whereArgs: [chapterId]);
    }
  }
}