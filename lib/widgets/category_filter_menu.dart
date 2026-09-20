import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';

/// 列表页顶部的分类筛选菜单（笔记/图片/语音/文档四个列表页共用）。
///
/// 选项值约定（回调 onSelected 收到）：
/// - `'all'`  全部；
/// - `'none'` 未分类；
/// - 其他     分类 id 的字符串形式。
class CategoryFilterMenu extends StatelessWidget {
  final String assetType;
  final String? selected;
  final ValueChanged<String> onSelected;

  const CategoryFilterMenu({
    super.key,
    required this.assetType,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().of(assetType);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      tooltip: '按分类筛选',
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'all', child: Text('全部')),
        const PopupMenuItem(value: 'none', child: Text('未分类')),
        ...categories.map(
          (c) => PopupMenuItem(value: c.id.toString(), child: Text(c.name)),
        ),
      ],
    );
  }
}
