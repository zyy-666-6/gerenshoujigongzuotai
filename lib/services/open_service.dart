import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/asset_item.dart';
import '../utils/app_feedback.dart';
import 'file_storage.dart';
import '../pages/doc/pdf_viewer_page.dart';

/// 资料打开分发服务（实现文档 §8.5）。
///
/// 规则与需求文档 4.1/三-结果展示 对齐：
/// - PDF：优先 App 内预览页；
/// - Office/txt 等其他文档：调用手机已安装的兼容应用打开；
/// - 图片/语音不走此入口（图片有查看页、语音在列表内播放）；
/// - 文件丢失、无兼容应用：给出明确提示（属约定边界，非程序 Bug）。
class OpenService {
  OpenService._(); // 纯静态工具类

  /// 统一入口：根据资料类型分派打开方式，错误场景就地提示
  static Future<void> openAsset(BuildContext context, AssetItem asset) async {
    final file = FileStorage.instance.fileOfAsset(asset);
    if (!await file.exists()) {
      if (context.mounted) showError(context, '文件不存在或已被删除');
      return;
    }
    if (!context.mounted) return;

    // PDF：App 内预览
    if (asset.extension.toLowerCase() == 'pdf') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(asset: asset, filePath: file.path),
        ),
      );
      return;
    }

    // 其他文档：调用系统兼容应用打开
    final result = await OpenFilex.open(file.path, type: asset.mimeType);
    if (!context.mounted) return;
    if (result.type == ResultType.noAppToOpen) {
      showError(context, '未找到可打开该文件的应用，请先安装对应的查看工具');
    } else if (result.type != ResultType.done) {
      showError(context, '打开失败：${result.message}');
    }
  }
}
