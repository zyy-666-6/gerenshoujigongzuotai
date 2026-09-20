import 'package:flutter/foundation.dart';

import '../models/asset_item.dart';
import '../services/dao/asset_dao.dart';
import '../services/db_service.dart';
import '../services/file_storage.dart';

/// 文件资料状态管理：图片 / 语音 / 文档（实现文档 §8.3~§8.5）。
///
/// 按类型分别缓存全量列表；导入完成后由页面调用 [reload] 刷新。
class AssetProvider extends ChangeNotifier {
  final Map<AssetType, List<AssetItem>> _items = {
    for (final t in AssetType.values) t: <AssetItem>[],
  };

  /// 某类型的全部资料（已按创建时间倒序）
  List<AssetItem> itemsOf(AssetType type) => _items[type]!;

  /// 某类型的资料条数（首页入口卡片摘要用）
  int countOf(AssetType type) => _items[type]!.length;

  /// 按 id 取资料（搜索结果跳转等场景）
  AssetItem? byId(AssetType type, int? id) {
    if (id == null) return null;
    for (final a in _items[type]!) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 从数据库全量刷新三种类型
  Future<void> reload() async {
    final dao = AssetDao(await DbService.instance.database);
    for (final t in AssetType.values) {
      _items[t] = await dao.queryByType(t);
    }
    notifyListeners();
  }

  /// 删除资料：先删数据库索引，再删落盘文件，最后刷新列表。
  ///
  /// 文件已不存在的场景由 FileStorage 内部静默容忍（孤儿索引可直接清掉）。
  Future<void> deleteAsset(AssetItem asset) async {
    final dao = AssetDao(await DbService.instance.database);
    await dao.delete(asset.id!);
    await FileStorage.instance.deleteFile(asset.type, asset.fileName);
    await reload();
  }

  /// 修改资料的显示名称和分类，并立即刷新各列表。
  Future<void> updateAsset(
    AssetItem asset, {
    required String name,
    int? categoryId,
  }) async {
    final dao = AssetDao(await DbService.instance.database);
    await dao.updateInfo(
      asset.id!,
      name: name,
      categoryId: categoryId,
    );
    await reload();
  }
}
