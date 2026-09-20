import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';

/// 分类选择底部弹层（笔记编辑页、录音保存对话框共用）。
///
/// 返回值约定：
/// - `> 0`：选中的分类 id；
/// - `-1`：选择"未分类"（categoryId 置 null）；
/// - `null`：用户取消，调用方保持原选择不变。
Future<int?> showCategoryPickerSheet(
  BuildContext context, {
  required String assetType,
  int? currentId,
}) {
  final categories = context.read<CategoryProvider>().of(assetType);
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text('选择分类', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            // 分类列表
            ...categories.map(
              (c) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(c.name),
                trailing: currentId == c.id
                    ? const Icon(Icons.check, color: Colors.teal)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            ),
            // 未分类选项
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('未分类'),
              trailing: currentId == null
                  ? const Icon(Icons.check, color: Colors.teal)
                  : null,
              onTap: () => Navigator.pop(ctx, -1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
