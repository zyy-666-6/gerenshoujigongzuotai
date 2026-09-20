/// 文字笔记数据模型，对应数据库 `note` 表。
///
/// 字段与需求文档 §17「笔记记录」核心字段对齐：
/// 标题、正文、分类、更新时间。
class Note {
  /// 数据库自增 id；新建未入库时为 null
  final int? id;

  /// 笔记标题（可为空，展示时兜底为"未命名 + 时间"）
  final String title;

  /// 笔记正文
  final String content;

  /// 所属分类 id；null = 未分类
  final int? categoryId;

  /// 创建时间（毫秒时间戳）
  final int createdAt;

  /// 最后更新时间（毫秒时间戳），列表按此倒序
  final int updatedAt;

  const Note({
    this.id,
    required this.title,
    required this.content,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库行构造
  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      categoryId: map['category_id'] as int?,
      createdAt: (map['created_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
    );
  }

  /// 序列化为数据库行（id 为 null 时 SQLite 自动递增）
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
