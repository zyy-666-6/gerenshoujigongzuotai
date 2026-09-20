/// 资料分类数据模型，对应数据库 `category` 表。
///
/// 分类按资料类型隔离：笔记、图片、语音、文档各自拥有独立的分类列表
/// （见实现文档 §6）。类型取值见 [AppConstants.categoryTypes]。
class CategoryItem {
  /// 数据库自增 id；未入库时为 null
  final int? id;

  /// 分类名称（同类型下不允许重名）
  final String name;

  /// 归属的资料类型：note / image / audio / doc
  final String assetType;

  /// 创建时间（毫秒时间戳）
  final int createdAt;

  const CategoryItem({
    this.id,
    required this.name,
    required this.assetType,
    required this.createdAt,
  });

  /// 从数据库行构造
  factory CategoryItem.fromMap(Map<String, Object?> map) {
    return CategoryItem(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      assetType: (map['asset_type'] as String?) ?? '',
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }

  /// 序列化为数据库行
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'asset_type': assetType,
      'created_at': createdAt,
    };
  }
}
