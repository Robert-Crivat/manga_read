import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

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
        await db.execute('PRAGMA foreign_keys = ON;');
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE manga (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        author TEXT,
        cover BLOB,
        added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id INTEGER NOT NULL,
        chapter_number REAL NOT NULL,
        title TEXT,
        pages_count INTEGER NOT NULL,
        downloaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (manga_id) REFERENCES manga(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        image_data BLOB NOT NULL,
        image_size INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
      )
    ''');

    // Indici per prestazioni
    await db.execute('CREATE INDEX idx_chapters_manga ON chapters(manga_id)');
    await db.execute('CREATE INDEX idx_pages_chapter ON pages(chapter_id)');
  }

  // --- OPERAZIONI CRUCIALI ---
  
  /// Aggiunge un capitolo (crea automaticamente il manga se non esiste)
  Future<void> addChapter({
    required String mangaTitle,
    required double chapterNumber,
    String? chapterTitle,
    required List<Uint8List> pageImages,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Crea manga se non esiste (INSERT OR IGNORE)
      final mangaId = await txn.rawInsert('''
        INSERT OR IGNORE INTO manga (title) VALUES (?)
      ''', [mangaTitle]);

      // 2. Ottieni ID effettivo (se già esistente)
      final mangaResult = await txn.query(
        'manga',
        where: 'title = ?',
        whereArgs: [mangaTitle],
      );
      final actualMangaId = mangaResult.first['id'] as int;

      // 3. Inserisci capitolo
      final chapterId = await txn.insert('chapters', {
        'manga_id': actualMangaId,
        'chapter_number': chapterNumber,
        'title': chapterTitle,
        'pages_count': pageImages.length,
      });

      // 4. Inserisci pagine (con compressione)
      for (int i = 0; i < pageImages.length; i++) {
        final compressedImage = _compressImage(pageImages[i]);
        await txn.insert('pages', {
          'chapter_id': chapterId,
          'page_number': i + 1,
          'image_data': compressedImage,
          'image_size': compressedImage.length,
        });
      }
    });
  }

  /// Comprime l'immagine prima di salvarla (risparmia spazio)
  Uint8List _compressImage(Uint8List imageData) {
    final decoded = img.decodeImage(imageData)!;
    
    // Ridimensiona a 1000px di larghezza (mantenendo aspect ratio)
    final resized = img.copyResize(decoded, width: 1000);
    
    // Comprime in JPEG (85% quality)
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  /// Ottiene tutti i manga con conteggio capitoli
  Future<List<Map<String, dynamic>>> getAllManga() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        m.*,
        (SELECT COUNT(*) FROM chapters c WHERE c.manga_id = m.id) AS chapters_count
      FROM manga m
      ORDER BY m.added_at DESC
    ''');
  }

  /// Ottiene capitoli per un manga specifico
  Future<List<Map<String, dynamic>>> getChaptersForManga(int mangaId) async {
    final db = await database;
    return await db.query(
      'chapters',
      where: 'manga_id = ?',
      whereArgs: [mangaId],
      orderBy: 'chapter_number ASC',
    );
  }

  /// Ottiene pagine per un capitolo (ordinato)
  Future<List<Uint8List>> getPagesForChapter(int chapterId) async {
    final db = await database;
    final result = await db.query(
      'pages',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'page_number ASC',
    );
    return result.map((e) => e['image_data'] as Uint8List).toList();
  }

  /// Elimina un intero manga (e tutto il suo contenuto)
  Future<void> deleteManga(int mangaId) async {
    final db = await database;
    await db.delete('manga', where: 'id = ?', whereArgs: [mangaId]);
    // Cascade delete gestito dal DB
  }

  /// Elimina un singolo capitolo
  Future<void> deleteChapter(int chapterId) async {
    final db = await database;
    await db.delete('chapters', where: 'id = ?', whereArgs: [chapterId]);
  }
}