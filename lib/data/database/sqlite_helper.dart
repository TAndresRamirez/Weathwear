import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Punto unico de acceso a la base de datos local del sistema
class SqliteHelper {
  static const String _dbName = 'weathwear.db';
  static const int dbVersion = 7; // v7: OutfitUso.corregido (indicador complementario del RF-09)

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
      version: dbVersion,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  //SQLite no aplica foreign keys por defecto
  //Hay que activarlas cada vez que se abre la conexion
  @visibleForTesting
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  //Se ejecuta al crear el archivo .db (instalación nueva)
  @visibleForTesting
  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Clima (
        id_clima          INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora        TEXT NOT NULL,
        temperatura       REAL NOT NULL,
        humedad           REAL NOT NULL,
        condicion         TEXT NOT NULL,
        sensacion_termica REAL,
        viento_kmh        REAL
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
        activa              INTEGER NOT NULL DEFAULT 1,
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

    // v4: en una instalación nueva se crean junto con el resto
    await crearTablasOutfit(db);
  }

  //Utilidad para pruebas o cierre forzoso
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  @visibleForTesting
  static void setTestDatabase(Database db) {
    _database = db;
  }

  @visibleForTesting
  static void resetForTest() {
    _database = null;
  }

  // Migra instalaciones existentes (sqflite la ejecuta dentro de una transacción)
  @visibleForTesting
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE Clima ADD COLUMN sensacion_termica REAL');
      await db.execute('ALTER TABLE Clima ADD COLUMN viento_kmh REAL');
    }
    // v3 -> v4: agrega las tablas de outfits sin tocar los datos existentes
    if (oldVersion < 4) {
      await crearTablasOutfit(db);
    }
    // v4 -> v5: Poleron pasa a Chaqueta (exterior). Los outfits que lo usaban
    // como superior quedan inválidos, así que se borran ANTES de renombrar
    // (CASCADE elimina también sus OutfitPrenda y OutfitUso)
    if (oldVersion < 5) {
      await db.execute('''
        DELETE FROM Outfit WHERE id_outfit IN (
          SELECT op.id_outfit FROM OutfitPrenda op
          JOIN Prenda p ON p.id_prenda = op.id_prenda
          WHERE lower(trim(p.tipo)) IN ('poleron', 'polerón'))
      ''');
      await db.execute(
        "UPDATE Prenda SET tipo = 'Chaqueta' "
        "WHERE lower(trim(tipo)) IN ('poleron', 'polerón')",
      );
    }
    // v5 -> v6: dispositivos que ya corrieron la v5 con el typo. Idempotente.
    if (oldVersion < 6) {
      await db.execute(
        "UPDATE Prenda SET tipo = 'Chaqueta' WHERE tipo = 'Chaquetas'",
      );
    }
    // v6 -> v7: indicador de corrección en los usos desde foto (RF-10)
    if (oldVersion < 7) {
      await _agregarColumnaCorregido(db);
    }
  }

  // Idempotente: si la tabla se creó en esta misma migración (oldVersion < 4)
  // ya trae la columna desde crearTablasOutfit, y un ADD COLUMN duplicado falla.
  static Future<void> _agregarColumnaCorregido(Database db) async {
    final columnas = await db.rawQuery('PRAGMA table_info(OutfitUso)');
    if (columnas.any((c) => c['name'] == 'corregido')) return;
    await db.execute('ALTER TABLE OutfitUso ADD COLUMN corregido INTEGER');
  }

  // v4: outfits guardados, su composición y el registro de usos.
  // Sin columnas de estadísticas: veces usado y temperatura promedio se
  // calculan desde OutfitUso, así no hay datos redundantes que desincronizar.
  // Público y estático para reutilizarlo en los tests.
  static Future<void> crearTablasOutfit(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Outfit (
        id_outfit      INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_creacion TEXT NOT NULL,
        origen         TEXT NOT NULL DEFAULT 'manual'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS OutfitPrenda (
        id_outfit INTEGER NOT NULL,
        id_prenda INTEGER NOT NULL,
        PRIMARY KEY (id_outfit, id_prenda),
        FOREIGN KEY (id_outfit) REFERENCES Outfit(id_outfit)
          ON DELETE CASCADE,
        FOREIGN KEY (id_prenda) REFERENCES Prenda(id_prenda)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS OutfitUso (
        id_uso    INTEGER PRIMARY KEY AUTOINCREMENT,
        id_outfit INTEGER NOT NULL,
        id_clima  INTEGER NOT NULL,
        fecha_uso TEXT NOT NULL,
        -- v7. NULL: uso manual ("Usar hoy"); 0: el usuario aceptó la propuesta
        -- del modelo; 1: la corrigió (RF-10)
        corregido INTEGER,
        FOREIGN KEY (id_outfit) REFERENCES Outfit(id_outfit)
          ON DELETE CASCADE,
        FOREIGN KEY (id_clima) REFERENCES Clima(id_clima)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outfituso_outfit ON OutfitUso(id_outfit)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outfitprenda_prenda ON OutfitPrenda(id_prenda)',
    );
  }
}
