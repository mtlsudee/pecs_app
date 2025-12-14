import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('students.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Veritabanı tablosu: İsimler ve TC şifreli (TEXT) tutulacak
    // isSynced: 0 (Senkronize olmadı/Bekliyor), 1 (Firebase'e gönderildi/Tamam)
    await db.execute('''
    CREATE TABLE students (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      encryptedName TEXT NOT NULL,
      encryptedSurname TEXT NOT NULL,
      encryptedTC TEXT NOT NULL,
      isSynced INTEGER NOT NULL
    )
    ''');
  }

  // Yeni öğrenci kaydı oluştur
  Future<int> createStudent(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('students', row);
  }

  // --- SENKRONİZASYON İÇİN GEREKLİ METOTLAR ---

  // 1. Henüz Firebase'e gönderilmemiş (isSynced = 0) kayıtları getirir
  Future<List<Map<String, dynamic>>> getUnsyncedStudents() async {
    final db = await instance.database;
    // 'isSynced' değeri 0 olanları seç
    return await db.query('students', where: 'isSynced = ?', whereArgs: [0]);
  }

  // 2. Veri Firebase'e başarıyla gittikten sonra durumunu günceller (0 -> 1)
  Future<int> updateStudentSyncStatus(int id, int status) async {
    final db = await instance.database;
    return await db.update(
      'students',
      {'isSynced': status}, // Genelde buraya 1 göndereceğiz
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}