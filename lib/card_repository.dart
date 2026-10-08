import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'models.dart';

class CardRepository {
  CardRepository(this.helper);
  final DatabaseHelper helper;
  Database get _db => helper.database;

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.name COLLATE NOCASE, f.id
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<CatalogueCard>> getCards(int folderId) async {
    final rows = await _db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE, id',
    );
    return rows.map(CatalogueCard.fromMap).toList();
  }

  Future<int> insertFolder(String name) => _db.insert(
    'folders',
    Folder(
      name: _folderName(name),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ).toMap(),
  );
  Future<int> updateFolder(int id, String name) => _db.update(
    'folders',
    {'name': _folderName(name)},
    where: 'id = ?',
    whereArgs: [id],
  );
  Future<int> deleteFolder(int id) => _db.transaction(
    (txn) => txn.delete('folders', where: 'id = ?', whereArgs: [id]),
  );
  String _folderName(String name) {
    if (name.trim().isEmpty) throw ArgumentError('Enter a folder name.');
    return name.trim();
  }

  void _validateCard(CatalogueCard card) {
    if (card.title.trim().isEmpty) throw ArgumentError('Enter a card title.');
    if (!CatalogueCard.suits.contains(card.suit)) {
      throw ArgumentError('Choose a supported suit.');
    }
    if (card.folderId <= 0) throw ArgumentError('Choose a valid folder.');
    // The connection's foreign key rejects a missing positive ID as well.
  }

  Future<int> insertCard(CatalogueCard card) {
    _validateCard(card);
    return _db.insert('cards', card.toMap());
  }

  Future<int> updateCard(CatalogueCard card) {
    _validateCard(card);
    if (card.id == null) throw ArgumentError('An update requires a card ID.');
    return _db.update(
      'cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) =>
      _db.delete('cards', where: 'id = ?', whereArgs: [id]);
}
