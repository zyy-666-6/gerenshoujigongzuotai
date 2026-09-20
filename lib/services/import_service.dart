import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/asset_item.dart';
import 'dao/asset_dao.dart';
import 'db_service.dart';
import 'file_storage.dart';

/// 导入结果汇总：成功条数 + 失败的文件名列表（用于批量导入后的提示）
class ImportResult {
  int success = 0;
  final List<String> failed = [];

  bool get hasFailure => failed.isNotEmpty;

  /// 生成给用户看的提示文案
  String describe() {
    if (hasFailure) {
      return '成功导入 $success 项，失败 ${failed.length} 项（${failed.take(3).join('、')}）';
    }
    return '成功导入 $success 项';
  }
}

/// 统一导入服务（实现文档 §7、§10）。
///
/// 事务性顺序：先把文件拷贝落盘成功，再写入数据库索引；
/// 单个文件失败不影响其余文件，最终汇总反馈。
class ImportService {
  /// 扩展名 -> MIME 类型映射（调用外部应用打开文档时使用）
  static const Map<String, String> _mimeByExt = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'm4a': 'audio/mp4',
  };

  /// 按扩展名取 MIME 类型；未知扩展名返回 null（由系统自行推断）
  static String? mimeOf(String ext) => _mimeByExt[ext.toLowerCase()];

  /// 从文件名提取小写扩展名（不含点）；无扩展名返回空字符串
  static String extOf(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return ext.startsWith('.') ? ext.substring(1) : '';
  }

  /// 导入相册选中的图片（image_picker 返回的 XFile 列表）
  static Future<ImportResult> importPickedImages(
    List<XFile> files, {
    int? categoryId,
  }) async {
    final result = ImportResult();
    final dao = AssetDao(await DbService.instance.database);
    for (final file in files) {
      try {
        final ext = extOf(file.name);
        final fileName = await FileStorage.instance.copyIn(
          file.path,
          AssetType.image,
          ext,
        );
        await dao.insert(AssetItem(
          type: AssetType.image,
          name: file.name,
          fileName: fileName,
          extension: ext,
          mimeType: mimeOf(ext),
          size: await File(file.path).length(),
          categoryId: categoryId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
        result.success++;
      } catch (_) {
        result.failed.add(file.name); // 单个失败不中断整批
      }
    }
    return result;
  }

  /// 导入文件选择器选中的文件（图片或文档，file_picker 返回的 PlatformFile）
  static Future<ImportResult> importPickedFiles(
    List<PlatformFile> files,
    AssetType type, {
    int? categoryId,
  }) async {
    final result = ImportResult();
    final dao = AssetDao(await DbService.instance.database);
    for (final file in files) {
      // path 为空说明选择器未能落地缓存（如云端文件），记为失败
      if (file.path == null) {
        result.failed.add(file.name);
        continue;
      }
      try {
        final ext = extOf(file.name);
        final fileName =
            await FileStorage.instance.copyIn(file.path!, type, ext);
        await dao.insert(AssetItem(
          type: type,
          name: file.name,
          fileName: fileName,
          extension: ext,
          mimeType: mimeOf(ext),
          size: await file.length() ?? 0,
          categoryId: categoryId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
        result.success++;
      } catch (_) {
        result.failed.add(file.name);
      }
    }
    return result;
  }

  /// 保存一条录音：把录音临时文件拷贝到语音目录并写索引。
  ///
  /// 成功返回带 id 的资料对象；失败返回 null（页面提示后可重试/放弃）。
  /// 无论成败都会尝试清理临时文件。
  static Future<AssetItem?> saveAudio({
    required String tempPath,
    required String name,
    int? categoryId,
    required int durationMs,
  }) async {
    try {
      final size = await File(tempPath).length();
      final fileName =
          await FileStorage.instance.copyIn(tempPath, AssetType.audio, 'm4a');
      final dao = AssetDao(await DbService.instance.database);
      final id = await dao.insert(AssetItem(
        type: AssetType.audio,
        name: name,
        fileName: fileName,
        extension: 'm4a',
        mimeType: mimeOf('m4a'),
        size: size,
        durationMs: durationMs,
        categoryId: categoryId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      return AssetItem(
        id: id,
        type: AssetType.audio,
        name: name,
        fileName: fileName,
        extension: 'm4a',
        mimeType: mimeOf('m4a'),
        size: size,
        durationMs: durationMs,
        categoryId: categoryId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    } finally {
      // 清理录音临时文件
      try {
        final temp = File(tempPath);
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }
}
