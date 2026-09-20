/// 全局常量：分类类型、文档/图片格式白名单等
///
/// 注意：文档格式白名单以双方确认的测试样例为准（需求文档 §17），
/// 如需调整在此处统一修改。
class AppConstants {
  AppConstants._(); // 纯常量类，禁止实例化

  /// 旧版本预置分类名，仅用于数据库升级时清理。
  static const String defaultCategoryName = '默认';

  /// 笔记、图片、语音、文档共用的六个预置分类名称。
  static const List<String> presetCategoryNames = [
    'མཚན་མ་',
    'ཕར་ཕྱིན་',
    'དབུ་མ',
    'མཛོད་',
    'འདུལ་བ།',
    'འདོན་པ།',
  ];

  /// 分类归属的资料类型标识（与数据库 category.asset_type 取值一致）
  static const List<String> categoryTypes = ['note', 'image', 'audio', 'doc'];

  /// 资料类型标识 -> 中文名（用于页面标题显示）
  static const Map<String, String> categoryTypeLabels = {
    'note': '笔记',
    'image': '图片',
    'audio': '语音',
    'doc': '文档',
  };

  /// 支持导入的文档扩展名白名单（小写、不含点）
  static const List<String> docExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt',
  ];

  /// 支持导入的图片扩展名白名单（小写、不含点）
  static const List<String> imageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
  ];
}
