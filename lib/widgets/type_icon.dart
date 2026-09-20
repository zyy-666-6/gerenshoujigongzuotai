// 资料类型图标工具（首页最近添加、文档列表、搜索结果共用）
import 'package:flutter/material.dart';

import '../models/asset_item.dart';

/// 图片/语音/文档三类资料的通用图标
IconData iconForType(AssetType type) {
  switch (type) {
    case AssetType.image:
      return Icons.image_outlined;
    case AssetType.audio:
      return Icons.mic_none;
    case AssetType.doc:
      return Icons.description_outlined;
  }
}

/// 按文档扩展名给出更细分的类型图标
IconData iconForDocExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'doc':
    case 'docx':
      return Icons.article_outlined;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_outlined;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_outlined;
    case 'txt':
      return Icons.notes_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// 资料图标统一入口：文档按扩展名细分，其余按类型
IconData iconForAsset(AssetItem asset) {
  if (asset.type == AssetType.doc) {
    return iconForDocExt(asset.extension);
  }
  return iconForType(asset.type);
}
