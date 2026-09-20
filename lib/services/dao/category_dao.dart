import 'package:sqflite/sqflite.dart';

import '../../models/category.dart';

/// 分类表（category）数据访问对象。
///
/// 分类按资料类型隔离（note/image/audio/doc 各自独立），
/// 同类型下名称唯一（建表 UNIQUE 约束兜底，业务层先查重给友好提示）。
class CategoryDao {
  final Database db;

  CategoryDao(this.db);

  /// 按资料类型查询分类列表，按创建时间正序（预置分类排最前）
  Future<List<CategoryItem>> queryByType(String assetType) async {
    final rows = await db.query(
      'category',
      where: 'asset_type = ?',
      whereArgs: [assetType],
      orderBy: 'created_at ASC',
    );
    return rows.map(CategoryItem.fromMap).toList();
  }

  /// 同类型下是否已存在同名分类
  Future<bool> exists(String name, String assetType) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM category WHERE asset_type = ? AND name = ?',
      [assetType, name],
    );
    return (rows.first['c'] as int? ?? 0) > 0;
  }

  /// 新增分类，返回自增 id
  Future<int> insert(CategoryItem category) =>
      db.insert('category', category.toMap());

  /// 重命名分类
  Future<int> rename(int id, String newName) =>
      db.update('category', {'name': newName}, where: 'id = ?', whereArgs: [id]);

  /// 删除分类。
  ///
  /// 注意：不在此处处理该分类下的资料——由 CategoryProvider 先调用
  /// NoteDao/AssetDao 的 clearCategory 把资料归入"未分类"，再删除分类。
  Future<int> delete(int id) =>
      db.delete('category', where: 'id = ?', whereArgs: [id]);
}
