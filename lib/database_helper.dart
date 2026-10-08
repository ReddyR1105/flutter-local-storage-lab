import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Recreated from the guide's interface/schema. The downloadable instructor
// helper was not included in the pasted material.
class DatabaseHelper {
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  late Database _db;
  Database get database => _db;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      path.join(directory.path, 'MyDatabase.db'),
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY,
            $columnName TEXT NOT NULL,
            $columnAge INTEGER NOT NULL
          )
        ''');
        await _createCatalogueSchema(db);
      },
      // These callbacks are already inside sqflite's transaction.
      // Leave the Part I table and rows untouched and keep the same filename.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCatalogueSchema(db);
      },
    );
  }

  static Future<void> _createCatalogueSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE CHECK(length(trim(name)) > 0),
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        suit TEXT NOT NULL CHECK(suit IN ('spades', 'hearts', 'diamonds', 'clubs')),
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_cards_folder_id ON cards(folder_id)');
  }

  Future<int> insert(Map<String, dynamic> row) => _db.insert(table, row);
  Future<List<Map<String, dynamic>>> queryAllRows() =>
      _db.query(table, orderBy: '$columnId ASC');
  Future<int> queryRowCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $table'))!;
  Future<int> update(Map<String, dynamic> row) {
    final id = row[columnId];
    if (id is! int) throw ArgumentError('update requires an integer _id.');
    return _db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) =>
      _db.delete(table, where: '$columnId = ?', whereArgs: [id]);
}
