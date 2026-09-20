import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/asset_item.dart';

/// 大图查看页（实现文档 §8.3）。
///
/// 全屏深色背景 + 双指缩放/拖动（InteractiveViewer）。
class ImageViewerPage extends StatelessWidget {
  final AssetItem asset;

  /// 图片完整路径（进入前已校验存在）
  final String filePath;

  const ImageViewerPage({
    super.key,
    required this.asset,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text(
          asset.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('图片加载失败', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }
}
