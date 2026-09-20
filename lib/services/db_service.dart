import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants.dart';

/// SQLite 数据库单例服务。
///
/// 职责（实现文档 §6）：
/// 1. 打开/创建数据库 `workbench.db`；
/// 2. 建表：category（分类）、note（笔记）、asset（图片/语音/文档索引）；
/// 3. 为四种资料类型分别预置六个藏文分类。
///
/// DAO 通过 [database] 获取连接，不在此处做业务查询。
class DbService {
  /// 全局单例
  static final DbService instance = DbService._();

  DbService._();

  Database? _db;

  /// 获取数据库连接（懒加载，进程内只打开一次）
  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// 应用启动时调用，确保建库完成
  Future<void> init() async {
    await database;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'workbench.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 首次建库：建表 + 预置分类
  Future<void> _onCreate(Database db, int version) async {
    // 分类表：UNIQUE(name, asset_type) 保证同类型下不重名
    await db.execute('''
      CREATE TABLE category (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        asset_type TEXT    NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(name, asset_type)
      )
    ''');

    // 笔记表
    await db.execute('''
      CREATE TABLE note (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL DEFAULT '',
        content     TEXT    NOT NULL DEFAULT '',
        category_id INTEGER,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');

    // 文件资料表：图片/语音/文档共用，type 列区分
    await db.execute('''
      CREATE TABLE asset (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        type        TEXT    NOT NULL,
        name        TEXT    NOT NULL,
        file_name   TEXT    NOT NULL,
        extension   TEXT    NOT NULL,
        mime_type   TEXT,
        size        INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER,
        category_id INTEGER,
        created_at  INTEGER NOT NULL
      )
    ''');

    // 常用查询索引
    await db.execute('CREATE INDEX idx_asset_type ON asset(type)');
    await db.execute('CREATE INDEX idx_asset_cat  ON asset(category_id)');
    await db.execute('CREATE INDEX idx_note_cat   ON note(category_id)');

    await _insertPresetCategories(db);
  }

  /// 版本 2：用六个预置分类替换旧版「默认」分类。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _insertPresetCategories(db);

      final defaults = await db.query(
        'category',
        columns: ['id', 'asset_type'],
        where: 'name = ?',
        whereArgs: [AppConstants.defaultCategoryName],
      );
      for (final category in defaults) {
        final id = category['id'] as int;
        final type = category['asset_type'] as String;
        if (type == 'note') {
          await db.update(
            'note',
            {'category_id': null},
            where: 'category_id = ?',
            whereArgs: [id],
          );
        } else {
          await db.update(
            'asset',
            {'category_id': null},
            where: 'category_id = ?',
            whereArgs: [id],
          );
        }
        await db.delete('category', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> _insertPresetCategories(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final type in AppConstants.categoryTypes) {
      for (var index = 0; index < AppConstants.presetCategoryNames.length; index++) {
        await db.insert(
          'category',
          {
            'name': AppConstants.presetCategoryNames[index],
            'asset_type': type,
            'created_at': now + index,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }
}
