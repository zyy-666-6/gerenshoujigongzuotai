/// 文件资料类型：图片 / 语音 / 文档。
///
/// 三类文件资料共用数据库 `asset` 表，用 [AssetType] 区分。
enum AssetType { image, audio, doc }

/// [AssetType] 的配套扩展：
/// 数据库存值、界面中文名、落盘子目录名之间的转换。
extension AssetTypeX on AssetType {
  /// 写入数据库 type 列的字符串值
  String get dbValue {
    switch (this) {
      case AssetType.image:
        return 'image';
      case AssetType.audio:
        return 'audio';
      case AssetType.doc:
        return 'doc';
    }
  }

  /// 界面显示中文名
  String get label {
    switch (this) {
      case AssetType.image:
        return '图片';
      case AssetType.audio:
        return '语音';
      case AssetType.doc:
        return '文档';
    }
  }

  /// 本地存储子目录名：files/images、files/audio、files/docs
  String get dirName {
    switch (this) {
      case AssetType.image:
        return 'images';
      case AssetType.audio:
        return 'audio';
      case AssetType.doc:
        return 'docs';
    }
  }

  /// 数据库存值解析为枚举（未知值兜底为 image）
  static AssetType parse(String value) {
    switch (value) {
      case 'audio':
        return AssetType.audio;
      case 'doc':
        return AssetType.doc;
      default:
        return AssetType.image;
    }
  }
}

/// 文件资料数据模型，对应数据库 `asset` 表。
///
/// 图片、语音、文档三类共用此模型；字段与需求文档 §17 对齐：
/// 文件名、类型、路径（落盘文件名）、分类、大小、时长（语音）。
class AssetItem {
  /// 数据库自增 id；未入库时为 null
  final int? id;

  /// 资料类型
  final AssetType type;

  /// 显示名（导入时默认取原文件名，语音保存时可自定义）
  final String name;

  /// 落盘文件名（uuid.ext），配合 FileStorage 还原完整路径
  final String fileName;

  /// 小写扩展名，不含点（如 pdf、jpg、m4a）
  final String extension;

  /// MIME 类型（用于调用外部应用打开时指定）
  final String? mimeType;

  /// 文件大小（字节）
  final int size;

  /// 语音时长（毫秒）；非语音类型为 null
  final int? durationMs;

  /// 所属分类 id；null = 未分类
  final int? categoryId;

  /// 创建（导入/录制）时间，毫秒时间戳
  final int createdAt;

  const AssetItem({
    this.id,
    required this.type,
    required this.name,
    required this.fileName,
    required this.extension,
    this.mimeType,
    this.size = 0,
    this.durationMs,
    this.categoryId,
    required this.createdAt,
  });

  /// 从数据库行构造
  factory AssetItem.fromMap(Map<String, Object?> map) {
    return AssetItem(
      id: map['id'] as int?,
      type: AssetTypeX.parse((map['type'] as String?) ?? 'image'),
      name: (map['name'] as String?) ?? '',
      fileName: (map['file_name'] as String?) ?? '',
      extension: (map['extension'] as String?) ?? '',
      mimeType: map['mime_type'] as String?,
      size: (map['size'] as int?) ?? 0,
      durationMs: map['duration_ms'] as int?,
      categoryId: map['category_id'] as int?,
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }

  /// 序列化为数据库行
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type.dbValue,
      'name': name,
      'file_name': fileName,
      'extension': extension,
      'mime_type': mimeType,
      'size': size,
      'duration_ms': durationMs,
      'category_id': categoryId,
      'created_at': createdAt,
    };
  }
}
