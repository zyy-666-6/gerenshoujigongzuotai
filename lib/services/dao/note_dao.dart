import 'package:sqflite/sqflite.dart';

import '../../models/note.dart';
import '../../utils/query_utils.dart';

/// 笔记表（note）数据访问对象。
///
/// 搜索范围与验收标准 7 对齐：标题 + 正文。
class NoteDao {
  final Database db;

  NoteDao(this.db);

  /// 全量查询，按更新时间倒序（列表页展示顺序）
  Future<List<Note>> queryAll() async {
    final rows = await db.query('note', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// 新增笔记，返回自增 id
  Future<int> insert(Note note) => db.insert('note', note.toMap());

  /// 更新笔记
  Future<int> update(Note note) =>
      db.update('note', note.toMap(), where: 'id = ?', whereArgs: [note.id]);

  /// 删除笔记
  Future<int> delete(int id) =>
      db.delete('note', where: 'id = ?', whereArgs: [id]);

  /// 关键词搜索：标题或正文匹配（LIKE 转义 + ESCAPE）
  Future<List<Note>> search(String keyword) async {
    final pattern = likePattern(keyword);
    final rows = await db.rawQuery(
      "SELECT * FROM note "
      "WHERE title LIKE ? ESCAPE '\\' OR content LIKE ? ESCAPE '\\' "
      "ORDER BY updated_at DESC",
      [pattern, pattern],
    );
    return rows.map(Note.fromMap).toList();
  }

  /// 分类被删除时：该分类下的笔记置为未分类（资料本身不删除）
  Future<void> clearCategory(int categoryId) async {
    await db.rawUpdate(
      'UPDATE note SET category_id = NULL WHERE category_id = ?',
      [categoryId],
    );
  }
}
