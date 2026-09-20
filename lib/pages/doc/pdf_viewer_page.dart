import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../models/asset_item.dart';

/// PDF App 内预览页（实现文档 §8.5）。
///
/// 使用 pdfrx 稳定 1.x 系列（基于新版 PDFium，维护活跃）。
/// 需求约定：PDF 优先内置预览；Office 等其他格式不在此页处理。
/// 文件存在性已由 OpenService 在进入前校验；加载失败（源文件损坏等）
/// 由 pdfrx 内置的错误横幅展示（属约定边界，非程序 Bug）。
class PdfViewerPage extends StatelessWidget {
  final AssetItem asset;

  /// PDF 完整路径（进入前已校验存在）
  final String filePath;

  const PdfViewerPage({
    super.key,
    required this.asset,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          asset.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // PdfViewer.file：从本地文件加载
      // 默认即支持上下滚动翻页、双指缩放、按需分页渲染
      body: PdfViewer.file(filePath),
    );
  }
}
