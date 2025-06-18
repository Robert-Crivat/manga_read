import 'package:flutter/material.dart';

class MangaPreferitiScreen extends StatelessWidget {
  final  List<Map<String, dynamic>> mangaPreferiti;
  const MangaPreferitiScreen({Key? key, required this.mangaPreferiti}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manga Preferiti'),
      ),
      body: mangaPreferiti.isEmpty
          ? const Center(
              child: Text(
                'Nessun manga tra i preferiti.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: mangaPreferiti.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(mangaPreferiti[index]['title'] ?? 'Titolo non disponibile'),
                );
              },
            ),
    );
  }
}