import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/dao/note_dao.dart';
import '../services/db_service.dart';

/// 笔记状态管理（实现文档 §8.2）。
///
/// 持有全量笔记（个人资料量级下无需分页），列表按更新时间倒序。
class NoteProvider extends ChangeNotifier {
  List<Note> _notes = [];

  /// 全部笔记（已按更新时间倒序）
  List<Note> get notes => _notes;

  /// 按 id 取笔记（编辑页回显用）
  Note? byId(int? id) {
    if (id == null) return null;
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<NoteDao> _dao() async => NoteDao(await DbService.instance.database);

  /// 从数据库全量刷新
  Future<void> load() async {
    _notes = await (await _dao()).queryAll();
    notifyListeners();
  }

  /// 保存笔记：id 为空即新增，否则为更新；返回保存后的笔记
  Future<Note> save(Note note) async {
    final dao = await _dao();
    if (note.id == null) {
      final id = await dao.insert(note);
      final saved = Note(
        id: id,
        title: note.title,
        content: note.content,
        categoryId: note.categoryId,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      );
      await load();
      return saved;
    }
    await dao.update(note);
    await load();
    return note;
  }

  /// 删除笔记（笔记无实体文件，仅删数据库记录）
  Future<void> delete(int id) async {
    await (await _dao()).delete(id);
    await load();
  }
}
