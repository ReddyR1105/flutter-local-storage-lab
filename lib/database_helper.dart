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

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      path.join(directory.path, 'MyDatabase.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY,
            $columnName TEXT NOT NULL,
            $columnAge INTEGER NOT NULL
          )
        ''');
      },
    );
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
