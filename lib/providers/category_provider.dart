import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../services/dao/asset_dao.dart';
import '../services/dao/category_dao.dart';
import '../services/dao/note_dao.dart';
import '../services/db_service.dart';

/// 分类状态管理（实现文档 §8.6）。
///
/// 分类按资料类型隔离（note/image/audio/doc 各自独立）。
/// 删除分类时，其下资料自动归入"未分类"，资料本身不删除。
class CategoryProvider extends ChangeNotifier {
  /// 按资料类型缓存的分类列表，key 取 AppConstants.categoryTypes 中的值
  final Map<String, List<CategoryItem>> _byType = {};

  /// 取某资料类型的分类列表（未加载时返回空列表）
  List<CategoryItem> of(String assetType) =>
      _byType[assetType] ?? const [];

  /// 按分类 id 查找分类对象（跨类型查找）
  CategoryItem? byId(int? id) {
    if (id == null) return null;
    for (final list in _byType.values) {
      for (final c in list) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// 分类 id -> 显示名；null/找不到时显示"未分类"
  String nameOf(int? id, {String fallback = '未分类'}) => byId(id)?.name ?? fallback;

  /// 取某资料类型的默认分类（列表第一个，即预置的首个分类）。
  /// 新建笔记/导入图片或文档时，若用户未指定分类则归入此分类，
  /// 避免资料散落在"未分类"中。
  int? defaultCategoryId(String assetType) {
    final list = of(assetType);
    return list.isEmpty ? null : list.first.id;
  }

  /// 从数据库全量刷新
  Future<void> load() async {
    final db = await DbService.instance.database;
    final dao = CategoryDao(db);
    for (final type in _allTypes) {
      _byType[type] = await dao.queryByType(type);
    }
    notifyListeners();
  }

  /// 新增分类：同类型下重名返回错误文案，成功返回 null
  Future<String?> add(String name, String assetType) async {
    final db = await DbService.instance.database;
    final dao = CategoryDao(db);
    if (await dao.exists(name, assetType)) return '该分类已存在';
    await dao.insert(CategoryItem(
      name: name,
      assetType: assetType,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await load();
    return null;
  }

  /// 重命名分类：新名称在同类型下重复时返回错误文案
  Future<String?> rename(CategoryItem category, String newName) async {
    final db = await DbService.instance.database;
    final dao = CategoryDao(db);
    if (newName != category.name && await dao.exists(newName, category.assetType)) {
      return '该分类已存在';
    }
    await dao.rename(category.id!, newName);
    await load();
    return null;
  }

  /// 删除分类：
  /// 1. 该分类下的笔记与文件资料先归入"未分类"；
  /// 2. 再删除分类本身；
  /// 3. 刷新分类列表，并通知资料列表刷新（NoteProvider/AssetProvider 各自监听重建）。
  Future<void> delete(CategoryItem category) async {
    final db = await DbService.instance.database;
    await NoteDao(db).clearCategory(category.id!);
    await AssetDao(db).clearCategory(category.id!);
    await CategoryDao(db).delete(category.id!);
    await load();
  }

  /// 需要维护分类的四种资料类型
  static const List<String> _allTypes = ['note', 'image', 'audio', 'doc'];
}
