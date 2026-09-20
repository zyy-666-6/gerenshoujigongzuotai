import 'package:sqflite/sqflite.dart';

import '../../models/asset_item.dart';
import '../../utils/query_utils.dart';

/// 文件资料表（asset）数据访问对象，覆盖图片/语音/文档三类。
class AssetDao {
  final Database db;

  AssetDao(this.db);

  /// 按类型查询，按创建时间倒序
  Future<List<AssetItem>> queryByType(AssetType type) async {
    final rows = await db.query(
      'asset',
      where: 'type = ?',
      whereArgs: [type.dbValue],
      orderBy: 'created_at DESC',
    );
    return rows.map(AssetItem.fromMap).toList();
  }

  /// 新增资料索引，返回自增 id
  Future<int> insert(AssetItem asset) => db.insert('asset', asset.toMap());

  /// 删除资料索引
  Future<int> delete(int id) =>
      db.delete('asset', where: 'id = ?', whereArgs: [id]);

  /// 更新资料的显示名称与分类。文件本身不改名，避免破坏已保存的路径。
  Future<int> updateInfo(
    int id, {
    required String name,
    int? categoryId,
  }) =>
      db.update(
        'asset',
        {'name': name, 'category_id': categoryId},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// 关键词搜索：按显示名匹配（验收标准 7 的"文件名"检索字段）
  Future<List<AssetItem>> search(String keyword) async {
    final rows = await db.rawQuery(
      "SELECT * FROM asset "
      "WHERE name LIKE ? ESCAPE '\\' "
      "ORDER BY created_at DESC",
      [likePattern(keyword)],
    );
    return rows.map(AssetItem.fromMap).toList();
  }

  /// 分类被删除时：该分类下的资料置为未分类（文件与索引均不删除）
  Future<void> clearCategory(int categoryId) async {
    await db.rawUpdate(
      'UPDATE asset SET category_id = NULL WHERE category_id = ?',
      [categoryId],
    );
  }
}
