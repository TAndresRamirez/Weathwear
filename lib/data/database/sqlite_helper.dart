import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Punto unico de acceso a la base de datos local del sistema
class SqliteHelper {
  static const String _dbName = 'weathwear.db';
  static const int _dbVersion = 1;

  //Singleton: una sola instancia de esta clase en toda la app
  SqliteHelper._internal();
  static final SqliteHelper instance = SqliteHelper._internal();

  //Una sola conexion abierta, reutilizada en todas las consultas.
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String dbPath = join(appDocDir.path, _dbName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  //SQLite no aplica foreign keys por defecto
  //Hay que activarlas cada vez que se abre la conexion
  Future<void> _onConfigure(Database db) async {
    await db.execute('Pragma foreign_keys = ON');
  }

  //Se ejecuta al crear el archivo .db
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Clima (
        id_clima    INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora  TEXT NOT NULL,
        temperatura REAL NOT NULL,
        humedad     REAL NOT NULL,
        condicion   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Prenda (
        id_prenda           INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo                TEXT NOT NULL,
        imagen_ruta         TEXT NOT NULL,
        temp_min            REAL NOT NULL,
        temp_max            REAL NOT NULL,
        condicion_aplicable TEXT NOT NULL,
        CHECK (temp_min <= temp_max)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Recomendacion (
        id_recomendacion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_clima INTEGER NOT NULL,
        id_prenda INTEGER NOT NULL,
        fecha_generacion TEXT NOT NULL,
        nivel_similitud REAL,
        FOREIGN KEY (id_clima) REFERENCES Clima(id_clima)
          ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (id_prenda) REFERENCES Prenda(id_prenda)
          ON DELETE RESTRICT ON UPDATE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recomentacion_clima ON Recomendacion(id_clima)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recomendacion_prenda ON Recomendacion(id_prenda)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clima_fecha ON Clima(fecha_hora)',
    );
  }

  //Utilidad para pruebas o cierre forzoso
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';

// class SqliteHelper {
//   Future<Database> getDB () async {
//     String databasesPath = await getDatabasesPath();
//     String path =join(databasesPath, 'database_sqlite.db');

//     //Abre o crea la base de datos
//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: _onCreate,
//     );
//   }

//   //Metodo para crear las tablas
//   void _onCreate(Database db, int version) async {
//     await db.execute()
//   }
// }
