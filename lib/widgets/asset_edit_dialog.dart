import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset_item.dart';
import '../providers/category_provider.dart';
import 'category_picker_sheet.dart';

class AssetEditResult {
  final String name;
  final int? categoryId;

  const AssetEditResult({required this.name, this.categoryId});
}

/// 编辑文件资料的显示名称与分类。
/// 文档目前只开放分类修改；图片和语音同时支持重命名。
Future<AssetEditResult?> showAssetEditDialog(
  BuildContext context, {
  required AssetItem asset,
  required bool allowRename,
}) async {
  final nameController = TextEditingController(text: asset.name);
  int? selectedCategoryId = asset.categoryId;

  final result = await showDialog<AssetEditResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final categoryName =
            context.watch<CategoryProvider>().nameOf(selectedCategoryId);
        return AlertDialog(
          title: Text('编辑${asset.type.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowRename)
                TextField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: const Text('分类'),
                subtitle: Text(categoryName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selected = await showCategoryPickerSheet(
                    dialogContext,
                    assetType: asset.type.dbValue,
                    currentId: selectedCategoryId,
                  );
                  if (selected == null) return;
                  setDialogState(() {
                    selectedCategoryId = selected == -1 ? null : selected;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (allowRename && name.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  AssetEditResult(
                    name: allowRename ? name : asset.name,
                    categoryId: selectedCategoryId,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ),
  );
  nameController.dispose();
  return result;
}
