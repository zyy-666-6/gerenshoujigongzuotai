import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/asset_item.dart';

/// 本地文件存储单例服务（实现文档 §7）。
///
/// 目录结构（App 私有目录内，无需任何存储权限、卸载即随 App 清除）：
/// ```
/// <App私有目录>/files/
///   ├── images/   # uuid.jpg / uuid.png ...
///   ├── audio/    # uuid.m4a
///   └── docs/     # uuid.pdf / uuid.docx ...
/// ```
///
/// 关键策略：
/// - 导入即拷贝：源文件拷贝为 uuid 文件名落盘，数据库记录原始显示名；
/// - 事务性顺序由 ImportService 保证：拷贝成功后才写索引。
class FileStorage {
  /// 全局单例
  static final FileStorage instance = FileStorage._();

  FileStorage._();

  /// 各类型对应的落盘目录绝对路径（init 后可用）
  final Map<AssetType, String> _dirPaths = {};

  /// 应用启动时调用：创建 files/{images,audio,docs} 目录
  Future<void> init() async {
    final baseDir =
        Directory(p.join((await getApplicationDocumentsDirectory()).path, 'files'));
    for (final type in AssetType.values) {
      final dir = Directory(p.join(baseDir.path, type.dirName));
      await dir.create(recursive: true); // 已存在时为空操作
      _dirPaths[type] = dir.path;
    }
  }

  /// 类型 + 落盘文件名 -> 完整路径（同步，init 之后调用）
  String pathOf(AssetType type, String fileName) =>
      p.join(_dirPaths[type]!, fileName);

  /// 资料对象对应的本地文件（不做存在性检查，调用方按需校验）
  File fileOfAsset(AssetItem asset) => File(pathOf(asset.type, asset.fileName));

  /// 把源文件拷贝到对应类型目录，文件名重命名为 `uuid.ext`。
  ///
  /// 返回落盘文件名（写入数据库 file_name 列）；拷贝失败向上抛异常，
  /// 由 ImportService 统一记为导入失败项。
  Future<String> copyIn(String sourcePath, AssetType type, String ext) async {
    final suffix = ext.isEmpty ? '' : '.$ext';
    final fileName = '${const Uuid().v4()}$suffix';
    await File(sourcePath).copy(pathOf(type, fileName));
    return fileName;
  }

  /// 删除落盘文件；文件已不存在时静默通过（容忍被系统清理的孤儿文件）
  Future<void> deleteFile(AssetType type, String fileName) async {
    final file = File(pathOf(type, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
